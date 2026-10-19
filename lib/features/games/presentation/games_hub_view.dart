import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import 'delivery_dash_game.dart';
import 'hungry_fresher_game.dart';
import 'swapeat_drop_game.dart';
import 'bite_ninja_game.dart';
import 'taste_match_game.dart';
import 'campus_quizzer_game.dart';
import 'memory_match_game.dart';
import 'daily_spin_game.dart';
import 'scavenger_hunt_game.dart';
import 'dorm_tycoon_game.dart';
import 'redeem_store_view.dart';
import 'vibe_check_game.dart';
import 'scratch_win_game.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/game_reward_service.dart';

class GamesHubView extends StatefulWidget {
  final UserModel userModel;

  const GamesHubView({super.key, required this.userModel});

  @override
  State<GamesHubView> createState() => _GamesHubViewState();
}

class _GamesHubViewState extends State<GamesHubView> {
  final Color _bgColor = const Color(0xFF0C101B);
  final Color _cardColor = const Color(0xFF131A2A);
  final Color _neonCyan = const Color(0xFF05D5AA);
  final Color _neonPink = const Color(0xFFF92B60);

  int _dishiCoins = 0;

  @override
  void initState() {
    super.initState();
    _dishiCoins = ((widget.userModel.toJson()['dishi_coins'] ?? 0) as num).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text('Games Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).snapshots(),
        builder: (context, userSnap) {
          int currentCoins = _dishiCoins;
          double currentWallet = widget.userModel.walletBalance;
          List<String> unlockedGames = ['delivery_dash', 'daily_spin'];
          List<String> paidGames = [];

          if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
            final data = userSnap.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              if (data['dishi_coins'] != null) {
                currentCoins = (data['dishi_coins'] as num).toInt();
                _dishiCoins = currentCoins;
              }
              if (data['walletBalance'] != null) {
                currentWallet = (data['walletBalance'] as num).toDouble();
              }
              if (data['unlocked_games'] != null) {
                unlockedGames = List<String>.from(data['unlocked_games']);
              }
              if (data['paid_games'] != null) {
                paidGames = List<String>.from(data['paid_games']);
              }
            }
          }

          return CustomScrollView(
            slivers: [
              // Header / Wallet Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0D2A20),
                          _cardColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _neonCyan.withValues(alpha: 0.35)),
                      boxShadow: [
                        BoxShadow(color: _neonCyan.withValues(alpha: 0.12), blurRadius: 24, spreadRadius: -4),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Arcade Coins', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12, letterSpacing: 0.5)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                      ),
                                      child: const Text('In-App Only', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                                    const SizedBox(width: 8),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 400),
                                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                                      child: Text(
                                        '$currentCoins',
                                        key: ValueKey<int>(currentCoins),
                                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Coins', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => RedeemStoreView(userModel: widget.userModel)));
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [_neonCyan.withValues(alpha: 0.25), _neonCyan.withValues(alpha: 0.1)]),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: _neonCyan),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.storefront_outlined, color: _neonCyan, size: 16),
                                    const SizedBox(width: 6),
                                    Text('Arcade Store', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Real Wallet & Notice Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet, color: Color(0xFF05D5AA), size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Wallet: KES ${currentWallet.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              const Text(
                                'Unlock Once: KES 5',
                                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Stats row from user_game_stats
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('user_game_stats').doc(widget.userModel.uid).snapshots(),
                          builder: (ctx, statsSnap) {
                            int gamesPlayed = 0;
                            bool canSpin = true;
                            if (statsSnap.hasData && statsSnap.data!.exists) {
                              final d = statsSnap.data!.data() as Map<String, dynamic>;
                              gamesPlayed = d.keys.where((k) => k.startsWith('best_')).length;
                              final lastSpin = d['last_spin'];
                              if (lastSpin != null) {
                                final lastSpinDt = (lastSpin as dynamic).toDate() as DateTime;
                                canSpin = DateTime.now().difference(lastSpinDt).inHours >= 24;
                              }
                            }
                            return Row(
                              children: [
                                _statChip(Icons.sports_esports_outlined, '$gamesPlayed', 'Played'),
                                const SizedBox(width: 8),
                                _statChip(Icons.lock_open, '${unlockedGames.length}/12', 'Unlocked', color: Colors.amber),
                                const SizedBox(width: 8),
                                _statChip(
                                  canSpin ? Icons.casino_outlined : Icons.timer_outlined,
                                  canSpin ? 'Free Spin' : '24h wait',
                                  'Daily Spin',
                                  color: canSpin ? Colors.greenAccent : Colors.orange,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                sliver: SliverToBoxAdapter(
                  child: Text('Arcade & Casual', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildGamesGrid([
                _GameItem(gameId: 'delivery_dash', title: 'Delivery Dash', icon: Icons.two_wheeler, color: Colors.orange, isReady: true, coinCost: 0, imagePath: 'assets/img/game_bg_delivery_dash_1790106266034.jpg', routeBuilder: (context) => DeliveryDashGame(userModel: widget.userModel)),
                _GameItem(gameId: 'dishi_drop', title: 'DISHI Drop', icon: Icons.fastfood, color: Colors.greenAccent, isReady: true, coinCost: 300, imagePath: 'assets/img/game_bg_dishi_drop_1790106402294.jpg', routeBuilder: (context) => SwapEatDropGame(userModel: widget.userModel)),
                _GameItem(gameId: 'hungry_fresher', title: 'Hungry Fresher', icon: Icons.gesture, color: _neonCyan, isReady: true, coinCost: 400, imagePath: 'assets/img/game_bg_hungry_fresher_1790106457208.jpg', routeBuilder: (context) => HungryFresherGame(userModel: widget.userModel)),
                _GameItem(gameId: 'bite_ninja', title: 'Bite Ninja', icon: Icons.content_cut, color: Colors.redAccent, isReady: true, coinCost: 500, imagePath: 'assets/img/game_bg_bite_ninja_1790106469828.jpg', routeBuilder: (context) => BiteNinjaGame(userModel: widget.userModel)),
              ], unlockedGames, paidGames),

              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Text('Social & Matching', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildGamesGrid([
                _GameItem(gameId: 'taste_match', title: 'Taste Match', icon: Icons.favorite, color: _neonPink, isReady: true, coinCost: 600, imagePath: 'assets/img/game_bg_taste_match_1790106482123.jpg', routeBuilder: (context) => TasteMatchGame(userModel: widget.userModel)),
                _GameItem(gameId: 'vibe_check', title: 'Vibe Check', icon: Icons.local_fire_department, color: Colors.orangeAccent, isReady: true, coinCost: 700, imagePath: 'assets/img/game_bg_vibe_check_1790106492811.jpg', routeBuilder: (context) => VibeCheckGame(userModel: widget.userModel)),
                _GameItem(gameId: 'campus_quizzer', title: 'Campus Quizzer', icon: Icons.quiz, color: Colors.purpleAccent, isReady: true, coinCost: 800, imagePath: 'assets/img/game_bg_campus_quizzer_1790106560687.jpg', routeBuilder: (context) => CampusQuizzerGame(userModel: widget.userModel)),
                _GameItem(gameId: 'memory_match', title: 'Memory Match', icon: Icons.grid_view, color: Colors.blueAccent, isReady: true, coinCost: 1000, imagePath: 'assets/img/game_bg_memory_match_1790106573115.jpg', routeBuilder: (context) => MemoryMatchGame(userModel: widget.userModel)),
              ], unlockedGames, paidGames),

              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Text('Daily Rewards & Progression', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildGamesGrid([
                _GameItem(gameId: 'daily_spin', title: 'Daily Spin', icon: Icons.casino, color: Colors.yellowAccent, isReady: true, coinCost: 0, imagePath: 'assets/img/game_bg_daily_spin_1790106586127.jpg', routeBuilder: (context) => DailySpinGame(userModel: widget.userModel)),
                _GameItem(gameId: 'scratch_win', title: 'Scratch & Win', icon: Icons.receipt, color: Colors.cyanAccent, isReady: true, coinCost: 1200, imagePath: 'assets/img/game_bg_scratch_win_1790106598873.jpg', routeBuilder: (context) => ScratchWinGame(userModel: widget.userModel)),
                _GameItem(gameId: 'dorm_tycoon', title: 'Dorm Tycoon', icon: Icons.store, color: Colors.tealAccent, isReady: true, coinCost: 1500, imagePath: 'assets/img/game_bg_dorm_tycoon_1790106611964.jpg', routeBuilder: (context) => DormTycoonGame(userModel: widget.userModel)),
                _GameItem(gameId: 'scavenger_hunt', title: 'Scavenger Hunt', icon: Icons.map, color: Colors.lightGreenAccent, isReady: true, coinCost: 2000, imagePath: 'assets/img/game_bg_scavenger_hunt_1790106624202.jpg', routeBuilder: (context) => ScavengerHuntGame(userModel: widget.userModel)),
              ], unlockedGames, paidGames),

              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          );
        },
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, {Color? color}) {
    final chipColor = color ?? const Color(0xFF05D5AA);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: chipColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: chipColor, size: 16),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: chipColor.withValues(alpha: 0.7), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesGrid(List<_GameItem> games, List<String> unlockedGames, List<String> paidGames) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 16.0,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final game = games[index];
            final bool isUnlocked = unlockedGames.contains(game.gameId) || game.coinCost == 0;
            final bool isPaid = paidGames.contains(game.gameId) || game.gameId == 'daily_spin';

            return InkWell(
              onTap: () {
                if (!game.isReady || game.routeBuilder == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${game.title} is coming soon!'), backgroundColor: _neonCyan),
                  );
                  return;
                }

                if (!isUnlocked) {
                  // Game is locked -> prompt user to unlock with Arcade Coins
                  GameRewardService.promptAndUnlockGame(
                    context: context,
                    userModel: widget.userModel,
                    gameId: game.gameId,
                    gameTitle: game.title,
                    coinPrice: game.coinCost,
                    onUnlocked: () {
                      setState(() {});
                    },
                  );
                } else if (isPaid) {
                  // Game already paid once -> permanent lifetime access!
                  Navigator.push(context, MaterialPageRoute(builder: game.routeBuilder!));
                } else {
                  // Game is unlocked -> prompt user to pay one-time entry fee
                  GameRewardService.promptAndPayEntryFee(
                    context: context,
                    userModel: widget.userModel,
                    gameId: game.gameId,
                    gameTitle: game.title,
                    onConfirmed: () {
                      Navigator.push(context, MaterialPageRoute(builder: game.routeBuilder!));
                    },
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPaid
                        ? _neonCyan.withValues(alpha: 0.35)
                        : isUnlocked
                            ? Colors.amber.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.08),
                    width: isPaid ? 1.5 : 1.0,
                  ),
                  image: game.imagePath != null
                      ? DecorationImage(
                          image: AssetImage(game.imagePath!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: isUnlocked ? 0.65 : 0.82),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: game.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: game.color.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 1),
                            ],
                          ),
                          child: Icon(game.icon, color: game.color, size: 36),
                        ),
                        if (!isUnlocked)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                              child: const Icon(Icons.lock, color: Colors.black, size: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      game.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (!game.isReady)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Coming Soon', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      )
                    else if (!isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, color: Colors.amber, size: 11),
                            const SizedBox(width: 4),
                            Text('${game.coinCost} Coins', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (isPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _neonCyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _neonCyan.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(game.gameId == 'daily_spin' ? Icons.casino_outlined : Icons.check_circle_outline, color: _neonCyan, size: 11),
                            const SizedBox(width: 4),
                            Text(
                              game.gameId == 'daily_spin' ? 'Free Spin' : 'Play Now',
                              style: const TextStyle(color: Color(0xFF05D5AA), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on_outlined, color: Colors.amber, size: 11),
                            SizedBox(width: 4),
                            Text(
                              'Unlock (KES 5)',
                              style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          childCount: games.length,
        ),
      ),
    );
  }
}

class _GameItem {
  final String gameId;
  final String title;
  final IconData icon;
  final Color color;
  final bool isReady;
  final int coinCost;
  final String? imagePath;
  final WidgetBuilder? routeBuilder;

  _GameItem({
    required this.gameId,
    required this.title,
    required this.icon,
    required this.color,
    this.isReady = false,
    this.coinCost = 0,
    this.imagePath,
    this.routeBuilder,
  });
}
