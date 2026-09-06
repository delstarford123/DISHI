import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'match_night_club_view.dart';
import 'match_discovery_view.dart';
import 'match_matches_hub.dart';
import 'match_speed_dating_view.dart';
import 'match_profile_setup.dart';
import 'match_premium_view.dart';
import 'match_double_date_view.dart';
import 'match_crush_radar_view.dart';
import 'match_event_date_view.dart';
import 'match_study_buddy_view.dart';
import 'match_vibe_check_dialog.dart';
import 'match_love_language_dialog.dart';
import 'match_voice_recorder_dialog.dart';
import 'match_spill_the_tea_view.dart';
import 'match_secret_admirer_view.dart';
import 'match_campus_idol_view.dart';
import 'match_library_lockin_view.dart';
import 'match_music_match_view.dart';
import 'match_truth_or_drink_view.dart';
import 'match_day_in_the_life_view.dart';
import 'match_shot_in_the_dark_view.dart';
import 'widgets/incoming_call_listener.dart';

class MatchHubView extends StatelessWidget {
  const MatchHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Very dark blue/slate
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Your Match',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: MPesaTheme.primaryGreen), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchProfileSetup()));
          }),
          IconButton(icon: const Icon(Icons.ac_unit, color: Colors.redAccent), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchPremiumView()));
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top 2x2 Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _buildTopCard(context, 'Start Swiping', 'Match Deck', Icons.style, const Color(0xFF10B981), const MatchDiscoveryView()),
                _buildTopCard(context, 'Matches & Chats', 'Active Messages', Icons.chat_bubble, const Color(0xFF3B82F6), const MatchMatchesHub()),
                _buildTopGradientCard(context, 'Virtual Club', '24/7 DJ Party Room', Icons.music_note, const [Color(0xFF8B5CF6), Color(0xFF6D28D9)], const MatchNightClubView()),
                _buildTopGradientCard(context, 'Shot in the Dark', '3-Min Blind Chat', Icons.nightlight_round, const [Color(0xFFF97316), Color(0xFFEF4444)], const MatchShotInTheDarkView()),
              ],
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader('Dating & Social Modes', Icons.local_fire_department, Colors.redAccent),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildListCard('Double Dates', 'Team up wit...', Icons.group, Colors.blue.shade300, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchDoubleDateView()));
                }),
                _buildListCard('Crush Radar', 'Students ne...', Icons.track_changes, Colors.pinkAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchCrushRadarView()));
                }),
                _buildListCard('Varsity Dates', 'Campus eve...', Icons.confirmation_num, Colors.amber, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchEventDateView()));
                }),
                _buildListCard('Spill The Tea', 'Confessions...', Icons.coffee, Colors.orangeAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchSpillTheTeaView()));
                }),
                _buildListCard('Secret Admirer', 'Send a crush...', Icons.favorite, Colors.pinkAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchSecretAdmirerView()));
                }),
                _buildListCard('Truth or Drink', 'Icebreaker...', Icons.liquor, Colors.redAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchTruthOrDrinkView()));
                }),
                _buildListCard('Campus Idol', 'Voice notes...', Icons.mic, Colors.blueAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchCampusIdolView()));
                }),
              ],
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Campus & Compatibility', Icons.school, Colors.pinkAccent),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildListCard('Study Buddy', 'Find librar...', Icons.menu_book, Colors.green, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchStudyBuddyView()));
                }),
                _buildListCard('Vibe Check', 'Quick Q&A...', Icons.psychology, Colors.purpleAccent, () {
                  showDialog(context: context, builder: (context) => const MatchVibeCheckDialog());
                }),
                _buildListCard('Love Language', 'Find your s...', Icons.favorite, Colors.redAccent, () {
                  showDialog(context: context, builder: (context) => const MatchLoveLanguageDialog());
                }),
                _buildListCard('Voice Intro', 'Listen to v...', Icons.mic, Colors.orangeAccent, () {
                  showDialog(context: context, builder: (context) => const MatchVoiceRecorderDialog());
                }),
                _buildListCard('Library Lock-In', 'Study dates...', Icons.local_library, Colors.greenAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchLibraryLockInView()));
                }),
                _buildListCard('Music Match', 'Spotify vibes...', Icons.music_note, Colors.purpleAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchMusicMatchView()));
                }),
                _buildListCard('Day in the Life', 'Photo prompt...', Icons.camera_alt, Colors.yellowAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchDayInTheLifeView()));
                }),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopGradientCard(BuildContext context, String title, String subtitle, IconData icon, List<Color> colors, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildListCard(String title, String subtitle, IconData icon, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B), // Slate 800
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.15),
              radius: 18,
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}
