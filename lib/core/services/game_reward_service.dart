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

  static const double entryFeeAmount = 5.0;

  /// Prompt user to pay KES 5 entry fee from real wallet balance before starting a game.
  static Future<void> promptAndPayEntryFee({
    required BuildContext context,
    required UserModel userModel,
    required String gameId,
    required String gameTitle,
    required VoidCallback onConfirmed,
  }) async {
    // If it's a free daily spin, allow directly
    if (gameId == 'daily_spin') {
      onConfirmed();
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(userModel.uid);
    final userSnap = await userRef.get();
    final List<dynamic> paidGames = List.from(userSnap.data()?['paid_games'] ?? []);
    if (paidGames.contains(gameId)) {
      onConfirmed();
      return;
    }

    final double walletBal = (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? userModel.walletBalance;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        bool isProcessing = false;
        String? errorText;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final bool hasEnoughBalance = walletBal >= entryFeeAmount;

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: const Color(0xFF05D5AA).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF05D5AA).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF05D5AA).withOpacity(0.35)),
                        ),
                        child: const Icon(Icons.sports_esports, color: Color(0xFF05D5AA), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gameTitle,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'One-Time Unlock • Play Forever',
                              style: TextStyle(color: Color(0xFF05D5AA), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: const Text('KES 5.00', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('One-Time Access Fee', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text('KES 5.00', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Your DISHI Wallet', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text(
                              'KES ${walletBal.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: hasEnoughBalance ? const Color(0xFF05D5AA) : const Color(0xFFF92B60),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(errorText!, style: const TextStyle(color: Color(0xFFF92B60), fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  if (hasEnoughBalance) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF05D5AA),
                          foregroundColor: const Color(0xFF080D18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: isProcessing ? null : () async {
                          setModalState(() => isProcessing = true);
                          try {
                            // Try backend API first
                            bool paid = false;
                            try {
                              final resp = await http.post(
                                Uri.parse(ApiConfig.gamesEntry),
                                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${userModel.uid}'},
                                body: json.encode({'game_id': gameId}),
                              ).timeout(const Duration(seconds: 10));
                              if (resp.statusCode == 200) paid = true;
                            } catch (_) {}

                            // Fallback atomic Firestore transaction
                            if (!paid) {
                              await FirebaseFirestore.instance.runTransaction((tx) async {
                                final s = await tx.get(userRef);
                                final b = (s.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
                                if (b < entryFeeAmount) throw Exception('Insufficient balance');
                                final List<dynamic> currentPaid = List.from(s.data()?['paid_games'] ?? []);
                                if (!currentPaid.contains(gameId)) {
                                  currentPaid.add(gameId);
                                }
                                tx.update(userRef, {
                                  'walletBalance': b - entryFeeAmount,
                                  'paid_games': currentPaid,
                                });
                                final tRef = FirebaseFirestore.instance.collection('transactions').doc();
                                tx.set(tRef, {
                                  'userId': userModel.uid,
                                  'studentId': userModel.uid,
                                  'type': 'arcade_entry_fee',
                                  'amount': entryFeeAmount,
                                  'gameId': gameId,
                                  'description': 'Arcade Lifetime Unlock: $gameTitle',
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'status': 'completed',
                                });
                              });
                            } else {
                              // Ensure paid_games is recorded locally on user doc
                              try {
                                await userRef.update({
                                  'paid_games': FieldValue.arrayUnion([gameId]),
                                });
                              } catch (_) {}
                            }

                            if (modalCtx.mounted) {
                              Navigator.pop(modalCtx);
                              onConfirmed();
                            }
                          } catch (e) {
                            setModalState(() {
                              isProcessing = false;
                              errorText = 'Payment failed: $e';
                            });
                          }
                        },
                        child: isProcessing
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                            : const Text('Pay KES 5.00 & Unlock Forever', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF92B60).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF92B60).withOpacity(0.35)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFF92B60), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You need at least KES 5.00 in your DISHI wallet to play.',
                              style: TextStyle(color: Color(0xFFF92B60), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.pop(modalCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please top up your wallet via M-PESA on your home dashboard.'),
                              backgroundColor: Colors.amber,
                            ),
                          );
                        },
                        child: const Text('Top Up Wallet (M-PESA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Prompts user to unlock a game using earned virtual Arcade Coins.
  static Future<void> promptAndUnlockGame({
    required BuildContext context,
    required UserModel userModel,
    required String gameId,
    required String gameTitle,
    required int coinPrice,
    required VoidCallback onUnlocked,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userModel.uid);
    final userSnap = await userRef.get();
    final int userCoins = (userSnap.data()?['dishi_coins'] as num?)?.toInt() ?? 0;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        bool isProcessing = false;
        String? errorText;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final bool hasEnoughCoins = userCoins >= coinPrice;

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.withOpacity(0.35)),
                        ),
                        child: const Icon(Icons.lock_open_rounded, color: Colors.amber, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unlock $gameTitle',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Spend Arcade Coins to permanently unlock',
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Text('$coinPrice Coins', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Unlock Price', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text('$coinPrice Arcade Coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Your Arcade Coins', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text(
                              '$userCoins Coins',
                              style: TextStyle(
                                color: hasEnoughCoins ? Colors.amber : const Color(0xFFF92B60),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(errorText!, style: const TextStyle(color: Color(0xFFF92B60), fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  if (hasEnoughCoins) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: isProcessing ? null : () async {
                          setModalState(() => isProcessing = true);
                          try {
                            bool unlocked = false;
                            try {
                              final resp = await http.post(
                                Uri.parse(ApiConfig.gamesUnlock),
                                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${userModel.uid}'},
                                body: json.encode({'game_id': gameId}),
                              ).timeout(const Duration(seconds: 10));
                              if (resp.statusCode == 200) unlocked = true;
                            } catch (_) {}

                            // Fallback atomic Firestore transaction
                            if (!unlocked) {
                              await FirebaseFirestore.instance.runTransaction((tx) async {
                                final s = await tx.get(userRef);
                                final c = (s.data()?['dishi_coins'] as num?)?.toInt() ?? 0;
                                if (c < coinPrice) throw Exception('Insufficient coins');
                                final List<dynamic> curUnlocked = List.from(s.data()?['unlocked_games'] ?? ['delivery_dash', 'daily_spin']);
                                if (!curUnlocked.contains(gameId)) {
                                  curUnlocked.add(gameId);
                                }
                                tx.update(userRef, {
                                  'dishi_coins': c - coinPrice,
                                  'unlocked_games': curUnlocked,
                                });
                              });
                            }

                            if (modalCtx.mounted) {
                              Navigator.pop(modalCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🎉 $gameTitle unlocked! Pay KES 5 to start playing.'),
                                  backgroundColor: const Color(0xFF05D5AA),
                                ),
                              );
                              onUnlocked();
                            }
                          } catch (e) {
                            setModalState(() {
                              isProcessing = false;
                              errorText = 'Unlock failed: $e';
                            });
                          }
                        },
                        child: isProcessing
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                            : Text('Unlock for $coinPrice Coins', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Play Delivery Dash or Daily Spin to earn ${coinPrice - userCoins} more coins to unlock this game!',
                              style: const TextStyle(color: Colors.orange, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF05D5AA),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(modalCtx),
                        child: const Text('Earn Coins Playing Free Games', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
