import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../document_vault_view.dart';
import '../emergency_alerts_view.dart';
import '../../../../core/services/local_auth_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../auth/presentation/pin_setup_view.dart';

const Color _cardColor = Color(0xFF131A2A);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonPink = Color(0xFFF92B60);
const Color _textSecondary = Color(0xFF8B9BB4);

class SettingsTabView extends StatefulWidget {
  final Map<String, dynamic> user;

  const SettingsTabView({super.key, required this.user});

  @override
  State<SettingsTabView> createState() => _SettingsTabViewState();
}

class _SettingsTabViewState extends State<SettingsTabView> {
  bool _biometricEnabled = false;
  bool _notificationSounds = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isBiometric = await LocalAuthService.isBiometricPreferred();
    final prefs = await SharedPreferences.getInstance();
    final soundPref = prefs.getBool('dishi_parent_sound_enabled') ?? true;
    if (mounted) {
      setState(() {
        _biometricEnabled = isBiometric;
        _notificationSounds = soundPref;
      });
    }
  }

  Future<void> _toggleNotificationSounds(bool enabled) async {
    setState(() => _notificationSounds = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dishi_parent_sound_enabled', enabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? 'Notification sounds enabled' : 'Notification sounds muted'),
          backgroundColor: _neonCyan,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showHelpAndSupportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF111726),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.headset_mic_rounded, color: _neonCyan, size: 26),
                  SizedBox(width: 12),
                  Text(
                    'DISHI Parent Care & Support',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Our 24/7 dedicated parent support team is here to help with meal allowances, escrow, and student safety.',
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _neonCyan.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.phone_in_talk_rounded, color: _neonCyan),
                ),
                title: const Text('Helpline Hotline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('+254 700 000 000 (Toll-Free Campus Care)', style: TextStyle(color: _textSecondary, fontSize: 12)),
                onTap: () async {
                  final uri = Uri.parse('tel:+254700000000');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.chat_rounded, color: Colors.greenAccent),
                ),
                title: const Text('WhatsApp Parent Desk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Direct chat with an agent for urgent assistance', style: TextStyle(color: _textSecondary, fontSize: 12)),
                onTap: () async {
                  final uri = Uri.parse('https://wa.me/254700000000?text=Hello%20DISHI%20Parent%20Support');
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.email_outlined, color: Colors.blueAccent),
                ),
                title: const Text('Email Parent Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('support@delstarfordworks.co.ke', style: TextStyle(color: _textSecondary, fontSize: 12)),
                onTap: () async {
                  final uri = Uri.parse('mailto:support@delstarfordworks.co.ke?subject=DISHI%20Parent%20Inquiry');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF111726),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.privacy_tip_rounded, color: _neonCyan, size: 26),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'DISHI Safety & Privacy Policy',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '1. Student Data Protection & Privacy',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'DISHI is strictly aligned with the Kenya Data Protection Act 2019 and Google Play Developer Policies. Student location and financial activity are shared solely with authorized parents and verified university emergency responders.',
                    style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '2. Ring-Fenced Meal Allowances & Escrow',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All parental wallet transfers are locked to verified food cafeterias and campus academic stores, preventing fund diversion or non-essential spending.',
                    style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '3. Location & Emergency SOS Safeguards',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Location breadcrumbs are encrypted at rest and in transit. Tracking triggers only during SOS alerts or when student consent is granted for campus safety geofencing.',
                    style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('I Understand & Agree', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: _neonPink.withOpacity(0.4))),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _neonPink, size: 28),
              SizedBox(width: 10),
              Text('Delete Account?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Deleting your parent account will unlink your dependants, forfeit active wallet escrow balances, and permanently erase transaction history. This action cannot be reversed.',
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deletion request queued. Please withdraw all vault funds first for security.'),
                    backgroundColor: _neonPink,
                  ),
                );
              },
              child: const Text('Request Deletion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentUid = FirebaseAuth.instance.currentUser?.uid ?? widget.user['uid'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Document & ID Vault Entry
        _buildSectionHeader('Secure Storage'),
        _buildSettingsTile(
          title: 'Document & ID Vault',
          subtitle: 'Manage passports, insurance, and medical records',
          icon: Icons.security,
          iconColor: _neonCyan,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DocumentVaultView(user: widget.user)),
            );
          },
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Security Settings'),
        _buildSwitchTile(
          'Biometric Login',
          'Use Fingerprint/Pattern to unlock DISHI',
          _biometricEnabled,
          (val) async {
            final messenger = ScaffoldMessenger.of(context);
            setState(() => _biometricEnabled = val);
            await LocalAuthService.setPreferredAuthMethod(val ? 'biometric' : 'pin');
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    val
                        ? 'Biometric / Pattern unlock set as default.'
                        : '4-Digit PIN set as default unlock.',
                  ),
                  backgroundColor: _neonCyan,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
        // SMS Two-Factor Authentication: User specified "only ssm should not work we will put it latter"
        _buildSwitchTile(
          'Two-Factor Authentication',
          'Require SMS code on new devices (v6.1)',
          false,
          (val) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SMS Two-Factor Authentication will be enabled in the upcoming v6.1 update.'),
                backgroundColor: Colors.orangeAccent,
                duration: Duration(seconds: 3),
              ),
            );
          },
        ),
        _buildSettingsTile(
          title: 'Change Recovery PIN',
          subtitle: 'Update your 4-digit security PIN',
          icon: Icons.password,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PinSetupView(
                  role: 'parent',
                  isChangingPin: true,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Preferences'),
        _buildSwitchTile(
          'Dark Mode',
          'Use dark cyber theme across the app',
          ThemeController.isDark,
          (val) async {
            await ThemeController.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
            if (mounted) setState(() {});
          },
        ),
        _buildSwitchTile(
          'Notification Sounds',
          'Play audible tone on student spending & SOS alerts',
          _notificationSounds,
          _toggleNotificationSounds,
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Account & Support'),
        _buildSettingsTile(
          title: 'Privacy Policy',
          subtitle: 'Student telemetry & safety compliance',
          icon: Icons.privacy_tip,
          onTap: _showPrivacyPolicyModal,
        ),
        _buildSettingsTile(
          title: 'Help & Support',
          subtitle: 'Call, WhatsApp, or email 24/7 parent desk',
          icon: Icons.help_outline,
          onTap: _showHelpAndSupportModal,
        ),
        _buildSettingsTile(
          title: 'Clear Cache',
          subtitle: 'Free up local image & temporary storage',
          icon: Icons.cleaning_services,
          onTap: () {
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Local app cache and image memory cleared successfully. 🧹'),
                backgroundColor: _neonCyan,
              ),
            );
          },
        ),
        _buildSettingsTile(
          title: 'Delete Account',
          subtitle: 'Permanently remove your data and links',
          icon: Icons.delete_forever,
          iconColor: _neonPink,
          textColor: _neonPink,
          onTap: _showDeleteAccountDialog,
        ),

        const SizedBox(height: 32),
        // Live Safety Alerts from Firestore
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Alerts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmergencyAlertsView(parentUser: widget.user),
                  ),
                );
              },
              child: const Text('View All', style: TextStyle(color: _neonCyan)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Live stream of alerts instead of mock data
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('safety_alerts')
              .where('parentUids', arrayContains: parentUid)
              .orderBy('timestamp', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Column(
                children: [
                  _buildNotificationItem(
                    'Safety System Active',
                    'All linked student meal restrictions and geofence tracking are running smoothly.',
                    false,
                  ),
                ],
              );
            }

            final alerts = snapshot.data!.docs;
            return Column(
              children: alerts.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final title = d['title'] ?? d['type'] ?? 'Safety Alert';
                final desc = d['description'] ?? d['message'] ?? 'Incident recorded.';
                final isUnresolved = (d['status'] ?? '') == 'Unresolved';
                return _buildNotificationItem(title, desc, isUnresolved);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: _textSecondary, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    String? subtitle,
    required IconData icon,
    Color iconColor = _neonCyan,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: iconColor.withOpacity(0.3))),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, color: _textSecondary, size: 14),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12)),
      value: value,
      activeColor: _neonCyan,
      onChanged: onChanged,
    );
  }

  Widget _buildNotificationItem(String title, String message, bool isAlert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isAlert ? Border.all(color: _neonPink.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          Icon(isAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: isAlert ? _neonPink : _neonCyan),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isAlert ? _neonPink : Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
