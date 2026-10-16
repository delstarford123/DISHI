import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM EXECUTIVE THEME COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  double _commissionRate = 1.5;
  bool _isMaintenance = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final rate = await _adminService.getCommissionRate().catchError((_) => 1.5);
      final cfgDoc = await FirebaseFirestore.instance.collection('system_settings').doc('platform_config').get();
      final isMaint = cfgDoc.data()?['maintenance_mode'] == true;

      if (mounted) {
        setState(() {
          _commissionRate = rate;
          _isMaintenance = isMaint;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleToggleFlag(String flagId, bool currentValue) async {
    try {
      await _adminService.toggleConfig(flagId, !currentValue);
      if (mounted) {
        setState(() {}); // refresh FutureBuilder
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Flag "$flagId" updated'), backgroundColor: _neonCyan, duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
      }
    }
  }

  void _showCommissionDialog() {
    final TextEditingController rateController = TextEditingController(text: _commissionRate.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 1.5)),
        title: const Text('Update Commission Rate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter platform fee deduction percentage for cafeteria & merchant sales:', style: TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                suffixText: '%',
                suffixStyle: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold),
                labelText: 'Platform Commission (%)',
                labelStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
            onPressed: () async {
              final newRate = double.tryParse(rateController.text.trim());
              if (newRate == null || newRate < 0 || newRate > 50) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid rate between 0% and 50%')));
                return;
              }
              Navigator.pop(context);
              try {
                await _adminService.updateCommissionRate(newRate);
                if (mounted) {
                  setState(() => _commissionRate = newRate);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Commission set to $newRate%'), backgroundColor: _neonCyan));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
              }
            },
            child: const Text('Update Rate', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Platform Config & Feature Flags', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            onPressed: _loadSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Maintenance Mode Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isMaintenance ? _neonRed.withOpacity(0.15) : _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isMaintenance ? _neonRed : _surfaceLight, width: 1.5),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: _neonRed,
                    title: const Text('Platform Maintenance Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      _isMaintenance ? 'ACTIVE: Only admins can access the system' : 'Inactive: Platform open to all campus students & vendors',
                      style: TextStyle(color: _isMaintenance ? _neonRed : _textSecondary, fontSize: 12),
                    ),
                    value: _isMaintenance,
                    onChanged: (val) async {
                      try {
                        await _adminService.toggleMaintenanceMode(val);
                        setState(() => _isMaintenance = val);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Maintenance mode ${val ? "Enabled" : "Disabled"}'), backgroundColor: val ? _neonRed : _neonCyan),
                          );
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Financial Controls
                const Text('Financial & Commission Rates', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),
                  child: ListTile(
                    leading: const Icon(Icons.percent, color: _neonCyan),
                    title: const Text('Platform Sales Commission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Deducted automatically on completed cafeteria POS checkout', style: TextStyle(color: _textSecondary, fontSize: 12)),
                    trailing: Text('$_commissionRate%', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 18)),
                    onTap: _showCommissionDialog,
                  ),
                ),
                const SizedBox(height: 10),
                _buildStaticSettingTile('Fundi Juaji Escrow Fee', '1.5%', Icons.build, Colors.amberAccent),
                const SizedBox(height: 10),
                _buildStaticSettingTile('Housing Booking Escrow Fee', 'KES 1,500.00', Icons.home_work, _neonBlue),
                const SizedBox(height: 24),

                // CBK Compliance & Limits
                const Text('Central Bank of Kenya (CBK) Compliance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildStaticSettingTile('Max Wallet Balance Limit', 'KES 3,000.00', Icons.account_balance, _neonCyan),
                const SizedBox(height: 10),
                _buildStaticSettingTile('Daily PIN-less Tap Limit', 'KES 200.00', Icons.contactless, _neonOrange),
                const SizedBox(height: 24),

                // Dynamic Live Feature Flags
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live Feature Flags', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('Instant Remote Config', style: TextStyle(color: _neonCyan, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<Map<String, dynamic>>(
                  future: _adminService.getSystemConfig(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: _neonCyan)));
                    }
                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                        child: Text('Error loading flags: ${snapshot.error}', style: const TextStyle(color: _neonRed, fontSize: 12)),
                      );
                    }

                    final flags = snapshot.data ?? {};
                    if (flags.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                        child: const Text('No dynamic feature flags found.', style: TextStyle(color: _textSecondary)),
                      );
                    }

                    return Column(
                      children: flags.entries.map((entry) {
                        final flagId = entry.key;
                        final isEnabled = entry.value['enabled'] == true;
                        final formattedName = flagId.replaceAll('_', ' ').toUpperCase();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isEnabled ? _neonCyan.withOpacity(0.3) : _surfaceLight),
                          ),
                          child: SwitchListTile(
                            activeColor: _neonCyan,
                            title: Text(formattedName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(
                              isEnabled ? 'Live & Available to Students' : 'Temporarily Disabled by Admin',
                              style: TextStyle(color: isEnabled ? _neonCyan : _neonRed, fontSize: 11),
                            ),
                            value: isEnabled,
                            onChanged: (val) => _handleToggleFlag(flagId, isEnabled),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildStaticSettingTile(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Text(value, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
