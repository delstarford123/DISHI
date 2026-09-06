import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class ParentLiveTrackingView extends StatelessWidget {
  const ParentLiveTrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: Colors.indigo,
      ),
      body: Stack(
        children: [
          // Simulated Map Background
          Container(
            color: Colors.grey.shade300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map, size: 100, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Google Maps Engine Initialized', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 40),
                  // Mock Driver Location Marker
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_car, color: Colors.indigo),
                            SizedBox(width: 8),
                            Text('Driver: Kevin (Deliv)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white, size: 40),
                    ],
                  )
                ],
              ),
            ),
          ),
          
          // Bottom Info Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Movement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: const Text('Student: Jane Doe'),
                    subtitle: const Text('Status: In Transit (Safe Walk Active)'),
                    trailing: const Icon(Icons.shield, color: MPesaTheme.primaryGreen),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.fastfood, color: Colors.white),
                    ),
                    title: const Text('Order #4421'),
                    subtitle: const Text('ETA: 12 mins • Qwetu Hostels'),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
