import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/user_model.dart';

// Import actual student & cross-dashboard views
import 'student_ledger_view.dart';
import 'student_transfers_view.dart';
import 'student_preorders_view.dart';
import 'vendor_directory_view.dart';
import 'okoa_food_view.dart';
import 'split_bill_view.dart';
import 'virtual_card_view.dart';
import 'subscription_manager_view.dart';
import 'health_and_carbon_view.dart';
import 'safter_pin_view.dart';
import 'campus_employment_hub.dart';
import 'campus_map_view.dart';
import 'nearby_services_map_view.dart';
import 'gift_meal_dialog.dart';
import 'request_funds_view.dart';

// Academic / Smarti
import '../../smartimer/presentation/smarti_chatbot_view.dart';
import '../../smartimer/presentation/timetable_view.dart';
import '../../smartimer/presentation/flashcards_view.dart';

// Social / UniUptown
import '../../match/presentation/match_hub_view.dart';
import '../../match/presentation/match_campus_feed_view.dart';
import '../../match/presentation/meetup_share_view.dart';

// Housing
import '../../housing/presentation/housing_dashboard_view.dart';
import '../../housing/presentation/housing_marketplace_view.dart';
import '../../fundi/presentation/fundi_marketplace_view.dart';

// Delivery
import '../../deliv/presentation/deliv_driver_dashboard.dart';
import '../../deliv/presentation/deliv_registration_view.dart';

// Games
import '../../games/presentation/games_hub_view.dart';
import '../../games/presentation/redeem_store_view.dart';
import '../../games/presentation/daily_spin_game.dart';

// Community / Marketplace / Safety
import '../../community/presentation/safety_pins_view.dart';
import '../../community/presentation/ar_campus_map_view.dart';
import '../../marketplace/presentation/escrow_market_view.dart';
import '../../marketplace/presentation/swipe_exchange_view.dart';
import '../../social/presentation/harambee_view.dart';
import '../../social/presentation/lost_and_found_view.dart';
import '../../social/presentation/gig_board_view.dart';
import '../../social/presentation/event_tickets_view.dart';
import '../../parent/presentation/parent_security_hub.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class AppFeature {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const AppFeature({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    this.badge,
    required this.onTap,
  });
}

class AllFeaturesView extends StatefulWidget {
  final UserModel userModel;

  const AllFeaturesView({super.key, required this.userModel});

  @override
  State<AllFeaturesView> createState() => _AllFeaturesViewState();
}

class _AllFeaturesViewState extends State<AllFeaturesView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Finance & Pay',
    'Dining & Food',
    'Campus Gigs',
    'Keja Housing',
    'Games & Rewards',
    'Smarti Study',
    'Social & Match',
    'Safety & Maps',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppFeature> _buildAllFeatures(BuildContext context) {
    final userModel = widget.userModel;

    return [
      // ── Finance & Pay ──
      AppFeature(
        id: 'p2p_transfer',
        title: 'Send Money',
        subtitle: 'Instant 0% fee transfer to students via DISHI ID or phone',
        category: 'Finance & Pay',
        icon: Icons.send_rounded,
        color: _neonCyan,
        badge: '0% Fee',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentTransfersView(userModel: userModel))),
      ),
      AppFeature(
        id: 'split_bill',
        title: 'Split Bill',
        subtitle: 'Split cafeteria lunch, groceries & rent with roommates',
        category: 'Finance & Pay',
        icon: Icons.call_split,
        color: const Color(0xFF06B6D4),
        badge: 'Popular',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SplitBillView(userModel: userModel))),
      ),
      AppFeature(
        id: 'virtual_card',
        title: 'Virtual VCC Card',
        subtitle: 'Dynamic NFC card details & daily limits for cafeteria pay',
        category: 'Finance & Pay',
        icon: Icons.credit_card,
        color: _neonBlue,
        badge: 'Contactless',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VirtualCardView(userModel: userModel))),
      ),
      AppFeature(
        id: 'history_ledger',
        title: 'History & Ledger',
        subtitle: 'Complete verified audit trail of deposits, meals & transfers',
        category: 'Finance & Pay',
        icon: Icons.history_edu,
        color: _neonOrange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLedgerView())),
      ),
      AppFeature(
        id: 'request_funds',
        title: 'Request Funds (Fund Me)',
        subtitle: 'Share your personal M-Pesa link with parents or friends',
        category: 'Finance & Pay',
        icon: Icons.monetization_on,
        color: const Color(0xFF10B981),
        badge: 'M-PESA',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestFundsView(userModel: userModel))),
      ),
      AppFeature(
        id: 'subscriptions',
        title: 'Meal Subscriptions',
        subtitle: 'Manage cafeteria weekly & monthly prepaid meal plans',
        category: 'Finance & Pay',
        icon: Icons.event_repeat,
        color: Colors.amber,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionManagerView(userModel: userModel))),
      ),
      AppFeature(
        id: 'safter_pin',
        title: 'Safter Emergency PIN',
        subtitle: 'Set a distress PIN to alert emergency contacts silently',
        category: 'Finance & Pay',
        icon: Icons.lock_outline,
        color: _neonPink,
        badge: 'Security',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafterPinView())),
      ),

      // ── Dining & Food ──
      AppFeature(
        id: 'vendor_directory',
        title: 'Campus Cafeterias',
        subtitle: 'Browse all approved food stalls, view menus & prices',
        category: 'Dining & Food',
        icon: Icons.restaurant_menu,
        color: _neonOrange,
        badge: 'Live Menus',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDirectoryView())),
      ),
      AppFeature(
        id: 'student_preorders',
        title: 'My Pre-orders',
        subtitle: 'Track active meal preparation status & pickup QR tokens',
        category: 'Dining & Food',
        icon: Icons.shopping_bag_outlined,
        color: _neonCyan,
        badge: 'Skip Queue',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentPreordersView())),
      ),
      AppFeature(
        id: 'okoa_food',
        title: 'Okoa Food Emergency',
        subtitle: 'Zero-interest meal credit so no student goes hungry',
        category: 'Dining & Food',
        icon: Icons.fastfood,
        color: const Color(0xFFEF4444),
        badge: 'KES 500 Credit',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OkoaFoodView())),
      ),
      AppFeature(
        id: 'gift_meal',
        title: 'Gift a Meal',
        subtitle: 'Pay it forward and buy lunch for a classmate or fresher',
        category: 'Dining & Food',
        icon: Icons.card_giftcard,
        color: _neonPink,
        onTap: () => showDialog(context: context, builder: (_) => const GiftMealDialog()),
      ),
      AppFeature(
        id: 'health_carbon',
        title: 'Nutrition & Carbon Impact',
        subtitle: 'Track daily calories, macros & campus environmental score',
        category: 'Dining & Food',
        icon: Icons.eco,
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HealthAndCarbonView(userModel: userModel))),
      ),

      // ── Campus Gigs & Hustle ──
      AppFeature(
        id: 'campus_employment_hub',
        title: 'Campus Employment Hub',
        subtitle: 'Find student gigs, part-time campus jobs & tutoring',
        category: 'Campus Gigs',
        icon: Icons.work_outline,
        color: _neonCyan,
        badge: 'Earn KES',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusEmploymentHubView())),
      ),
      AppFeature(
        id: 'deliv_courier',
        title: 'DeLiv Courier Driver',
        subtitle: 'Deliver food & parcels across campus on bicycle or foot',
        category: 'Campus Gigs',
        icon: Icons.delivery_dining,
        color: const Color(0xFFE11D48),
        badge: 'Earn Daily',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DelivDriverDashboard(user: userModel.toJson()))),
      ),
      AppFeature(
        id: 'deliv_register',
        title: 'Become a Courier Rider',
        subtitle: 'Register your bicycle or scooter to start fulfilling orders',
        category: 'Campus Gigs',
        icon: Icons.motorcycle,
        color: Colors.deepOrangeAccent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DelivRegistrationView())),
      ),
      AppFeature(
        id: 'gig_board',
        title: 'Community Gig Board',
        subtitle: 'Peer-to-peer campus task marketplace (assignments, errands)',
        category: 'Campus Gigs',
        icon: Icons.assignment_outlined,
        color: Colors.cyanAccent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GigBoardView(user: userModel.toJson()))),
      ),
      AppFeature(
        id: 'escrow_market',
        title: 'Escrow Marketplace',
        subtitle: 'Buy and sell textbooks, laptops & electronics securely',
        category: 'Campus Gigs',
        icon: Icons.storefront,
        color: _neonBlue,
        badge: 'Escrow Protected',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EscrowMarketView(user: userModel.toJson()))),
      ),
      AppFeature(
        id: 'swipe_exchange',
        title: 'Swipe Exchange',
        subtitle: 'Trade cafeteria meal swipes & voucher tokens with peers',
        category: 'Campus Gigs',
        icon: Icons.sync_alt,
        color: Colors.amber,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SwipeExchangeView(userModel: userModel))),
      ),

      // ── Keja Housing ──
      AppFeature(
        id: 'keja_dashboard',
        title: 'Keja Yangu Dashboard',
        subtitle: 'Hostel manager, rent receipts & roommate communications',
        category: 'Keja Housing',
        icon: Icons.apartment,
        color: _neonBlue,
        badge: 'Housing Hub',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HousingDashboardView(user: userModel.toJson()))),
      ),
      AppFeature(
        id: 'housing_marketplace',
        title: 'Hostel Marketplace',
        subtitle: 'Browse student hostels, verified bedsitters & room rates',
        category: 'Keja Housing',
        icon: Icons.house_siding,
        color: Colors.tealAccent,
        badge: 'Verified',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HousingMarketplaceView(user: userModel.toJson()))),
      ),
      AppFeature(
        id: 'fundi_hub',
        title: 'Fundi Maintenance Hub',
        subtitle: 'Book verified electricians, plumbers & carpenters for hostels',
        category: 'Keja Housing',
        icon: Icons.handyman,
        color: _neonOrange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FundiMarketplaceView(userModel: userModel))),
      ),

      // ── Games & Rewards ──
      AppFeature(
        id: 'games_hub',
        title: 'DISHI Arcade Hub',
        subtitle: 'Play Byte Ninja, Delivery Dash & win free cafeteria coins',
        category: 'Games & Rewards',
        icon: Icons.sports_esports,
        color: const Color(0xFFA855F7),
        badge: 'Arcade',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamesHubView(userModel: userModel))),
      ),
      AppFeature(
        id: 'daily_spin',
        title: 'Daily Lucky Spin',
        subtitle: 'Spin the wheel daily for free delivery tokens & coins',
        category: 'Games & Rewards',
        icon: Icons.casino,
        color: _neonPink,
        badge: 'Free Daily',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailySpinGame(userModel: userModel))),
      ),
      AppFeature(
        id: 'redeem_store',
        title: 'Redeem Store',
        subtitle: 'Exchange DISHI loyalty coins for real cafeteria meals & merch',
        category: 'Games & Rewards',
        icon: Icons.redeem,
        color: _neonCyan,
        badge: 'Discounts',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RedeemStoreView(userModel: userModel))),
      ),

      // ── Smarti Academic ──
      AppFeature(
        id: 'smarti_ai',
        title: 'Smarti AI Tutor',
        subtitle: '24/7 Academic study assistant powered by campus AI',
        category: 'Smarti Study',
        icon: Icons.smart_toy,
        color: Colors.purpleAccent,
        badge: 'AI Powered',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartiChatbotView())),
      ),
      AppFeature(
        id: 'timetable',
        title: 'Class Timetable',
        subtitle: 'Lecture schedules, venue changes & exam alerts',
        category: 'Smarti Study',
        icon: Icons.calendar_month,
        color: Colors.lightBlueAccent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TimetableView())),
      ),
      AppFeature(
        id: 'flashcards',
        title: 'Study Flashcards',
        subtitle: 'Spaced repetition revision cards for exams & quizzes',
        category: 'Smarti Study',
        icon: Icons.style,
        color: Colors.amberAccent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardsView())),
      ),

      // ── Social & Campus ──
      AppFeature(
        id: 'uniuptown',
        title: 'UniUptown Matches',
        subtitle: 'Connect with students across faculties, dating & friends',
        category: 'Social & Match',
        icon: Icons.favorite,
        color: _neonPink,
        badge: 'Trending',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchHubView())),
      ),
      AppFeature(
        id: 'campus_feed',
        title: 'Campus Buzz Feed',
        subtitle: 'Live campus social feed, memes, questions & announcements',
        category: 'Social & Match',
        icon: Icons.dynamic_feed,
        color: _neonBlue,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCampusFeedView())),
      ),
      AppFeature(
        id: 'event_tickets',
        title: 'Campus Events & Tickets',
        subtitle: 'Buy student tickets for concerts, dinners & sports',
        category: 'Social & Match',
        icon: Icons.confirmation_num,
        color: Colors.purpleAccent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventTicketsView(user: userModel.toJson()))),
      ),
      AppFeature(
        id: 'harambee',
        title: 'Harambee Crowdfund',
        subtitle: 'Rally classmates to fund medical, tuition or emergency needs',
        category: 'Social & Match',
        icon: Icons.volunteer_activism,
        color: Colors.pinkAccent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HarambeeView(user: userModel.toJson()))),
      ),
      AppFeature(
        id: 'lost_found',
        title: 'Lost & Found',
        subtitle: 'Report lost IDs, keys, wallets & laptops across campus',
        category: 'Social & Match',
        icon: Icons.find_in_page,
        color: _neonOrange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LostAndFoundView(user: userModel.toJson()))),
      ),
      AppFeature(
        id: 'meetup_share',
        title: 'Meetup Share',
        subtitle: 'Share your temporary campus coordinates for lunch meetups',
        category: 'Social & Match',
        icon: Icons.share_location,
        color: _neonCyan,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MeetupShareView(studentUid: userModel.uid, studentName: userModel.displayName))),
      ),

      // ── Safety & Maps ──
      AppFeature(
        id: 'campus_map',
        title: 'Campus Navigator',
        subtitle: 'Interactive map of lecture halls, libraries & safe paths',
        category: 'Safety & Maps',
        icon: Icons.map,
        color: _neonCyan,
        badge: 'Safe Walk',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CampusMapView(studentUid: userModel.uid))),
      ),
      AppFeature(
        id: 'nearby_services',
        title: 'Nearby Services Map',
        subtitle: 'Find ATMs, pharmacies, printing shops & bodaboda stands',
        category: 'Safety & Maps',
        icon: Icons.store_mall_directory,
        color: _neonOrange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NearbyServicesMapView(studentUid: userModel.uid))),
      ),
      AppFeature(
        id: 'ar_map',
        title: 'AR Campus Map',
        subtitle: 'Augmented reality live camera wayfinding across campus',
        category: 'Safety & Maps',
        icon: Icons.view_in_ar,
        color: const Color(0xFF10B981),
        badge: 'AR Vision',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArCampusMapView())),
      ),
      AppFeature(
        id: 'safety_pins',
        title: 'Campus Safety Pins',
        subtitle: 'Community safety alert pins & lighted night pathways',
        category: 'Safety & Maps',
        icon: Icons.shield,
        color: Colors.redAccent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SafetyPinsView())),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final allFeatures = _buildAllFeatures(context);

    // Apply search filter
    final query = _searchQuery.trim().toLowerCase();
    final filteredFeatures = allFeatures.where((f) {
      final matchesSearch = query.isEmpty ||
          f.title.toLowerCase().contains(query) ||
          f.subtitle.toLowerCase().contains(query) ||
          f.category.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == 'All' || f.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Campus Features & Apps',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: _neonCyan),
            tooltip: 'Share Fund Me Link',
            onPressed: () => _showFundMeDialog(context, widget.userModel),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _surfaceLight),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search features, bills, meals, housing...',
                  hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: _textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: _textSecondary, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
            ),
          ),

          // ── Category Filter Chips ──
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: _neonCyan,
                  backgroundColor: _cardColor,
                  side: BorderSide(
                    color: isSelected ? _neonCyan : _surfaceLight,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── Results Summary Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory == 'All' ? 'All Platforms (${filteredFeatures.length})' : '$_selectedCategory (${filteredFeatures.length})',
                  style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _selectedCategory = 'All';
                      });
                    },
                    child: const Text('Reset', style: TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Features Grid ──
          Expanded(
            child: filteredFeatures.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 4),
                    itemCount: filteredFeatures.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filteredFeatures[index];
                      return _buildFeatureTile(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: _textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No features found',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find anything matching "$_searchQuery" in $_selectedCategory.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedCategory = 'All';
                });
              },
              child: const Text('Clear Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(AppFeature item) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        item.onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _surfaceLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: item.color.withOpacity(0.3)),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: item.color.withOpacity(0.3)),
                          ),
                          child: Text(
                            item.badge!,
                            style: TextStyle(
                              color: item.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: _textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  void _showFundMeDialog(BuildContext context, UserModel userModel) {
    String currentDishiId = userModel.uid;
    final link = 'https://dishi.delstarfordworks.co.ke/fund?dishi_id=$currentDishiId';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _neonPink.withOpacity(0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.favorite, color: _neonPink, size: 28),
            SizedBox(width: 8),
            Text('Fund Me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this link with your parents, guardians, or friends. They can fund your wallet directly via M-PESA.',
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _surfaceLight),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(color: _neonCyan, fontSize: 13, fontWeight: FontWeight.w500),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fund Me link copied to clipboard!'),
                      backgroundColor: _neonCyan,
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, color: Colors.black),
                label: const Text('Copy Link', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonCyan,
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
              child: const Text('Close', style: TextStyle(color: _textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
