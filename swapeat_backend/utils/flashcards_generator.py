import random

def get_365_flashcards():
    categories = ['Academics', 'Relationships', 'Games', 'History', 'Trivia']
    
    # Base set of compelling flashcards
    base_cards = [
        {"category": "Academics", "question": "What is the Pomodoro Technique?", "answer": "A time management method: 25 mins of focused work, followed by a 5 min break."},
        {"category": "Academics", "question": "What is active recall?", "answer": "Testing yourself on material rather than just passively re-reading it."},
        {"category": "Academics", "question": "Best way to beat procrastination?", "answer": "The '2-Minute Rule': if it takes less than 2 mins, do it right now."},
        {"category": "Relationships", "question": "What are the 5 Love Languages?", "answer": "Words of Affirmation, Quality Time, Receiving Gifts, Acts of Service, Physical Touch."},
        {"category": "Relationships", "question": "What is the 80/20 rule in dating?", "answer": "Don't expect one person to fulfill 100% of your needs; 80% is incredible."},
        {"category": "Relationships", "question": "How to handle a disagreement effectively?", "answer": "Use 'I' statements instead of 'You' statements. E.g., 'I feel overwhelmed when...'"},
        {"category": "Games", "question": "What is the Konami Code?", "answer": "Up, Up, Down, Down, Left, Right, Left, Right, B, A."},
        {"category": "Games", "question": "Best strategy in Monopoly?", "answer": "Buy the Orange properties! They get landed on most often due to the Jail square."},
        {"category": "Games", "question": "Most sold video game of all time?", "answer": "Minecraft (over 300 million copies)."},
        {"category": "History", "question": "Who was the first computer programmer?", "answer": "Ada Lovelace, in the mid-1800s."},
        {"category": "History", "question": "When did the first iPhone launch?", "answer": "June 29, 2007, changing campus life forever."},
        {"category": "History", "question": "What was the first university in the world?", "answer": "The University of al-Qarawiyyin in Morocco, founded in 859 AD."},
        {"category": "Trivia", "question": "How much coffee does the average student drink?", "answer": "About 3.2 cups a day during finals week!"},
        {"category": "Trivia", "question": "What is the 'Freshman 15'?", "answer": "A myth! Studies show the average weight gain is actually only 2.5 to 3.5 pounds."},
        {"category": "Trivia", "question": "Why is a marathon exactly 26.2 miles?", "answer": "To accommodate the British Royal Family at the 1908 London Olympics."},
    ]

    cards = []
    
    # First add the handcrafted ones
    for card in base_cards:
        cards.append(card)
        
    # Generate the rest to reach 365
    while len(cards) < 365:
        idx = len(cards) + 1
        cat = categories[idx % len(categories)]
        
        if cat == 'Academics':
            q = f"Study Tip #{idx}: How to optimize your study environment?"
            a = f"Ensure good lighting, minimize phone distractions, and try to study in a dedicated space. Tip #{idx}."
        elif cat == 'Relationships':
            q = f"Relationship Advice #{idx}: Icebreaker idea?"
            a = f"Ask them about their favorite campus meal or a controversial food opinion. Tip #{idx}."
        elif cat == 'Games':
            q = f"Gaming Fact #{idx}: Retro gaming trivia."
            a = f"Did you know classic arcade games used to cost just a quarter? Level #{idx}."
        elif cat == 'History':
            q = f"On this day in Campus History #{idx}..."
            a = f"A major technological breakthrough occurred that shaped modern student life. Fact #{idx}."
        else:
            q = f"Daily Trivia #{idx} for Campus Life!"
            a = f"Remember to stay hydrated and get at least 7 hours of sleep. Trivia #{idx}."
            
        cards.append({"category": cat, "question": q, "answer": a})

    return cards
