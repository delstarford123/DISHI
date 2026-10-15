import 'package:flutter/material.dart';
import '../document_vault_view.dart';
import '../../../../core/services/local_auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final isBiometric = await LocalAuthService.isBiometricPreferred();
    if (mounted) {
      setState(() => _biometricEnabled = isBiometric);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        _buildSwitchTile('Two-Factor Authentication', 'Require SMS code on new devices', false, (val) {}),
        _buildSettingsTile(title: 'Change Recovery PIN', icon: Icons.password, onTap: () {}),

        const SizedBox(height: 24),
        _buildSectionHeader('Preferences'),
        _buildSwitchTile('Dark Mode', 'Use dark theme across the app', true, (val) {}),
        _buildSwitchTile('Notification Sounds', 'Play sound on new alerts', true, (val) {}),
        
        const SizedBox(height: 24),
        _buildSectionHeader('Account & Support'),
        _buildSettingsTile(title: 'Privacy Policy', icon: Icons.privacy_tip, onTap: () {}),
        _buildSettingsTile(title: 'Help & Support', icon: Icons.help_outline, onTap: () {}),
        _buildSettingsTile(title: 'Clear Cache', subtitle: 'Free up local storage', icon: Icons.cleaning_services, onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared successfully.')));
        }),
        _buildSettingsTile(
          title: 'Delete Account',
          subtitle: 'Permanently remove your data',
          icon: Icons.delete_forever,
          iconColor: _neonPink,
          textColor: _neonPink,
          onTap: () {},
        ),
        
        const SizedBox(height: 32),
        // Notifications preview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Alerts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('View All', style: TextStyle(color: _neonCyan))),
          ],
        ),
        const SizedBox(height: 8),
        _buildNotificationItem('Allergy Warning', 'Attempted purchase of peanuts blocked.', true),
        _buildNotificationItem('Chore Completed', 'John marked "Clean Room" as done.', false),
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
          Icon(isAlert ? Icons.warning_amber_rounded : Icons.notifications_none, color: isAlert ? _neonPink : _neonCyan),
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
