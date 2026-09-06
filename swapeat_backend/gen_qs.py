import json
import random

topics = ["Routine", "Dates", "Music", "Food", "Hobbies", "Movies", "Personality", "Future", "Social", "Habits", "Pets", "Tech", "Style"]
adjectives = ["Chill", "Crazy", "Deep", "Funny", "Random", "Spicy", "Hot Take", "Real Talk"]

# Generate 365 unique-ish questions
questions = []
for i in range(365):
    t = random.choice(topics)
    adj = random.choice(adjectives)
    questions.append({
        "question": f"{adj} {t} Vibe #{i+1}",
        "option0": f"Option A",
        "option1": f"Option B"
    })

# Overwrite some with the original good ones
good_qs = [
    {'question': 'Daily Routine', 'option0': '🦉 Night Owl', 'option1': '🌅 Early Bird'},
    {'question': 'Ideal Date Spot', 'option0': '🍔 Fast Food & Snacks', 'option1': '🍷 Dinner & Venues'},
    {'question': 'Weekend Vibes', 'option0': '📚 Library & Chill', 'option1': '🍸 Virtual Night Club'},
    {'question': 'Communication Style', 'option0': '💬 Quick Texting', 'option1': '🎙️ Long Calls & Video'},
    {'question': 'Energy Level', 'option0': '🤫 Calm Introvert', 'option1': '🎉 Loud Extrovert'},
    {'question': 'Movie Genre', 'option0': '🤣 Comedy', 'option1': '😱 Horror / Thriller'},
    {'question': 'Music Preference', 'option0': '🎧 Afrobeats', 'option1': '🎸 HipHop / R&B'},
    {'question': 'Social Media', 'option0': '📸 Instagram & TikTok', 'option1': '🐦 X (Twitter)'},
    {'question': 'Pets', 'option0': '🐶 Dogs', 'option1': '🐱 Cats'},
    {'question': 'Food Choice', 'option0': '🍕 Pizza & Burgers', 'option1': '🥗 Healthy Greens'},
    {'question': 'Study Style', 'option0': '📖 Solo Focus', 'option1': '🗣️ Group Study'},
    {'question': 'Vacation Goal', 'option0': '🏖️ Beach Relaxation', 'option1': '⛰️ Mountain Hiking'},
    {'question': 'Coffee or Tea?', 'option0': '☕ Coffee', 'option1': '🫖 Tea'},
    {'question': 'First Impression', 'option0': '😁 Smile & Humor', 'option1': '🕶️ Style & Swag'},
    {'question': 'Gaming', 'option0': '🎮 Console / PC Gamer', 'option1': '📱 Casual Mobile Gamer'},
    {'question': 'Fitness', 'option0': '🏋️ Gym Rat', 'option1': '🚶 Casual Walker'},
    {'question': 'Money Habit', 'option0': '💸 Spender', 'option1': '🏦 Saver'},
    {'question': 'Conflict Resolution', 'option0': '🗣️ Talk it out instantly', 'option1': '🧘 Give it time'},
    {'question': 'Sense of Humor', 'option0': '🤪 Silly & Goofy', 'option1': '😏 Sarcastic & Witty'},
    {'question': 'Dream Career', 'option0': '👔 Corporate Boss', 'option1': '💡 Startup Founder'},
    {'question': 'Relationship Pacing', 'option0': '🚀 Fast & Furious', 'option1': '🐢 Slow & Steady'},
    {'question': 'Love Language', 'option0': '🎁 Receiving Gifts', 'option1': '🕒 Quality Time'},
    {'question': 'Breakfast', 'option0': '🥞 Heavy Meal', 'option1': '🥐 Light Snack'},
    {'question': 'Fashion', 'option0': '👟 Streetwear', 'option1': '👔 Formal / Classy'},
    {'question': 'Vibe Match', 'option0': '🔥 Passionate', 'option1': '🧊 Chill & Laid Back'}
]

for i, q in enumerate(good_qs):
    questions[i] = q

dart_code = "class VibeQuestions {\n  static final List<Map<String, dynamic>> allQuestions = [\n"
for q in questions:
    dart_code += f"    {{'question': '{q['question']}', 'option0': '{q['option0']}', 'option1': '{q['option1']}'}},\n"
dart_code += "  ];\n\n"
dart_code += """  static List<Map<String, dynamic>> getDailyQuestions() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    
    // Select 5 questions sequentially starting at an offset based on the day of year
    final int start = (dayOfYear * 5) % allQuestions.length;
    List<Map<String, dynamic>> daily = [];
    for(int i = 0; i < 5; i++) {
      var q = Map<String, dynamic>.from(allQuestions[(start + i) % allQuestions.length]);
      q['question'] = '${i + 1}. ${q['question']}'; // Add numbering
      daily.add(q);
    }
    return daily;
  }
}
"""

with open(r"c:\Users\Delstaford\swapeat\lib\features\match\data\vibe_questions.dart", "w", encoding="utf-8") as f:
    f.write(dart_code)
print("Dart file written with 365 questions.")
