import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';

class CoParentingInviteView extends StatefulWidget {
  final Map<String, dynamic> parentUser;
  final String? selectedStudentUid;

  const CoParentingInviteView({
    super.key,
    required this.parentUser,
    this.selectedStudentUid,
  });

  @override
  State<CoParentingInviteView> createState() => _CoParentingInviteViewState();
}

class _CoParentingInviteViewState extends State<CoParentingInviteView> {
    final _emailController = TextEditingController();

  bool _isInviting = false;

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || widget.selectedStudentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student and enter an email address.')),
      );
      return;
    }

    setState(() => _isInviting = true);
    try {
      // 1. Check if the user exists
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user found with that email. They must register first.')),
          );
        }
        return;
      }

      final targetParent = querySnapshot.docs.first;
      final targetParentUid = targetParent.id;

      // 2. Add targetParentUid to the student's linkedParents array
      await FirebaseFirestore.instance.collection('users').doc(widget.selectedStudentUid).update({
        'linkedParents': FieldValue.arrayUnion([targetParentUid])
      });

      // 3. Add studentUid to the target parent's linkedStudents array
      await FirebaseFirestore.instance.collection('users').doc(targetParentUid).update({
        'linkedStudents': FieldValue.arrayUnion([widget.selectedStudentUid])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Co-Parent linked successfully!'), backgroundColor: MPesaTheme.primaryGreen),
        );
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Co-Parenting'),
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
              'Invite a Co-Parent',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share management of your student\'s wallet with another guardian. Enter their registered email address below.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            if (widget.selectedStudentUid == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No student selected in Dependents tab.', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Co-Parent Email',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF131A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.email, color: MPesaTheme.neonCyan),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isInviting ? null : _sendInvite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MPesaTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isInviting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Send Invite', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

