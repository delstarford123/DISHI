import 'package:flutter/material.dart';
import '../../../core/services/admin_service.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminDeliverySecurityView extends StatefulWidget {
  const AdminDeliverySecurityView({super.key});

  @override
  State<AdminDeliverySecurityView> createState() => _AdminDeliverySecurityViewState();
}

class _AdminDeliverySecurityViewState extends State<AdminDeliverySecurityView> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleAction(String userId, String action) async {
    try {
      if (action == 'verify') {
        await _adminService.verifyDriver(userId);
      } else if (action == 'suspend') {
        await _adminService.suspendDriver(userId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Driver $action successful')));
        setState(() {}); // refresh FutureBuilders
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Delivery Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _neonCyan,
          labelColor: _neonCyan,
          unselectedLabelColor: _textSecondary,
          tabs: const [
            Tab(text: 'Drivers & Fleet'),
            Tab(text: 'Live Rides Track'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDriversTab(),
          _buildLiveRidesTab(),
        ],
      ),
    );
  }

  Widget _buildDriversTab() {
    return FutureBuilder<List<dynamic>>(
      future: _adminService.getDeliveryDrivers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _neonCyan));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
        }

        final drivers = snapshot.data ?? [];
        if (drivers.isEmpty) {
          return const Center(child: Text('No drivers registered.', style: TextStyle(color: _textSecondary)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];
            final status = driver['status'] ?? 'unknown';
            final isPending = status == 'pending_approval';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPending ? _neonOrange : _surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('User ID: ${driver['user_id']?.toString().substring(0, 8)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: (isPending ? _neonOrange : (status == 'suspended' ? _neonRed : _neonCyan)).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(status.toString().toUpperCase(), style: TextStyle(color: isPending ? _neonOrange : (status == 'suspended' ? _neonRed : _neonCyan), fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Vehicle: ${driver['vehicle_type']} - ${driver['plate_number']}', style: const TextStyle(color: _textSecondary)),
                  Text('Phone: ${driver['phone']}', style: const TextStyle(color: _textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (isPending || status == 'suspended')
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                            onPressed: () => _handleAction(driver['user_id'], 'verify'),
                            child: const Text('Verify & Approve'),
                          ),
                        ),
                      if (status == 'free' || status == 'busy')
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _neonRed, foregroundColor: Colors.white),
                            onPressed: () => _handleAction(driver['user_id'], 'suspend'),
                            child: const Text('Suspend Driver'),
                          ),
                        ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  String? _selectedDriverId;
  String? _selectedRequestId;

  Widget _buildLiveRidesTab() {
    return FutureBuilder(
      future: Future.wait([
        _adminService.getActiveRides(),
        _adminService.getOnlineDrivers(),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _neonCyan));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _neonRed)));
        }

        final rides = (snapshot.data?[0] as List<dynamic>?) ?? [];
        final drivers = (snapshot.data?[1] as List<dynamic>?) ?? [];

        final pendingRides = rides.where((r) => r['status'] == 'pending').toList();
        final activeRides = rides.where((r) => r['status'] != 'pending').toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Manual Dispatch (Pending Requests)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (pendingRides.isEmpty)
                const Text('No pending requests.', style: TextStyle(color: _textSecondary))
              else
                ...pendingRides.map((ride) => _buildDispatchCard(ride, drivers)),
                
              const SizedBox(height: 32),
              const Text('Active Connected Rides', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (activeRides.isEmpty)
                const Text('No active rides.', style: TextStyle(color: _textSecondary))
              else
                ...activeRides.map((ride) => _buildActiveRideCard(ride)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDispatchCard(Map<String, dynamic> ride, List<dynamic> drivers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _neonOrange)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request: ${ride['service_type']} from User ${ride['user_id'].toString().substring(0,8)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Assign Available Driver',
              labelStyle: const TextStyle(color: _neonCyan),
              filled: true,
              fillColor: _surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            dropdownColor: _surfaceLight,
            items: drivers.map((d) => DropdownMenuItem<String>(
              value: d['user_id'],
              child: Text('${d['vehicle_type']} - ${d['phone']}', style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: (val) {
              setState(() {
                _selectedDriverId = val;
                _selectedRequestId = ride['id'];
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: () async {
                if (_selectedDriverId == null) return;
                try {
                  await _adminService.manualDispatchDelivery(ride['id'], _selectedDriverId!);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispatched successfully')));
                  setState(() {});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Force Dispatch'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActiveRideCard(Map<String, dynamic> ride) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${ride['service_type']} - ${ride['status'].toString().toUpperCase()}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('User: ${ride['user_id']}', style: const TextStyle(color: _textSecondary)),
          Text('Driver: ${ride['driver_id']}', style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _surfaceLight, foregroundColor: Colors.white),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Call Users'),
                  onPressed: () {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling users is integrated with SIP trunk.')));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonOrange, foregroundColor: Colors.black),
                  icon: const Icon(Icons.notifications_active, size: 16),
                  label: const Text('FCM Alert'),
                  onPressed: () async {
                    try {
                      await _adminService.notifyDeliveryParty(ride['driver_id'], 'Admin Alert', 'Please check in on your active ride immediately.');
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification Sent to Driver via FCM')));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send FCM: $e')));
                    }
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
