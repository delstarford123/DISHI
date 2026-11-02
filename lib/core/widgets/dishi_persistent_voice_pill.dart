import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dishi_voice_service.dart';
import '../services/dishi_voice_models.dart';
import 'sema_na_dishi_overlay.dart';

/// Floating Non-Intrusive HUD Pill that remains on screen when DISHI Voice is Online.
/// Displays live listening state, voice transcript, quick standby ("Thank you DISHI"),
/// training launcher, and full sheet expander.
class DishiPersistentVoicePill extends StatefulWidget {
  const DishiPersistentVoicePill({super.key});

  @override
  State<DishiPersistentVoicePill> createState() => _DishiPersistentVoicePillState();
}

class _DishiPersistentVoicePillState extends State<DishiPersistentVoicePill> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    DishiVoiceService.instance.showTrainingSheetNotifier.addListener(_checkShowTrainingSheet);
  }

  @override
  void dispose() {
    DishiVoiceService.instance.showTrainingSheetNotifier.removeListener(_checkShowTrainingSheet);
    _pulseController.dispose();
    super.dispose();
  }

  void _checkShowTrainingSheet() {
    if (DishiVoiceService.instance.showTrainingSheetNotifier.value && mounted) {
      DishiVoiceService.instance.showTrainingSheetNotifier.value = false;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const DishiVoiceTrainingSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DishiVoiceService.instance.isOnlineNotifier,
      builder: (context, isOnline, _) {
        if (!isOnline) return const SizedBox.shrink();

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: ValueListenableBuilder<bool>(
              valueListenable: DishiVoiceService.instance.isListeningNotifier,
              builder: (context, isListening, _) {
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = _pulseController.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1523).withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isListening
                              ? kVoiceNeonGold.withValues(alpha: 0.6 + (pulse * 0.4))
                              : kVoiceNeonCyan.withValues(alpha: 0.4),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isListening
                                ? kVoiceNeonGold.withValues(alpha: 0.3 * pulse)
                                : kVoiceNeonCyan.withValues(alpha: 0.15),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Animated Pulsing Mic Avatar
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: isListening
                                    ? [const Color(0xFFFFF9A6), const Color(0xFFFFD700)]
                                    : [kVoiceNeonCyan, const Color(0xFF009688)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isListening ? kVoiceNeonGold : kVoiceNeonCyan).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              isListening ? Icons.mic : Icons.mic_none,
                              color: const Color(0xFF0C101B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Dynamic Transcript & Status Text
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                SemaNaDishiOverlay.show(context);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'DISHI Voice Online',
                                        style: TextStyle(
                                          color: isListening ? kVoiceNeonGold : kVoiceNeonCyan,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          DishiVoiceService.instance.selectedPersona.name.split(' ')[0],
                                          style: const TextStyle(color: Colors.white70, fontSize: 9),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  ValueListenableBuilder<String>(
                                    valueListenable: DishiVoiceService.instance.transcriptNotifier,
                                    builder: (context, transcript, _) {
                                      if (transcript.isNotEmpty) {
                                        return Text(
                                          '"$transcript"',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      }
                                      return const Text(
                                        'Say "Hello DISHI" or "Thank you DISHI"',
                                        style: TextStyle(color: kVoiceTextSecondary, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Interactive Action Buttons
                          IconButton(
                            icon: const Icon(Icons.school_rounded, color: Colors.amberAccent, size: 20),
                            tooltip: 'Voice Training',
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              DishiVoiceService.instance.launchVoiceTraining();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_full_rounded, color: Colors.white70, size: 18),
                            tooltip: 'Expand Voice Assistant',
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              SemaNaDishiOverlay.show(context);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Standby / Manual Mode ("Thank you DISHI")',
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              DishiVoiceService.instance.setStandby(speakDismiss: true);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Interactive Training & Voice Command Guide Bottom Sheet
class DishiVoiceTrainingSheet extends StatelessWidget {
  const DishiVoiceTrainingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = DishiVoiceService.instance.currentLanguage;
    final isEn = lang == 'en';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1424),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'DISHI Voice Training & Guide' : 'Mafunzo ya Sauti ya DISHI',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isEn ? 'Speak naturally anywhere in the app' : 'Ongea kawaida mahali popote kwenye app',
                      style: const TextStyle(color: kVoiceTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overview banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E2640),
                  const Color(0xFF171E33),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kVoiceNeonCyan.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates, color: kVoiceNeonCyan, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEn
                        ? 'DISHI stays online in the background! Say "Hello DISHI" to wake, give any command, and say "Thank you DISHI" when you want manual control.'
                        : 'DISHI inabaki hewani kila wakati! Sema "Hello DISHI" kuniamsha, taja amri yoyote, na sema "Thank you DISHI" unapotaka kutumia mikono.',
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Interactive Training Modules (Tap any to practice):',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Scrollable Training Cards
          Expanded(
            child: ListView(
              children: [
                _buildTrainingCard(
                  context,
                  title: '1. Wake Up & Time-Based Greeting',
                  subtitle: 'Say "Hello DISHI" anytime to get an instant time-aware greeting.',
                  command: 'Hello DISHI',
                  badge: 'Wake Phrase',
                  badgeColor: Colors.amber,
                  icon: Icons.wb_sunny_rounded,
                ),
                _buildTrainingCard(
                  context,
                  title: '2. UniUptown Campus Dating & Hub',
                  subtitle: 'Opens student dating, matchmaking, and campus connections.',
                  command: 'open uniuptown',
                  badge: 'Intent: OPEN_UNIUPTOWN',
                  badgeColor: Colors.purpleAccent,
                  icon: Icons.favorite_rounded,
                ),
                _buildTrainingCard(
                  context,
                  title: '3. Comrade Swiping Deck',
                  subtitle: 'Browse student profiles, swipe right to match, and connect.',
                  command: 'start swiping',
                  badge: 'Intent: START_SWIPING',
                  badgeColor: Colors.pinkAccent,
                  icon: Icons.swipe_rounded,
                ),
                _buildTrainingCard(
                  context,
                  title: '4. Matches & Comrade Chats',
                  subtitle: 'Directly view your active connections and private messages.',
                  command: 'matches and chats',
                  badge: 'Intent: OPEN_MATCHES_CHATS',
                  badgeColor: Colors.deepPurpleAccent,
                  icon: Icons.chat_bubble_rounded,
                ),
                _buildTrainingCard(
                  context,
                  title: '5. Pre-orders & Skip The Line',
                  subtitle: 'Order your meal in advance from Nyawuora Cafeteria.',
                  command: 'open preorder and order this',
                  badge: 'Intent: OPEN_PREORDERS',
                  badgeColor: Colors.orangeAccent,
                  icon: Icons.restaurant_menu_rounded,
                ),
                _buildTrainingCard(
                  context,
                  title: '6. Campus Supermarket & Electronics',
                  subtitle: 'Buy groceries, scientific calculators, stationery, and lab coats.',
                  command: 'campus supermarket',
                  badge: 'Intent: OPEN_SUPERMARKET',
                  badgeColor: Colors.tealAccent,
                  icon: Icons.store_rounded,
                ),
                _buildTrainingCard(
                  context,
                  title: '7. Campus Gigs & Fundi Services',
                  subtitle: 'Find student employment, laptop repairs, room cleaning, and tech.',
                  command: 'campus gigs',
                  badge: 'Intent: CAMPUS_GIGS',
                  badgeColor: Colors.blueAccent,
                  icon: Icons.handyman_rounded,
                ),
                _buildTrainingCard(
                  context,
                  title: '8. Wallet Balance & Financial Ledger',
                  subtitle: 'Check your current digital wallet balance and student transactions.',
                  command: 'Check my wallet balance',
                  badge: 'Intent: QUERY_BALANCE',
                  badgeColor: Colors.greenAccent,
                  icon: Icons.account_balance_wallet_rounded,
                ),
                _buildTrainingCard(
                  context,
                  title: '9. Standby & Manual Navigation Mode',
                  subtitle: 'Puts DISHI Voice to sleep so you can navigate the screen by touch.',
                  command: 'Thank you DISHI',
                  badge: 'Intent: THANK_YOU_DISHI',
                  badgeColor: Colors.redAccent,
                  icon: Icons.pause_circle_filled_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String command,
    required String badge,
    required Color badgeColor,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kVoiceCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: badgeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: kVoiceTextSecondary, fontSize: 11, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C101B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic, size: 12, color: kVoiceNeonGold),
                    const SizedBox(width: 6),
                    Text(
                      '"$command"',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: badgeColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Try Saying This', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  DishiVoiceService.instance.processVoiceCommand(command);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

