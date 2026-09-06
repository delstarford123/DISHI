import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _neonPink = Color(0xFFFF2A6D);
const Color _neonPurple = Color(0xFF9C27B0);
const Color _textSecondary = Color(0xFF8B9BB4);

class MatchPartnerVenuesView extends StatefulWidget {
  const MatchPartnerVenuesView({super.key});

  @override
  State<MatchPartnerVenuesView> createState() => _MatchPartnerVenuesViewState();
}

class _MatchPartnerVenuesViewState extends State<MatchPartnerVenuesView> {
  bool _isLoading = true;
  List<dynamic> _venues = [];

  @override
  void initState() {
    super.initState();
    _fetchVenues();
  }

  Future<void> _fetchVenues() async {
    try {
      final response = await http.get(
        Uri.parse('https://dishi.delstarfordworks.co.ke/api/v1/match_campus/campus/partner_venues'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _venues = data['venues'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showQRCode(Map<String, dynamic> venue) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(venue['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(venue['discount'], style: const TextStyle(color: _neonPink, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: QrImageView(
                  data: 'swapeat_match_discount_${venue['id']}',
                  version: QrVersions.auto,
                  size: 200.0,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              const Text('Show this to the vendor when paying.', textAlign: TextAlign.center, style: TextStyle(color: _textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Partner Venues', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonPink))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _venues.length,
            itemBuilder: (context, index) {
              final venue = _venues[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _neonPurple.withOpacity(0.3)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    backgroundColor: _neonPurple,
                    child: Icon(Icons.store, color: Colors.white),
                  ),
                  title: Text(venue['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(venue['discount'], style: const TextStyle(color: _neonPink, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${venue['distance']} away', style: const TextStyle(color: _textSecondary)),
                    ],
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _neonPink),
                    onPressed: () => _showQRCode(venue),
                    child: const Text('GET QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          ),
    );
  }
}
