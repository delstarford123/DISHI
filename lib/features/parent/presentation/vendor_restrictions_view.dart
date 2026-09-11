import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class VendorRestrictionsView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const VendorRestrictionsView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<VendorRestrictionsView> createState() => _VendorRestrictionsViewState();
}

class _VendorRestrictionsViewState extends State<VendorRestrictionsView> {
    List<dynamic> _blockedVendors = [];
  bool _isLoading = false;

  final _vendorIdController = TextEditingController();

  Future<void> _fetchRestrictions(String studentUid) async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(studentUid).get();
      if (doc.exists) {
        setState(() {
          _blockedVendors = doc.data()?['blockedVendors'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRestrictions() async {
    if (widget.selectedStudentUid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.selectedStudentUid).update({
        'blockedVendors': _blockedVendors,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restrictions updated!'), backgroundColor: MPesaTheme.primaryGreen),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _addVendor() {
    final vendorId = _vendorIdController.text.trim();
    if (vendorId.isNotEmpty && !_blockedVendors.contains(vendorId)) {
      setState(() {
        _blockedVendors.add(vendorId);
      });
      _vendorIdController.clear();
      _updateRestrictions();
    }
  }

  void _removeVendor(String vendorId) {
    setState(() {
      _blockedVendors.remove(vendorId);
    });
    _updateRestrictions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Vendor Restrictions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Allowable Vendors',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explicitly block specific vendors (by Vendor ID) from receiving payments from your student.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            if (widget.selectedStudentUid == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No student selected in Dependents tab.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 24),
            if (widget.selectedStudentUid != null) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _vendorIdController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter Vendor ID to Block',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF131A2A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addVendor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MPesaTheme.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('BLOCK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Blocked Vendors',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryRed))
              else if (_blockedVendors.isEmpty)
                const Text('No vendors are currently blocked.', style: TextStyle(color: Colors.white54))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _blockedVendors.length,
                    itemBuilder: (context, index) {
                      final vendorId = _blockedVendors[index];
                      return Card(
                        color: const Color(0xFF131A2A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent, width: 0.5)),
                        child: ListTile(
                          leading: const Icon(Icons.block, color: MPesaTheme.primaryRed),
                          title: Text('Vendor ID: $vendorId', style: const TextStyle(color: Colors.white)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white54),
                            onPressed: () => _removeVendor(vendorId),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

