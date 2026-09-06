from flask import request, jsonify
from firebase_admin import firestore
import logging
from datetime import datetime
from . import v3_bp

logger = logging.getLogger(__name__)
db = firestore.client()

@v3_bp.route('/academic/setup', methods=['POST'])
def academic_setup():
    """
    Save academic setup for a student.
    Payload:
    {
        "studentId": "uid",
        "academicYear": "Year 2",
        "semester": "Semester 1",
        "units": [
            {"code": "CS101", "name": "Intro to CS", "targetGrade": "A", "targetCatScore": 25, "targetExamScore": 65}
        ]
    }
    """
    try:
        data = request.json
        student_id = data.get('studentId')
        
        if not student_id:
            return jsonify({"error": "studentId is required"}), 400
            
        doc_ref = db.collection('users').document(student_id).collection('academic_profile').document('current')
        doc_ref.set({
            'academicYear': data.get('academicYear'),
            'semester': data.get('semester'),
            'units': data.get('units', []),
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        # Save Leaderboard Settings
        leaderboard_settings = data.get('leaderboardSettings')
        if leaderboard_settings:
            db.collection('users').document(student_id).collection('academic_profile').document('settings').set({
                'studyAlias': leaderboard_settings.get('studyAlias', ''),
                'useRealName': leaderboard_settings.get('useRealName', False),
                'updatedAt': firestore.SERVER_TIMESTAMP
            }, merge=True)
        
        return jsonify({"message": "Academic profile saved successfully"}), 200
        
    except Exception as e:
        logger.error(f"Error saving academic profile: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/results', methods=['POST'])
def log_academic_results():
    """
    Log actual results for a unit to compare against targets.
    Payload:
    {
        "studentId": "uid",
        "unitCode": "CS101",
        "type": "CAT1", # CAT1, CAT2, EXAM
        "score": 20
    }
    """
    try:
        data = request.json
        student_id = data.get('studentId')
        unit_code = data.get('unitCode')
        
        if not student_id or not unit_code:
            return jsonify({"error": "studentId and unitCode are required"}), 400
            
        results_ref = db.collection('users').document(student_id).collection('academic_results').document(unit_code)
        
        # Merge the new score into the document
        update_data = {
            f"scores.{data.get('type')}": data.get('score'),
            "updatedAt": firestore.SERVER_TIMESTAMP
        }
        
        results_ref.set(update_data, merge=True)
        
        return jsonify({"message": "Result logged successfully"}), 200
        
    except Exception as e:
        logger.error(f"Error logging academic result: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/analytics', methods=['GET'])
def get_academic_analytics():
    """
    Retrieve academic targets vs actuals and generate AI study advice.
    """
    try:
        student_id = request.args.get('studentId')
        if not student_id:
            return jsonify({"error": "studentId is required"}), 400
            
        # Fetch profile and results
        profile_doc = db.collection('users').document(student_id).collection('academic_profile').document('current').get()
        results_stream = db.collection('users').document(student_id).collection('academic_results').stream()
        
        profile_data = profile_doc.to_dict() if profile_doc.exists else {}
        results_data = {doc.id: doc.to_dict().get('scores', {}) for doc in results_stream}
        
        advice = []
        
        if profile_data.get('units'):
            advice.append("Keep logging your CAT and Exam results to track performance.")
            for unit in profile_data.get('units', []):
                code = unit.get('code')
                target = unit.get('targetCatScore')
                actual = results_data.get(code, {}).get('CAT1')
                if target and actual:
                    try:
                        t_val = float(str(target).replace('%', '').split('/')[0])
                        a_val = float(str(actual).replace('%', '').split('/')[0])
                        if a_val < t_val:
                            advice.append(f"For {code}, you missed your target by {t_val - a_val}. Allocate more time to {code} in your Daily Focus.")
                        elif a_val >= t_val:
                            advice.append(f"Great job on {code}! You met or exceeded your target.")
                    except:
                        pass
        
        if not advice:
            advice.append("Keep logging your CAT and Exam results to get personalized study advice.")
            
        return jsonify({
            "profile": profile_data,
            "results": results_data,
            "aiAdvice": advice
        }), 200
        
    except Exception as e:
        logger.error(f"Error fetching academic analytics: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/timetable/generate', methods=['POST'])
def generate_timetable():
    try:
        data = request.json
        student_id = data.get('studentId')
        
        if not student_id:
            return jsonify({"error": "studentId is required"}), 400
            
        profile_doc = db.collection('users').document(student_id).collection('academic_profile').document('current').get()
        if not profile_doc.exists:
            return jsonify({"error": "Academic profile not found"}), 404
            
        profile_data = profile_doc.to_dict()
        units = profile_data.get('units', [])
        
        def generate_fallback(units_list):
            if not units_list:
                return {"Monday": [{"time": "8:00 AM - 10:00 AM", "task": "General Study (Focus)", "type": "Study", "color": "0xFF3B82F6"}]}
            
            days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
            slots = [
                {"time": "8:00 AM - 10:00 AM", "type": "Deep Work", "color": "0xFF10B981"},
                {"time": "10:30 AM - 12:30 PM", "type": "Review", "color": "0xFFF59E0B"},
                {"time": "2:00 PM - 4:00 PM", "type": "Assignment", "color": "0xFF8B5CF6"},
                {"time": "4:30 PM - 6:30 PM", "type": "Reading", "color": "0xFFEC4899"}
            ]
            
            sch = {d: [] for d in days}
            for i, u in enumerate(units_list):
                d = days[i % len(days)]
                s = slots[i % len(slots)]
                code = u.get('code', 'Study')
                
                sch[d].append({
                    "time": s["time"],
                    "task": f"{code} ({s['type']})",
                    "type": s["type"],
                    "color": s["color"]
                })
                
            sch["Saturday"] = [{"time": "9:00 AM - 12:00 PM", "task": "Weekly Content Review", "type": "Review", "color": "0xFFF59E0B"}]
            return {k: v for k, v in sch.items() if v}
        
        schedule = generate_fallback(units)
        
        # Save to firestore
        db.collection('users').document(student_id).collection('academic_timetable').document('current').set({
            'schedule': schedule,
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"message": "Timetable generated", "schedule": schedule}), 200

    except Exception as e:
        logger.error(f"Error generating timetable: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/timetable', methods=['GET'])
def get_timetable():
    try:
        student_id = request.args.get('studentId')
        if not student_id:
            return jsonify({"error": "studentId is required"}), 400
            
        doc = db.collection('users').document(student_id).collection('academic_timetable').document('current').get()
        if doc.exists:
            return jsonify({"schedule": doc.to_dict().get('schedule', {})}), 200
        return jsonify({"schedule": {}}), 200
    except Exception as e:
        logger.error(f"Error getting timetable: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/timetable/save', methods=['POST'])
def save_timetable():
    try:
        data = request.json
        student_id = data.get('studentId')
        schedule = data.get('schedule')
        
        if not student_id or not schedule:
            return jsonify({"error": "studentId and schedule are required"}), 400
            
        db.collection('users').document(student_id).collection('academic_timetable').document('current').set({
            'schedule': schedule,
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        return jsonify({"message": "Timetable saved successfully"}), 200
    except Exception as e:
        logger.error(f"Error saving timetable: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/tasks', methods=['GET', 'POST'])
def manage_tasks():
    try:
        if request.method == 'GET':
            student_id = request.args.get('studentId')
            if not student_id:
                return jsonify({"error": "studentId is required"}), 400
                
            docs = db.collection('users').document(student_id).collection('academic_tasks').stream()
            tasks = [{"id": doc.id, **doc.to_dict()} for doc in docs]
            return jsonify({"tasks": tasks}), 200
            
        elif request.method == 'POST':
            data = request.json
            student_id = data.get('studentId')
            title = data.get('title')
            completed = data.get('completed', False)
            task_id = data.get('taskId') # If provided, update
            scheduled_time = data.get('scheduledTime') # Optional HH:MM
            
            if not student_id or not title:
                return jsonify({"error": "studentId and title are required"}), 400
                
            tasks_ref = db.collection('users').document(student_id).collection('academic_tasks')
            
            task_data = {'title': title, 'completed': completed}
            if scheduled_time:
                task_data['scheduledTime'] = scheduled_time
                
            if task_id:
                tasks_ref.document(task_id).set(task_data, merge=True)
            else:
                task_data['createdAt'] = firestore.SERVER_TIMESTAMP
                tasks_ref.add(task_data)
                
            return jsonify({"message": "Task saved"}), 200
            
    except Exception as e:
        logger.error(f"Error managing tasks: {e}")
        return jsonify({"error": str(e)}), 500

from datetime import datetime, timezone, timedelta
import random
from utils.flashcards_generator import get_365_flashcards

@v3_bp.route('/academic/focus/heatmap', methods=['GET'])
def get_focus_heatmap():
    try:
        student_id = request.args.get('studentId')
        if not student_id:
            return jsonify({"error": "studentId required"}), 400
            
        now = datetime.now(timezone.utc)
        sixty_days_ago = now - timedelta(days=60)
        start_date_str = sixty_days_ago.strftime('%Y-%m-%d')
        
        logs_ref = db.collection('users').document(student_id).collection('academic_focus_logs')
        query = logs_ref.where('dateString', '>=', start_date_str).stream()
        
        heatmap_data = {}
        for doc in query:
            data = doc.to_dict()
            date_str = data.get('dateString')
            duration = data.get('durationMinutes', 0)
            if date_str:
                heatmap_data[date_str] = heatmap_data.get(date_str, 0) + duration
                
        return jsonify({"heatmap": heatmap_data}), 200
        
    except Exception as e:
        logger.error(f"Error fetching heatmap: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/focus/log', methods=['POST'])
def log_focus_session():
    try:
        data = request.json
        student_id = data.get('studentId')
        duration_minutes = data.get('durationMinutes', 0)
        status = data.get('status', 'completed')
        
        if not student_id:
            return jsonify({"error": "studentId is required"}), 400
            
        now = datetime.now(timezone.utc)
        today_str = now.strftime('%Y-%m-%d')
        yesterday = now - timedelta(days=1)
        yesterday_str = yesterday.strftime('%Y-%m-%d')
        
        # 1. Log the session
        db.collection('users').document(student_id).collection('academic_focus_logs').add({
            'durationMinutes': duration_minutes,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'dateString': today_str,
            'status': status
        })
        
        if status == 'failed':
            return jsonify({"message": "Failed focus session logged"}), 200
        
        # 2. Calculate Streaks & Stats
        streak_ref = db.collection('users').document(student_id).collection('academic_streaks').document('current')
        streak_doc = streak_ref.get()
        
        current_streak = 0
        total_minutes = 0
        last_log_date = ""
        
        if streak_doc.exists:
            streak_data = streak_doc.to_dict()
            current_streak = streak_data.get('currentStreak', 0)
            total_minutes = streak_data.get('totalFocusMinutes', 0)
            last_log_date = streak_data.get('lastLogDate', "")
            
        # Update streak logic
        if last_log_date == yesterday_str:
            current_streak += 1
        elif last_log_date != today_str:
            # They either missed a day, or this is their very first log ever
            current_streak = 1
            
        total_minutes += duration_minutes
        
        streak_ref.set({
            'currentStreak': current_streak,
            'totalFocusMinutes': total_minutes,
            'lastLogDate': today_str,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
        # 3. Sync to Global Leaderboard
        profile_doc = db.collection('users').document(student_id).collection('academic_profile').document('settings').get()
        use_real_name = False
        display_name = "Anonymous Scholar"
        
        if profile_doc.exists:
            profile_data = profile_doc.to_dict()
            use_real_name = profile_data.get('useRealName', False)
            if not use_real_name:
                alias = profile_data.get('studyAlias', '').strip()
                if alias:
                    display_name = alias
                
        if use_real_name or display_name == "Anonymous Scholar":
            user_doc = db.collection('users').document(student_id).get()
            if user_doc.exists and use_real_name:
                display_name = user_doc.to_dict().get('displayName', display_name)
            
        db.collection('global_academic_stats').document(student_id).set({
            'displayName': display_name,
            'currentStreak': current_streak,
            'totalFocusMinutes': total_minutes,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
        return jsonify({
            "message": "Focus session logged", 
            "currentStreak": current_streak,
            "totalFocusMinutes": total_minutes
        }), 200
        
    except Exception as e:
        logger.error(f"Error logging focus session: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/focus/stats', methods=['GET'])
def get_focus_stats():
    try:
        student_id = request.args.get('studentId')
        if not student_id:
            return jsonify({"error": "studentId is required"}), 400
            
        streak_doc = db.collection('users').document(student_id).collection('academic_streaks').document('current').get()
        
        # Validate streak isn't lost if they just opened the app today but haven't logged yet
        now = datetime.now(timezone.utc)
        today_str = now.strftime('%Y-%m-%d')
        yesterday = now - timedelta(days=1)
        yesterday_str = yesterday.strftime('%Y-%m-%d')
        
        if streak_doc.exists:
            data = streak_doc.to_dict()
            last_log = data.get('lastLogDate', '')
            # If the last log wasn't today or yesterday, they lost the streak
            if last_log != today_str and last_log != yesterday_str:
                data['currentStreak'] = 0
            return jsonify(data), 200
            
        return jsonify({"currentStreak": 0, "totalFocusMinutes": 0}), 200
    except Exception as e:
        logger.error(f"Error getting focus stats: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/leaderboard', methods=['GET'])
def get_leaderboard():
    try:
        # Fetch top 10 students by total focus minutes
        docs = db.collection('global_academic_stats').order_by(
            'totalFocusMinutes', direction=firestore.Query.DESCENDING
        ).limit(10).stream()
        
        leaderboard = []
        for i, doc in enumerate(docs):
            data = doc.to_dict()
            leaderboard.append({
                "id": doc.id,
                "rank": i + 1,
                "displayName": data.get('displayName', 'Anonymous Scholar'),
                "totalFocusMinutes": data.get('totalFocusMinutes', 0),
                "currentStreak": data.get('currentStreak', 0)
            })
            
        return jsonify({"leaderboard": leaderboard}), 200
    except Exception as e:
        logger.error(f"Error fetching leaderboard: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/flashcards', methods=['GET', 'POST'])
def manage_flashcards():
    try:
        if request.method == 'POST':
            data = request.json
            student_id = data.get('studentId') or data.get('student_id')
            unit_code = data.get('unitCode', 'General')
            front = data.get('front')
            back = data.get('back')
            
            if not student_id or not front or not back:
                return jsonify({"error": "studentId, front, back required"}), 400
                
            now = datetime.now(timezone.utc)
            today_str = now.strftime('%Y-%m-%d')
            
            card_data = {
                'unitCode': unit_code,
                'front': front,
                'back': back,
                'repetition': 0,
                'interval': 0,
                'easeFactor': 2.5,
                'nextReviewDate': today_str,
                'createdAt': firestore.SERVER_TIMESTAMP
            }
            
            db.collection('users').document(student_id).collection('academic_flashcards').add(card_data)
            return jsonify({"message": "Flashcard created successfully"}), 201

        elif request.method == 'GET':
            student_id = request.args.get('studentId') or request.args.get('student_id')
            if not student_id:
                return jsonify({"error": "studentId required"}), 400
                
            now = datetime.now(timezone.utc)
            today_str = now.strftime('%Y-%m-%d')
            
            # Fetch cards where nextReviewDate <= today_str
            cards_ref = db.collection('users').document(student_id).collection('academic_flashcards')
            query = cards_ref.where('nextReviewDate', '<=', today_str).stream()
            
            cards = [{"id": c.id, **c.to_dict()} for c in query]
            
            if not cards:
                # Auto-generate 365 flashcards for the student using the massive generator
                now = datetime.now(timezone.utc)
                generated_cards = get_365_flashcards()
                
                batch = db.batch()
                for i, card_info in enumerate(generated_cards):
                    card_data = {
                        'unitCode': card_info['category'],
                        'question': card_info['question'],
                        'answer': card_info['answer'],
                        'repetition': 0,
                        'interval': 0,
                        'easeFactor': 2.5,
                        'nextReviewDate': (now + timedelta(days=i)).strftime('%Y-%m-%d'),
                        'createdAt': firestore.SERVER_TIMESTAMP
                    }
                    doc_ref = db.collection('users').document(student_id).collection('academic_flashcards').document()
                    batch.set(doc_ref, card_data)
                    
                    # Return the first 50 to the frontend immediately so we don't overwhelm payload
                    if i < 50:
                        c = card_data.copy()
                        c['id'] = doc_ref.id
                        cards.append(c)
                    
                batch.commit()
                
            return jsonify({"flashcards": cards}), 200
            
    except Exception as e:
        logger.error(f"Error managing flashcards: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/flashcards/review', methods=['POST'])
def review_flashcard():
    """
    SM-2 Spaced Repetition Algorithm
    quality: 0-5 (0=Complete blackout, 3=Hard, 5=Perfect)
    """
    try:
        data = request.json
        student_id = data.get('studentId')
        card_id = data.get('cardId')
        quality = data.get('quality') # 0 to 5
        
        if not student_id or not card_id or quality is None:
            return jsonify({"error": "studentId, cardId, quality required"}), 400
            
        card_ref = db.collection('users').document(student_id).collection('academic_flashcards').document(card_id)
        card_doc = card_ref.get()
        
        if not card_doc.exists:
            return jsonify({"error": "Card not found"}), 404
            
        c_data = card_doc.to_dict()
        repetition = c_data.get('repetition', 0)
        interval = c_data.get('interval', 0)
        ease = c_data.get('easeFactor', 2.5)
        
        if quality >= 3:
            if repetition == 0:
                interval = 1
            elif repetition == 1:
                interval = 6
            else:
                interval = round(interval * ease)
            repetition += 1
        else:
            repetition = 0
            interval = 1
            
        ease = ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
        if ease < 1.3:
            ease = 1.3
            
        next_date = datetime.now(timezone.utc) + timedelta(days=interval)
        
        updates = {
            'repetition': repetition,
            'interval': interval,
            'easeFactor': ease,
            'nextReviewDate': next_date.strftime('%Y-%m-%d')
        }
        card_ref.update(updates)
        
        # Track streak
        user_ref = db.collection('users').document(student_id)
        user_doc = user_ref.get()
        if user_doc.exists:
            udata = user_doc.to_dict()
            last_review = udata.get('lastFlashcardReviewDate')
            today_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
            current_streak = udata.get('flashcardStreak', 0)
            
            if last_review != today_str:
                # Need to increment streak. Check if it was yesterday to keep streak alive
                yesterday_str = (datetime.now(timezone.utc) - timedelta(days=1)).strftime('%Y-%m-%d')
                if last_review == yesterday_str:
                    current_streak += 1
                else:
                    current_streak = 1 # Reset streak
                
                user_ref.update({
                    'lastFlashcardReviewDate': today_str,
                    'flashcardStreak': current_streak
                })

        return jsonify({"message": "Review logged", "updates": updates, "streak": current_streak if user_doc.exists else 0}), 200
        
    except Exception as e:
        logger.error(f"Error reviewing flashcard: {e}")
        return jsonify({"error": str(e)}), 500

@v3_bp.route('/academic/assignments', methods=['GET', 'POST'])
def manage_assignments():
    try:
        if request.method == 'POST':
            data = request.json
            student_id = data.get('studentId')
            title = data.get('title')
            due_date_str = data.get('dueDate') # Expected format YYYY-MM-DD
            parts = data.get('parts', 1)
            
            if not student_id or not title or not due_date_str:
                return jsonify({"error": "studentId, title, dueDate required"}), 400
                
            # 1. Save the assignment
            assignment_data = {
                'title': title,
                'dueDate': due_date_str,
                'parts': parts,
                'createdAt': firestore.SERVER_TIMESTAMP
            }
            db.collection('users').document(student_id).collection('academic_assignments').add(assignment_data)
            
            # 2. Backward Planning Algorithm
            # Calculate days between now and due_date
            now = datetime.now(timezone.utc)
            try:
                due_date = datetime.strptime(due_date_str, '%Y-%m-%d').replace(tzinfo=timezone.utc)
                days_left = (due_date - now).days
            except ValueError:
                return jsonify({"error": "Invalid date format. Use YYYY-MM-DD"}), 400
                
            if days_left > 0 and parts > 0:
                tasks_ref = db.collection('users').document(student_id).collection('academic_tasks')
                
                batch = db.batch()
                for i in range(1, parts + 1):
                    task_doc = tasks_ref.document()
                    batch.set(task_doc, {
                        'title': f'Prep for {title} - Ch/Part {i}/{parts}',
                        'completed': False,
                        'createdAt': firestore.SERVER_TIMESTAMP
                    })
                batch.commit()
                
            return jsonify({"message": "Assignment created and backward planning applied"}), 201

        elif request.method == 'GET':
            student_id = request.args.get('studentId')
            if not student_id:
                return jsonify({"error": "studentId required"}), 400
                
            now_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
            
            # Fetch upcoming assignments
            assign_ref = db.collection('users').document(student_id).collection('academic_assignments')
            query = assign_ref.where('dueDate', '>=', now_str).stream()
            
            assignments = [{"id": a.id, **a.to_dict()} for a in query]
            # Sort by due date locally
            assignments.sort(key=lambda x: x.get('dueDate', '9999-99-99'))
            
            return jsonify({"assignments": assignments}), 200
            
    except Exception as e:
        logger.error(f"Error managing assignments: {e}")
        return jsonify({"error": str(e)}), 500
