import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'coins_display.dart';

class CampusQuizzerGame extends StatefulWidget {
  final UserModel userModel;

  const CampusQuizzerGame({super.key, required this.userModel});

  @override
  State<CampusQuizzerGame> createState() => _CampusQuizzerGameState();
}

class Question {
  final String text;
  final List<String> options;
  final int correctAnswerIndex;

  Question(this.text, this.options, this.correctAnswerIndex);
}

class _CampusQuizzerGameState extends State<CampusQuizzerGame> with SingleTickerProviderStateMixin {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);
  final Color _cardColor = const Color(0xFF131A2A);

  List<Question> questions = [];
  int currentQuestionIndex = 0;
  int score = 0;
  bool isGameOver = false;
  
  late AnimationController _timerController;
  int? selectedAnswer;
  bool isAnswered = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..addListener(() {
        setState(() {});
      });

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !isAnswered) {
        _handleTimeout();
      }
    });

    _timerController.forward();
  }

  void _loadQuestions() {
    questions = [
      Question("Which of these is NOT a valid programming language?", ["Python", "Java", "Cobra", "Ruby"], 2),
      Question("What is the main ingredient in guacamole?", ["Tomato", "Avocado", "Onion", "Lime"], 1),
      Question("In computer science, what does 'UI' stand for?", ["User Integration", "Universal Interface", "User Interface", "United Inputs"], 2),
      Question("What is the name of the popular campus food that consists of flatbread and beans?", ["Madondo", "Smocha", "Rolex", "Chips Mwitu"], 0),
      Question("Which tech giant created Flutter?", ["Apple", "Facebook", "Google", "Microsoft"], 2),
      Question("What does a 'HTTP 404' error mean?", ["Forbidden", "Internal Server Error", "Bad Request", "Not Found"], 3),
    ];
    questions.shuffle();
  }

  void _handleTimeout() {
    if (isAnswered) return;
    setState(() {
      isAnswered = true;
      selectedAnswer = -1; // -1 means timeout
    });
    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  void _handleAnswer(int index) {
    if (isAnswered) return;
    
    _timerController.stop();
    setState(() {
      isAnswered = true;
      selectedAnswer = index;
      if (index == questions[currentQuestionIndex].correctAnswerIndex) {
        score += 20;
      }
    });

    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        isAnswered = false;
        selectedAnswer = null;
      });
      _timerController.reset();
      _timerController.forward();
    } else {
      _showGameOver();
    }
  }

  void _showGameOver() {
    setState(() {
      isGameOver = true;
    });
    _submitScore();
  }

  Future<void> _submitScore() async {
    try {
      await http.post(
        Uri.parse('https://swapeatbackend.vercel.app/api/v1/games/score'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.userModel.uid}'},
        body: json.encode({'game_id': 'campus_quizzer', 'score': score}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      print("Error submitting quiz score: \$e");
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Campus Quizzer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        actions: [
          CoinsDisplay(uid: widget.userModel.uid),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('Score: $score', style: TextStyle(color: _neonCyan, fontSize: 18, fontWeight: FontWeight.bold))),
          )
        ],
      ),
      body: isGameOver ? _buildGameOver() : _buildQuiz(),
    );
  }

  Widget _buildQuiz() {
    if (questions.isEmpty) return const Center(child: CircularProgressIndicator());

    final question = questions[currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question ${currentQuestionIndex + 1} of ${questions.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: 1.0 - _timerController.value,
            backgroundColor: _cardColor,
            color: _timerController.value > 0.7 ? _neonPink : _neonCyan,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Text(
              question.text,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          ...List.generate(question.options.length, (index) {
            bool isSelected = selectedAnswer == index;
            bool isCorrect = index == question.correctAnswerIndex;
            
            Color btnColor = _cardColor;
            Color textColor = Colors.white;
            BorderSide border = BorderSide(color: Colors.white.withOpacity(0.1));

            if (isAnswered) {
              if (isCorrect) {
                btnColor = _neonCyan.withOpacity(0.2);
                border = BorderSide(color: _neonCyan, width: 2);
                textColor = _neonCyan;
              } else if (isSelected) {
                btnColor = _neonPink.withOpacity(0.2);
                border = BorderSide(color: _neonPink, width: 2);
                textColor = _neonPink;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: InkWell(
                onTap: () => _handleAnswer(index),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: btnColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.fromBorderSide(border),
                  ),
                  child: Text(
                    question.options[index],
                    style: TextStyle(color: textColor, fontSize: 18),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 100),
          const SizedBox(height: 20),
          const Text(
            'Quiz Completed!',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Final Score: $score',
            style: TextStyle(color: _neonCyan, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonCyan,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('BACK TO HUB', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
