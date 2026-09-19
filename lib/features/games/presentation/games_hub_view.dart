import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/mpesa_theme.dart';
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
    _dishiCoins = (widget.userModel.toJson()['dishi_coins'] ?? 0) as int;
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
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_cardColor, _cardColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _neonCyan.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(color: _neonCyan.withOpacity(0.1), blurRadius: 20, spreadRadius: -5),
                  ],
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.userModel.uid).snapshots(),
                  builder: (context, snapshot) {
                    int currentCoins = _dishiCoins;
                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data['dishi_coins'] != null) {
                        currentCoins = data['dishi_coins'] as int;
                        _dishiCoins = currentCoins;
                      }
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dishi Coins Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  '$currentCoins',
                                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => RedeemStoreView(userModel: widget.userModel)));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _neonCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: _neonCyan),
                            ),
                            child: const Text('Redeem', style: TextStyle(color: Color(0xFF05D5AA), fontWeight: FontWeight.bold)),
                          ),
                        )
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
