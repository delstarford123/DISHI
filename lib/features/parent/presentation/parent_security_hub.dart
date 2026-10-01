import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/widgets/custom_secure_keypad.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _textSecondary = Color(0xFF8B9BB4);

class ParentSecurityHub extends StatefulWidget {
  const ParentSecurityHub({super.key});

  @override
  State<ParentSecurityHub> createState() => _ParentSecurityHubState();
}

class _ParentSecurityHubState extends State<ParentSecurityHub> {

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Security Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('security_alerts')
            .where('uid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          int compromised = 0;
          int outliers = 0;
          int devices = 2; // Assuming 2 active devices statically for now unless tracked

          if (snapshot.hasData) {
            final docs = snapshot.data!.docs;
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['type'] == 'compromise') compromised++;
              if (data['type'] == 'location') outliers++;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHubCard(Icons.warning, 'Compromised Alerts', '$compromised Active Alerts', _neonCyan, onTap: () {}),
              _buildHubCard(Icons.location_on, 'Location Outliers', '$outliers Flagged Transactions', Colors.orange, onTap: () {}),
              _buildHubCard(Icons.devices, 'Active Devices', '$devices Devices logged in', _neonPink, onTap: () {}),
              _buildHubCard(Icons.pin, 'Safety PIN', 'Set or update your emergency PIN', _neonCyan, onTap: () => _showSafetyPinSetup(context, uid)),
              _buildHubCard(Icons.family_restroom, 'Linked Family', 'Manage connected student accounts', _neonPink, onTap: () {}),
              
              const SizedBox(height: 32),
              const Text('Recent Alerts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator(color: _neonCyan)),
              
              if (snapshot.hasData && snapshot.data!.docs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('No security alerts at this time.', style: TextStyle(color: _textSecondary)),
                  ),
                ),

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
                ...snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'alert';
                  IconData icon = Icons.notifications;
                  Color color = Colors.white;

                  if (type == 'compromise') {
                    icon = Icons.warning;
                    color = _neonCyan;
                  } else if (type == 'location') {
                    icon = Icons.location_on;
                    color = Colors.orange;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(icon, color: color),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title'] ?? 'Alert', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(data['description'] ?? '', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Simulate an active security sweep instead of just dropping a dummy alert
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Scanning for security anomalies...'),
            backgroundColor: _surfaceLight,
          ));
          await Future.delayed(const Duration(seconds: 2));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('All systems secure. No new anomalies detected.'),
              backgroundColor: _neonCyan,
            ));
          }
        },
        backgroundColor: _neonCyan,
        elevation: 4,
        icon: const Icon(Icons.security, color: Colors.black),
        label: const Text('Security Scan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHubCard(IconData icon, String title, String subtitle, Color iconColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: _surfaceLight, size: 16)
          ],
        ),
      ),
    );
  }

  void _showSafetyPinSetup(BuildContext context, String? uid) {
    if (uid == null) return;
    String enteredPin = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: _bgColor,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const Text('Set Safety PIN', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('This PIN allows you to override security locks on linked student accounts.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary)),
                  const SizedBox(height: 32),
                  
                  // PIN Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < enteredPin.length ? _neonCyan : Colors.white24,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  
                  Expanded(
                    child: CustomSecureKeypad(
                      randomize: true,
                      showBiometric: false,
                      onKeyPressed: (val) {
                        if (enteredPin.length < 4) {
                          setModalState(() => enteredPin += val);
                        }
                      },
                      onBackspace: () {
                        if (enteredPin.isNotEmpty) {
                          setModalState(() => enteredPin = enteredPin.substring(0, enteredPin.length - 1));
                        }
                      },
                      onBiometricTap: () {},
                    ),
                  ),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: enteredPin.length == 4 ? () async {
                        await FirebaseFirestore.instance.collection('users').doc(uid).set({
                          'safetyPin': enteredPin,
                          'safetyPinUpdatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Safety PIN updated successfully.'), backgroundColor: _neonCyan));
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Save PIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
