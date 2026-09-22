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
      body: CustomScrollView(
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
                  border: Border.all(color: _neonCyan.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(color: _neonCyan.withOpacity(0.12), blurRadius: 24, spreadRadius: -4),
                  ],
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).snapshots(),
                  builder: (context, snapshot) {
                    int currentCoins = _dishiCoins;
                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data['dishi_coins'] != null) {
                        currentCoins = (data['dishi_coins'] as num).toInt();
                        _dishiCoins = currentCoins;
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dishi Coins Balance', style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, letterSpacing: 0.5)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.monetization_on, color: Colors.amber, size: 30),
                                    const SizedBox(width: 8),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 400),
                                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                                      child: Text(
                                        '$currentCoins',
                                        key: ValueKey<int>(currentCoins),
                                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('pts', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w600)),
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [_neonCyan.withOpacity(0.25), _neonCyan.withOpacity(0.1)]),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: _neonCyan),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.storefront_outlined, color: _neonCyan, size: 16),
                                    const SizedBox(width: 6),
                                    Text('Redeem', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Stats row from user_game_stats
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('user_game_stats').doc(widget.userModel.uid).snapshots(),
                          builder: (ctx, statsSnap) {
                            int gamesPlayed = 0;
                            int totalEarned = 0;
                            bool canSpin = true;
                            if (statsSnap.hasData && statsSnap.data!.exists) {
                              final d = statsSnap.data!.data() as Map<String, dynamic>;
                              // Count fields that look like best_<game_id>
                              gamesPlayed = d.keys.where((k) => k.startsWith('best_')).length;
                              // last_spin cooldown check
                              final lastSpin = d['last_spin'];
                              if (lastSpin != null) {
                                final lastSpinDt = (lastSpin as dynamic).toDate() as DateTime;
                                canSpin = DateTime.now().difference(lastSpinDt).inHours >= 24;
                              }
                            }
                            return Row(
                              children: [
                                _statChip(Icons.sports_esports_outlined, '$gamesPlayed', 'Games'),
                                const SizedBox(width: 10),
                                _statChip(Icons.monetization_on_outlined, '$currentCoins', 'Total Coins'),
                                const SizedBox(width: 10),
                                _statChip(
                                  canSpin ? Icons.casino_outlined : Icons.timer_outlined,
                                  canSpin ? 'Ready' : '24h wait',
                                  'Daily Spin',
                                  color: canSpin ? Colors.greenAccent : Colors.orange,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            sliver: SliverToBoxAdapter(
              child: Text('Arcade & Casual', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          _buildGamesGrid([
            _GameItem(title: 'Delivery Dash', icon: Icons.two_wheeler, color: Colors.orange, isReady: true, routeBuilder: (context) => DeliveryDashGame(userModel: widget.userModel)),
            _GameItem(title: 'DISHI Drop', icon: Icons.fastfood, color: Colors.greenAccent, isReady: true, routeBuilder: (context) => SwapEatDropGame(userModel: widget.userModel)),
            _GameItem(title: 'Hungry Fresher', icon: Icons.gesture, color: _neonCyan, isReady: true, routeBuilder: (context) => HungryFresherGame(userModel: widget.userModel)),
            _GameItem(title: 'Bite Ninja', icon: Icons.content_cut, color: Colors.redAccent, isReady: true, routeBuilder: (context) => BiteNinjaGame(userModel: widget.userModel)),
          ]),

          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            sliver: SliverToBoxAdapter(
              child: Text('Social & Matching', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          _buildGamesGrid([
            _GameItem(title: 'Taste Match', icon: Icons.favorite, color: _neonPink, isReady: true, routeBuilder: (context) => TasteMatchGame(userModel: widget.userModel)),
            _GameItem(title: 'Vibe Check', icon: Icons.local_fire_department, color: Colors.orangeAccent, isReady: true, routeBuilder: (context) => VibeCheckGame(userModel: widget.userModel)),
            _GameItem(title: 'Campus Quizzer', icon: Icons.quiz, color: Colors.purpleAccent, isReady: true, routeBuilder: (context) => CampusQuizzerGame(userModel: widget.userModel)),
            _GameItem(title: 'Memory Match', icon: Icons.grid_view, color: Colors.blueAccent, isReady: true, routeBuilder: (context) => MemoryMatchGame(userModel: widget.userModel)),
          ]),

          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            sliver: SliverToBoxAdapter(
              child: Text('Daily Rewards & Progression', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          _buildGamesGrid([
            _GameItem(title: 'Daily Spin', icon: Icons.casino, color: Colors.yellowAccent, isReady: true, routeBuilder: (context) => DailySpinGame(userModel: widget.userModel)),
            _GameItem(title: 'Scratch & Win', icon: Icons.receipt, color: Colors.cyanAccent, isReady: true, routeBuilder: (context) => ScratchWinGame(userModel: widget.userModel)),
            _GameItem(title: 'Dorm Tycoon', icon: Icons.store, color: Colors.tealAccent, isReady: true, routeBuilder: (context) => DormTycoonGame(userModel: widget.userModel)),
            _GameItem(title: 'Scavenger Hunt', icon: Icons.map, color: Colors.lightGreenAccent, isReady: true, routeBuilder: (context) => ScavengerHuntGame(userModel: widget.userModel)),
          ]),
          
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, {Color? color}) {
    final chipColor = color ?? const Color(0xFF05D5AA);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: chipColor.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: chipColor, size: 18),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: chipColor.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesGrid(List<_GameItem> games) {
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
            return InkWell(
              onTap: () {
                if (!game.isReady || game.routeBuilder == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${game.title} is coming soon!'), backgroundColor: _neonCyan),
                  );
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: game.routeBuilder!));
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: game.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: game.color.withOpacity(0.2), blurRadius: 20, spreadRadius: 1),
                        ],
                      ),
                      child: Icon(game.icon, color: game.color, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      game.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (!game.isReady)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Coming Soon', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _neonCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Play Now', style: TextStyle(color: Color(0xFF05D5AA), fontSize: 10, fontWeight: FontWeight.bold)),
                      )
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
  final String title;
  final IconData icon;
  final Color color;
  final bool isReady;
  final WidgetBuilder? routeBuilder;

  _GameItem({
    required this.title,
    required this.icon,
    required this.color,
    this.isReady = false,
    this.routeBuilder,
  });
}
