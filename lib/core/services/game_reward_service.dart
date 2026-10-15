import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'api_config.dart';
import '../../features/games/presentation/redeem_store_view.dart';

class GameRewardResult {
  final int score;
  final int coinsEarned;
  final bool isNewHighScore;
  final bool wasSuccessful;

  GameRewardResult({
    required this.score,
    required this.coinsEarned,
    required this.isNewHighScore,
    required this.wasSuccessful,
  });
}

class GameRewardService {
  /// Submits the game score to the backend API with an automatic, resilient
  /// direct Firestore fallback. This ensures the user NEVER loses earned Dishi Coins.
  static Future<GameRewardResult> submitScore({
    required String uid,
    required String gameId,
    required int score,
    int? overrideCoins,
  }) async {
    int coins = 0;
    if (overrideCoins != null) {
      coins = overrideCoins;
    } else {
      final scaleFactors = {
        'scratch_win': 100,
        'daily_spin': 1,
        'dorm_tycoon': 10,
        'delivery_dash': 10,
      };
      final factor = scaleFactors[gameId] ?? 10;
      coins = score ~/ factor;
      if (score > 0 && coins == 0) coins = 1; // Minimum 1 coin for playing
    }

    bool isNewHighScore = false;
    bool submittedViaApi = false;

    // 1. Try backend API
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.gamesScore),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $uid',
        },
        body: json.encode({
          'game_id': gameId,
          'score': score,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        submittedViaApi = true;
        final resData = json.decode(response.body);
        if (resData['coins_earned'] != null) {
          coins = (resData['coins_earned'] as num).toInt();
        }
      }
    } catch (_) {
      submittedViaApi = false;
    }

    // 2. Direct Firestore fallback (Guarantees coins and best score are ALWAYS saved)
    try {
      final statsRef = FirebaseFirestore.instance.collection('user_game_stats').doc(uid);
      final statsSnap = await statsRef.get();
      final currentBest = (statsSnap.data()?[ 'best_$gameId'] ?? 0) as int;
      if (score > currentBest) {
        isNewHighScore = true;
        await statsRef.set({'best_$gameId': score}, SetOptions(merge: true));
      }

      if (!submittedViaApi && coins > 0) {
        // Direct increment user coins
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'dishi_coins': FieldValue.increment(coins),
        }, SetOptions(merge: true));

        // Add to leaderboards collection
        await FirebaseFirestore.instance.collection('game_leaderboards').add({
          'uid': uid,
          'game_id': gameId,
          'score': score,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating local Firestore stats: $e');
    }

    return GameRewardResult(
      score: score,
      coinsEarned: coins,
      isNewHighScore: isNewHighScore,
      wasSuccessful: true,
    );
  }

  /// Displays an ultra-polished, arcade-style Game Over dialog with neon aesthetics,
  /// animated coin rewards, and instant navigation to the Redeem Store.
  static void showArcadeGameOverDialog({
    required BuildContext context,
    required UserModel userModel,
    required String gameTitle,
    required int score,
    required int coinsEarned,
    required VoidCallback onPlayAgain,
    String? scoreLabel,
    bool isVictory = false,
  }) {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF131A2A), Color(0xFF0C101B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isVictory ? const Color(0xFF05D5AA) : const Color(0xFFF92B60).withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isVictory ? const Color(0xFF05D5AA) : const Color(0xFFF92B60)).withOpacity(0.25),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isVictory ? const Color(0xFF05D5AA) : const Color(0xFFF92B60)).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isVictory ? const Color(0xFF05D5AA) : const Color(0xFFF92B60),
                    ),
                  ),
                  child: Text(
                    isVictory ? 'VICTORY! 🏆' : 'ROUND OVER 🎮',
                    style: TextStyle(
                      color: isVictory ? const Color(0xFF05D5AA) : const Color(0xFFF92B60),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  gameTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),

                // Score Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        scoreLabel ?? 'FINAL SCORE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Coins reward
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withOpacity(0.2),
                              Colors.amber.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              '+$coinsEarned Dishi Coins Won!',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    // Play Again
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF05D5AA),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onPlayAgain();
                        },
                        icon: const Icon(Icons.replay, size: 20),
                        label: const Text(
                          'PLAY AGAIN',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Redeem Store Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purpleAccent.withOpacity(0.25),
                            Colors.purpleAccent.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purpleAccent.withOpacity(0.6)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.storefront, color: Colors.purpleAccent),
                        tooltip: 'Redeem Coins',
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RedeemStoreView(userModel: userModel),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Back to Hub Text Button
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // back to games hub
                  },
                  child: Text(
                    'Back to Games Hub',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
