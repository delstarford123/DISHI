import os
import json
from flask import Blueprint, request, jsonify, render_template_string
from firebase_admin import firestore

campus_idol_v6_bp = Blueprint('campus_idol_v6', __name__)

def _format_duration(seconds):
    try:
        sec = int(round(float(seconds)))
        mins = sec // 60
        rem_sec = sec % 60
        return f"{mins}:{rem_sec:02d}"
    except (ValueError, TypeError):
        return "0:10"

def _hex_to_css_color(color_int):
    if not color_int:
        return "#3B82F6"
    try:
        # If it's an ARGB integer (Flutter toARGB32)
        val = int(color_int) & 0xFFFFFFFF
        # ARGB -> RGB
        r = (val >> 16) & 0xFF
        g = (val >> 8) & 0xFF
        b = val & 0xFF
        return f"rgb({r}, {g}, {b})"
    except Exception:
        return "#3B82F6"

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🎤 {{ idol.title }} - {{ idol.userName }} | DISHI Campus Idol</title>
    <meta name="description" content="Listen to {{ idol.userName }}'s audition '{{ idol.title }}' on DISHI Campus Idol. Vote, turn your chair, and discover student talent across Kenya!">
    
    <!-- OpenGraph Metadata for WhatsApp, iMessage, Telegram, Twitter -->
    <meta property="og:title" content="🎤 {{ idol.title }} - {{ idol.userName }} | DISHI Campus Idol">
    <meta property="og:description" content="Listen to this student audition on DISHI Campus Idol! Turn your chair and cast your vote.">
    <meta property="og:image" content="{{ idol.userPhoto or 'https://dishi.delstarfordworks.co.ke/static/img/dishi_logo.png' }}">
    <meta property="og:audio" content="{{ idol.audioUrl }}">
    <meta property="og:type" content="music.song">
    <meta property="og:url" content="{{ share_url }}">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="🎤 {{ idol.title }} - {{ idol.userName }}">
    <meta name="twitter:description" content="Listen to this student audition on DISHI Campus Idol! Turn your chair & vote.">
    <meta name="twitter:image" content="{{ idol.userPhoto or 'https://dishi.delstarfordworks.co.ke/static/img/dishi_logo.png' }}">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@600;700;800;900&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="icon" type="image/png" href="/static/img/dishi_logo.png">

    <style>
        :root {
            --bg: #080D18;
            --card-bg: rgba(16, 23, 38, 0.85);
            --card-elevated: #162033;
            --border: rgba(255, 255, 255, 0.1);
            --accent-glow: {{ theme_color }};
            --neon-mint: #05D5AA;
            --neon-red: #FF2A6D;
            --neon-blue: #38BDF8;
            --text-main: #FFFFFF;
            --text-sub: #94A3B8;
        }

        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
            background-color: var(--bg);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 24px 16px;
            background-image: 
                radial-gradient(circle at 50% 20%, rgba(56, 189, 248, 0.12) 0%, transparent 50%),
                radial-gradient(circle at 80% 80%, rgba(255, 42, 109, 0.1) 0%, transparent 40%);
        }

        .container {
            width: 100%;
            max-width: 440px;
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 32px;
            backdrop-filter: blur(24px);
            -webkit-backdrop-filter: blur(24px);
            padding: 32px 24px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7), 0 0 40px rgba(56, 189, 248, 0.15);
            text-align: center;
            position: relative;
            overflow: hidden;
        }

        .brand-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 6px 14px;
            border-radius: 9999px;
            background: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.12);
            font-size: 12px;
            font-weight: 600;
            color: var(--neon-mint);
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 24px;
        }

        .avatar-wrap {
            width: 130px;
            height: 130px;
            margin: 0 auto 20px;
            border-radius: 50%;
            padding: 6px;
            background: linear-gradient(135deg, var(--accent-glow), var(--neon-mint));
            box-shadow: 0 0 30px var(--accent-glow);
            position: relative;
        }

        .avatar-inner {
            width: 100%;
            height: 100%;
            border-radius: 50%;
            background: #0F172A;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }

        .avatar-inner img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }

        .avatar-icon {
            font-size: 52px;
        }

        .track-title {
            font-family: 'Outfit', sans-serif;
            font-size: 26px;
            font-weight: 800;
            margin-bottom: 6px;
            color: #FFFFFF;
            letter-spacing: -0.5px;
            line-height: 1.2;
        }

        .artist-name {
            font-size: 15px;
            color: var(--text-sub);
            margin-bottom: 16px;
        }

        .chips {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            margin-bottom: 24px;
        }

        .chip {
            font-size: 12px;
            font-weight: 600;
            padding: 5px 12px;
            border-radius: 20px;
            background: rgba(255, 255, 255, 0.08);
            color: #E2E8F0;
        }

        /* Sound Wave Animation */
        .soundwave {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 4px;
            height: 40px;
            margin-bottom: 20px;
        }

        .bar {
            width: 4px;
            background: var(--neon-mint);
            border-radius: 2px;
            height: 6px;
            transition: height 0.2s ease;
        }

        .soundwave.playing .bar:nth-child(1) { animation: wave 0.8s ease-in-out infinite alternate 0.1s; }
        .soundwave.playing .bar:nth-child(2) { animation: wave 0.9s ease-in-out infinite alternate 0.3s; }
        .soundwave.playing .bar:nth-child(3) { animation: wave 0.7s ease-in-out infinite alternate 0.2s; }
        .soundwave.playing .bar:nth-child(4) { animation: wave 1.1s ease-in-out infinite alternate 0.4s; }
        .soundwave.playing .bar:nth-child(5) { animation: wave 0.8s ease-in-out infinite alternate 0.1s; }
        .soundwave.playing .bar:nth-child(6) { animation: wave 1.0s ease-in-out infinite alternate 0.5s; }
        .soundwave.playing .bar:nth-child(7) { animation: wave 0.7s ease-in-out infinite alternate 0.2s; }
        .soundwave.playing .bar:nth-child(8) { animation: wave 1.2s ease-in-out infinite alternate 0.3s; }

        @keyframes wave {
            0% { height: 6px; }
            100% { height: 36px; }
        }

        /* Player Controls */
        .player-bar {
            width: 100%;
            margin-bottom: 12px;
        }

        .progress-container {
            width: 100%;
            height: 6px;
            background: rgba(255, 255, 255, 0.15);
            border-radius: 3px;
            cursor: pointer;
            position: relative;
            margin-bottom: 8px;
        }

        .progress-bar {
            height: 100%;
            width: 0%;
            background: linear-gradient(90deg, var(--neon-mint), var(--neon-blue));
            border-radius: 3px;
            transition: width 0.1s linear;
        }

        .time-row {
            display: flex;
            justify-content: space-between;
            font-size: 11px;
            color: var(--text-sub);
            font-weight: 500;
        }

        .play-btn-wrap {
            margin-bottom: 24px;
        }

        .play-btn {
            width: 68px;
            height: 68px;
            border-radius: 50%;
            background: linear-gradient(135deg, #2563EB, #1D4ED8);
            border: none;
            color: white;
            font-size: 28px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            box-shadow: 0 10px 25px -5px rgba(37, 99, 235, 0.6);
            transition: transform 0.15s ease, box-shadow 0.15s ease;
        }

        .play-btn:active {
            transform: scale(0.92);
        }

        /* Actions */
        .actions-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            margin-bottom: 24px;
        }

        .action-card {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 18px;
            padding: 14px;
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 6px;
            cursor: pointer;
            transition: all 0.2s ease;
            text-decoration: none;
            color: white;
        }

        .action-card:hover {
            background: rgba(255, 255, 255, 0.09);
            border-color: rgba(255, 255, 255, 0.18);
        }

        .action-card:active {
            transform: scale(0.97);
        }

        .action-card.voted {
            border-color: var(--neon-red);
            background: rgba(255, 42, 109, 0.15);
        }

        .action-num {
            font-size: 18px;
            font-weight: 800;
            color: #FFFFFF;
        }

        .action-label {
            font-size: 11px;
            color: var(--text-sub);
            font-weight: 600;
        }

        .primary-cta {
            display: block;
            width: 100%;
            background: linear-gradient(135deg, #10B981, #059669);
            color: white;
            text-decoration: none;
            font-weight: 700;
            font-size: 15px;
            padding: 16px;
            border-radius: 18px;
            box-shadow: 0 10px 20px -5px rgba(16, 185, 129, 0.4);
            transition: transform 0.15s ease;
        }

        .primary-cta:active {
            transform: scale(0.98);
        }

        .toast {
            position: fixed;
            bottom: 30px;
            background: #1E293B;
            border: 1px solid rgba(255, 255, 255, 0.15);
            color: #FFFFFF;
            padding: 12px 20px;
            border-radius: 14px;
            font-size: 13px;
            font-weight: 600;
            box-shadow: 0 15px 30px rgba(0, 0, 0, 0.5);
            opacity: 0;
            transform: translateY(20px);
            transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
            pointer-events: none;
            z-index: 100;
        }

        .toast.show {
            opacity: 1;
            transform: translateY(0);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="brand-badge">
            <span>🎤</span> DISHI Campus Idol
        </div>

        <div class="avatar-wrap">
            <div class="avatar-inner">
                {% if idol.userPhoto %}
                    <img src="{{ idol.userPhoto }}" alt="{{ idol.userName }}">
                {% else %}
                    <span class="avatar-icon">🎙️</span>
                {% endif %}
            </div>
        </div>

        <h1 class="track-title">{{ idol.title }}</h1>
        <p class="artist-name">By <strong>{{ idol.userName }}</strong></p>

        <div class="chips">
            <span class="chip">🎛️ Filter: {{ idol.filter or 'Normal' }}</span>
            <span class="chip">⏱️ {{ duration_formatted }}</span>
        </div>

        <!-- Animated Wave -->
        <div class="soundwave" id="soundwave">
            <div class="bar"></div>
            <div class="bar"></div>
            <div class="bar"></div>
            <div class="bar"></div>
            <div class="bar"></div>
            <div class="bar"></div>
            <div class="bar"></div>
            <div class="bar"></div>
        </div>

        <!-- Custom Audio Controller -->
        <audio id="audioPlayer" preload="auto" src="{{ idol.audioUrl }}"></audio>

        <div class="player-bar">
            <div class="progress-container" id="progressContainer">
                <div class="progress-bar" id="progressBar"></div>
            </div>
            <div class="time-row">
                <span id="currentTime">0:00</span>
                <span>{{ duration_formatted }}</span>
            </div>
        </div>

        <div class="play-btn-wrap">
            <button class="play-btn" id="playBtn" aria-label="Play audition">
                <span id="playIcon">▶</span>
            </button>
        </div>

        <!-- Actions: Turn Chair (Vote) & Share Link -->
        <div class="actions-grid">
            <div class="action-card" id="chairVoteBtn">
                <span class="action-num" id="likeCountDisplay">❤️ {{ idol.likes or 0 }}</span>
                <span class="action-label" id="voteLabel">Turn Your Chair 🔴</span>
            </div>
            <div class="action-card" id="copyShareBtn">
                <span class="action-num">🔗</span>
                <span class="action-label">Copy Audition Link</span>
            </div>
        </div>

        <a href="swapeat://idol?id={{ idol_id }}" class="primary-cta" id="openAppBtn">
            Open in DISHI App 📲
        </a>
    </div>

    <div class="toast" id="toastMsg">Link copied to clipboard! 🎶</div>

    <script>
        const audio = document.getElementById('audioPlayer');
        const playBtn = document.getElementById('playBtn');
        const playIcon = document.getElementById('playIcon');
        const soundwave = document.getElementById('soundwave');
        const progressBar = document.getElementById('progressBar');
        const progressContainer = document.getElementById('progressContainer');
        const currentTime = document.getElementById('currentTime');
        const chairVoteBtn = document.getElementById('chairVoteBtn');
        const likeCountDisplay = document.getElementById('likeCountDisplay');
        const voteLabel = document.getElementById('voteLabel');
        const copyShareBtn = document.getElementById('copyShareBtn');
        const toast = document.getElementById('toastMsg');
        const openAppBtn = document.getElementById('openAppBtn');

        let isPlaying = false;
        let hasVoted = false;
        const idolId = "{{ idol_id }}";
        const shareUrl = "{{ share_url }}";

        function showToast(text) {
            toast.textContent = text;
            toast.classList.add('show');
            setTimeout(() => toast.classList.remove('show'), 2800);
        }

        function formatSec(seconds) {
            const sec = Math.floor(seconds || 0);
            const m = Math.floor(sec / 60);
            const s = sec % 60;
            return `${m}:${s < 10 ? '0' : ''}${s}`;
        }

        playBtn.addEventListener('click', () => {
            if (isPlaying) {
                audio.pause();
            } else {
                audio.play().catch(e => console.error("Playback error:", e));
            }
        });

        audio.addEventListener('play', () => {
            isPlaying = true;
            playIcon.textContent = '⏸';
            soundwave.classList.add('playing');
        });

        audio.addEventListener('pause', () => {
            isPlaying = false;
            playIcon.textContent = '▶';
            soundwave.classList.remove('playing');
        });

        audio.addEventListener('ended', () => {
            isPlaying = false;
            playIcon.textContent = '▶';
            soundwave.classList.remove('playing');
            progressBar.style.width = '0%';
            currentTime.textContent = '0:00';
        });

        audio.addEventListener('timeupdate', () => {
            if (audio.duration) {
                const percent = (audio.currentTime / audio.duration) * 100;
                progressBar.style.width = percent + '%';
                currentTime.textContent = formatSec(audio.currentTime);
            }
        });

        progressContainer.addEventListener('click', (e) => {
            if (!audio.duration) return;
            const rect = progressContainer.getBoundingClientRect();
            const clickX = e.clientX - rect.left;
            const frac = Math.max(0, Math.min(1, clickX / rect.width));
            audio.currentTime = frac * audio.duration;
        });

        // Vote / Turn chair
        chairVoteBtn.addEventListener('click', async () => {
            if (hasVoted) {
                showToast("You've already turned your chair! 🔴");
                return;
            }
            hasVoted = true;
            chairVoteBtn.classList.add('voted');
            voteLabel.textContent = "Chair Turned! ⭐";
            showToast("You turned your chair! 🔴 Voice voted!");

            try {
                const res = await fetch(`/api/v6/idol/${idolId}/vote`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ source: 'web_preview' })
                });
                const data = await res.json();
                if (data.status === 'success' && data.likes !== undefined) {
                    likeCountDisplay.textContent = `❤️ ${data.likes}`;
                }
            } catch (err) {
                console.error("Vote failed:", err);
            }
        });

        // Copy Share Link
        copyShareBtn.addEventListener('click', () => {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(shareUrl).then(() => {
                    showToast("Audition link copied to clipboard! 🎶");
                }).catch(() => {
                    fallbackCopy();
                });
            } else {
                fallbackCopy();
            }
        });

        function fallbackCopy() {
            const ta = document.createElement('textarea');
            ta.value = shareUrl;
            document.body.appendChild(ta);
            ta.select();
            document.execCommand('copy');
            document.body.removeChild(ta);
            showToast("Audition link copied! 🎶");
        }

        // Deep link handler: attempt to open app, fallback to app info if not installed
        openAppBtn.addEventListener('click', (e) => {
            const start = Date.now();
            setTimeout(() => {
                // If user is still on this web page after 1.5s, app probably not installed
                if (Date.now() - start < 2000 && !document.hidden) {
                    window.location.href = "https://dishi.delstarfordworks.co.ke";
                }
            }, 1500);
        });
    </script>
</body>
</html>
"""

HTML_NOT_FOUND = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audition Not Found | DISHI Campus Idol</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
        body {
            background-color: #080D18;
            color: #FFFFFF;
            font-family: 'Plus Jakarta Sans', sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
            text-align: center;
        }
        .box {
            background: #101726;
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 24px;
            padding: 40px 24px;
            max-width: 420px;
        }
        .icon { font-size: 48px; margin-bottom: 16px; }
        h1 { font-size: 22px; margin-bottom: 8px; }
        p { color: #94A3B8; font-size: 14px; margin-bottom: 24px; }
        a {
            display: inline-block;
            background: #3B82F6;
            color: white;
            text-decoration: none;
            padding: 12px 24px;
            border-radius: 12px;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="box">
        <div class="icon">🎙️</div>
        <h1>Audition Not Found</h1>
        <p>This Campus Idol voice track may have expired or was removed by the singer.</p>
        <a href="https://dishi.delstarfordworks.co.ke">Explore DISHI App</a>
    </div>
</body>
</html>
"""

@campus_idol_v6_bp.route('/<audition_id>', methods=['GET'])
def get_idol_audition_api(audition_id):
    """
    Returns JSON metadata for a Campus Idol audition.
    """
    if not audition_id:
        return jsonify({"error": "audition_id is required"}), 400

    try:
        db = firestore.client()
        doc = db.collection('campus_idols').document(audition_id).get()
        if not doc.exists:
            return jsonify({"error": "Audition not found"}), 404

        data = doc.to_dict()
        data['id'] = doc.id
        return jsonify({"status": "success", "idol": data}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@campus_idol_v6_bp.route('/<audition_id>/vote', methods=['POST'])
def vote_idol_audition(audition_id):
    """
    Increments like / chair turn count for an audition.
    """
    if not audition_id:
        return jsonify({"error": "audition_id is required"}), 400

    try:
        db = firestore.client()
        doc_ref = db.collection('campus_idols').document(audition_id)
        doc = doc_ref.get()
        if not doc.exists:
            return jsonify({"error": "Audition not found"}), 404

        doc_ref.update({
            'likes': firestore.Increment(1)
        })

        updated = doc_ref.get()
        new_likes = updated.to_dict().get('likes', 1)
        return jsonify({"status": "success", "likes": new_likes}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def render_idol_preview(audition_id=None):
    """
    Renders an OpenGraph-compliant, interactive web audio preview for Campus Idol links.
    Handles both /idol?id=<id> and /idol/<id>.
    """
    target_id = audition_id or request.args.get('id') or request.args.get('audition_id')
    if not target_id or not str(target_id).strip():
        return render_template_string(HTML_NOT_FOUND), 404

    target_id = str(target_id).strip()

    try:
        db = firestore.client()
        doc = db.collection('campus_idols').document(target_id).get()
        if not doc.exists:
            return render_template_string(HTML_NOT_FOUND), 404

        data = doc.to_dict() or {}
        share_url = f"https://dishi.delstarfordworks.co.ke/idol?id={target_id}"
        theme_color = _hex_to_css_color(data.get('colorHex'))
        duration_formatted = _format_duration(data.get('durationSeconds', 10))

        idol_data = {
            'userName': data.get('userName') or 'Comrade Singer',
            'userPhoto': data.get('userPhoto'),
            'title': data.get('title') or 'Campus Voice Audition',
            'audioUrl': data.get('audioUrl') or '',
            'filter': data.get('filter') or 'Normal',
            'likes': data.get('likes', 0),
        }

        return render_template_string(
            HTML_TEMPLATE,
            idol=idol_data,
            idol_id=target_id,
            share_url=share_url,
            theme_color=theme_color,
            duration_formatted=duration_formatted
        )
    except Exception as e:
        print(f"Error rendering idol preview: {e}")
        return render_template_string(HTML_NOT_FOUND), 500

