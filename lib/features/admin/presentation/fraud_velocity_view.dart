import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';

class FraudVelocityView extends StatefulWidget {
  const FraudVelocityView({super.key});

  @override
  State<FraudVelocityView> createState() => _FraudVelocityViewState();
}

class _FraudVelocityViewState extends State<FraudVelocityView> {
  final List<Map<String, dynamic>> _flaggedVendors = [
    {
      'vendor_id': 'V-1002',
      'name': 'Mama Njeri Kiosk',
      'offense': 'Wash Trading (Exceeded 500 KES Top-up)',
      'timestamp': '2 mins ago',
      'severity': 'High'
    },
    {
      'vendor_id': 'V-1088',
      'name': 'Student Center Cafe',
      'offense': 'Rapid Successive Scanning',
      'timestamp': '15 mins ago',
      'severity': 'Medium'
    },
  ];

  void _takeAction(String vendorId, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Action "\$action" executed against \$vendorId')),
    );
    setState(() {
      _flaggedVendors.removeWhere((v) => v['vendor_id'] == vendorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Fraud & Wash Trading'),
        backgroundColor: MPesaTheme.primaryRed,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _flaggedVendors.length,
          itemBuilder: (context, index) {
            final vendor = _flaggedVendors[index];
            final isHighSeverity = vendor['severity'] == 'High';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isHighSeverity ? Colors.red.shade200 : Colors.orange.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(vendor['vendor_id'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(vendor['timestamp'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(vendor['name'], style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                      vendor['offense'],
                      style: TextStyle(color: isHighSeverity ? MPesaTheme.primaryRed : Colors.orange, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _takeAction(vendor['vendor_id'], 'Dismiss'),
                          child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _takeAction(vendor['vendor_id'], 'Shadow Ban'),
                          style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryRed),
                          child: const Text('Shadow Ban'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
