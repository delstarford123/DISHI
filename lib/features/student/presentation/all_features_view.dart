import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_model.dart';

// Import actual views
import 'student_ledger_view.dart';
import 'okoa_food_view.dart';
import '../../smartimer/presentation/smarti_chatbot_view.dart';
import '../../smartimer/presentation/timetable_view.dart';
import '../../smartimer/presentation/flashcards_view.dart';
import '../../match/presentation/match_hub_view.dart';
import '../../match/presentation/match_campus_feed_view.dart';
import '../../parent/presentation/parent_security_hub.dart';
import '../../fundi/presentation/fundi_marketplace_view.dart';
import '../../housing/presentation/housing_dashboard_view.dart';
import '../../community/presentation/safety_pins_view.dart';
import '../../deliv/presentation/deliv_driver_dashboard.dart';
import 'split_bill_view.dart';
import 'subscription_manager_view.dart';
import 'health_and_carbon_view.dart';
import 'gift_meal_dialog.dart';
import '../../social/presentation/harambee_view.dart';
import '../../social/presentation/lost_and_found_view.dart';
import '../../social/presentation/gig_board_view.dart';
import '../../social/presentation/event_tickets_view.dart';
import '../../marketplace/presentation/escrow_market_view.dart';
import '../../marketplace/presentation/swipe_exchange_view.dart';
import '../../community/presentation/ar_campus_map_view.dart';
import 'safter_pin_view.dart';
import 'campus_employment_hub.dart';
class AllFeaturesView extends StatelessWidget {
  final UserModel userModel;

  const AllFeaturesView({super.key, required this.userModel});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0C101B);
    const Color cardColor = Color(0xFF131A2A);
    const Color neonCyan = Color(0xFF05D5AA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('All Features & Apps', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          _buildStickyHeader('Core Wallet & Finance'),
          _buildSliverGrid([
            _FeatureItem(icon: Icons.history, label: 'History & Ledger', color: neonCyan, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLedgerView()))),
            _FeatureItem(icon: Icons.fastfood, label: 'Okoa Food', color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OkoaFoodView()))),
            _FeatureItem(icon: Icons.card_giftcard, label: 'Gift Meal', color: Colors.pinkAccent, onTap: () => showDialog(context: context, builder: (_) => const GiftMealDialog())),
            _FeatureItem(icon: Icons.monetization_on, label: 'Request Funds', color: Colors.greenAccent, onTap: () => _showFundMeDialog(context, userModel)),
            _FeatureItem(icon: Icons.call_split, label: 'Split Bill', color: Colors.purpleAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SplitBillView(userModel: userModel)))),
            _FeatureItem(icon: Icons.event_repeat, label: 'Subscriptions', color: Colors.orangeAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionManagerView(userModel: userModel)))),
            _FeatureItem(icon: Icons.savings, label: 'Safter Pin', color: Colors.amber, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafterPinView()))),
          ], cardColor),
          
          _buildStickyHeader('Academic & Study (Smarti)'),
          _buildSliverGrid([
            _FeatureItem(icon: Icons.smart_toy, label: 'AI Chatbot', color: Colors.purpleAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartiChatbotView()))),
            _FeatureItem(icon: Icons.calendar_month, label: 'Timetable', color: Colors.lightBlueAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TimetableView()))),
            _FeatureItem(icon: Icons.style, label: 'Flashcards', color: Colors.yellowAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardsView()))),
          ], cardColor),

          _buildStickyHeader('Student Life & Social (Match)'),
          _buildSliverGrid([
            _FeatureItem(icon: Icons.favorite, label: 'Match Hub', color: Colors.redAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchHubView()))),
            _FeatureItem(icon: Icons.people, label: 'Campus Feed', color: Colors.blueAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCampusFeedView()))),
          ], cardColor),

          _buildStickyHeader('Housing & Services'),
          _buildSliverGrid([
            _FeatureItem(icon: Icons.apartment, label: 'Keja Yangu', color: Colors.tealAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HousingDashboardView(user: userModel.toJson())))),
            _FeatureItem(icon: Icons.handyman, label: 'Fundi Hub', color: Colors.orangeAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FundiMarketplaceView(userModel: userModel)))),
            _FeatureItem(icon: Icons.local_shipping, label: 'DeLiv Driver', color: Colors.deepOrangeAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DelivDriverDashboard(user: userModel.toJson())))),
          ], cardColor),

          _buildStickyHeader('Marketplace & Commerce'),
          _buildSliverGrid([
            _FeatureItem(icon: Icons.storefront, label: 'Escrow Market', color: Colors.blueAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EscrowMarketView(user: userModel.toJson())))),
            _FeatureItem(icon: Icons.sync_alt, label: 'Swipe Exchange', color: Colors.orangeAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SwipeExchangeView(user: userModel.toJson())))),
          ], cardColor),

          _buildStickyHeader('Social & Community'),
          _buildSliverGrid([
            _FeatureItem(icon: Icons.volunteer_activism, label: 'Harambee', color: Colors.pinkAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HarambeeView(user: userModel.toJson())))),
            _FeatureItem(icon: Icons.find_in_page, label: 'Lost & Found', color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LostAndFoundView(user: userModel.toJson())))),
            _FeatureItem(icon: Icons.work_outline, label: 'Campus Gigs Hub', color: Colors.cyanAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CampusEmploymentHubView()))),
            _FeatureItem(icon: Icons.confirmation_num, label: 'Event Tickets', color: Colors.purpleAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventTicketsView(user: userModel.toJson())))),
          ], cardColor),

          _buildStickyHeader('Advanced Tech'),
          _buildSliverGrid([
            _FeatureItem(icon: Icons.view_in_ar, label: 'AR Campus Map', color: Colors.greenAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArCampusMapView()))),
          ], cardColor),

          _buildStickyHeader('Family & Safety'),
          _buildSliverGrid([
            _FeatureItem(icon: Icons.family_restroom, label: 'Oversight Center', color: Colors.indigoAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParentSecurityHub()))),
            _FeatureItem(icon: Icons.security, label: 'Safety Pins', color: Colors.red, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SafetyPinsView()))),
          ], cardColor),

          _buildStickyHeader('Health & Environment'),
          _buildSliverGrid([
            _FeatureItem(icon: Icons.eco, label: 'Health & Impact', color: Colors.greenAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HealthAndCarbonView(userModel: userModel)))),
          ], cardColor),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon!', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFundMeDialog(BuildContext context, UserModel userModel) {
    const Color cardColor = Color(0xFF131A2A);
    const Color neonPink = Color(0xFFF92B60);
    const Color neonCyan = Color(0xFF05D5AA);
    const Color textSecondary = Color(0xFF8B9BB4);
    const Color surfaceLight = Color(0xFF1A2235);

    String currentDishiId = userModel.uid;
    final link = 'https://dishi.delstarfordworks.co.ke/fund?dishi_id=$currentDishiId';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: neonPink.withOpacity(0.5))),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: neonPink, size: 28),
            SizedBox(width: 8),
            Text('Fund Me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this link with your parents, guardians, or friends. They can fund your wallet directly via M-PESA.',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: surfaceLight),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(color: neonCyan, fontSize: 13, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fund Me link copied to clipboard!'), backgroundColor: neonCyan, duration: Duration(seconds: 3)));
                },
                icon: const Icon(Icons.copy, color: Colors.black),
                label: const Text('Copy Link', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonCyan,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(String title) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyHeaderDelegate(
        minHeight: 40,
        maxHeight: 40,
        child: Container(
          color: const Color(0xFF0C101B), // Match bgColor
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverGrid(List<_FeatureItem> items, Color cardColor) {
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 24.0),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: GridView.count(
            crossAxisCount: 4,
            childAspectRatio: 0.70,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 16,
            crossAxisSpacing: 8,
            children: items.map((item) => _buildGridItem(item)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(_FeatureItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _FeatureItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
