import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DocumentVaultView extends StatefulWidget {
  const DocumentVaultView({super.key});

  @override
  State<DocumentVaultView> createState() => _DocumentVaultViewState();
}

class _DocumentVaultViewState extends State<DocumentVaultView> {
  final String _parentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Document Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('parentUid', isEqualTo: _parentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: MPesaTheme.mpesaGreen));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading linked students', style: const TextStyle(color: Colors.red)));
          }
          final students = snapshot.data?.docs ?? [];
          if (students.isEmpty) {
            return const Center(child: Text('No linked students found.', style: TextStyle(color: Colors.white70)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final data = student.data() as Map<String, dynamic>;
              final name = data['name'] ?? data['displayName'] ?? 'Student';
              
              return _buildStudentDocuments(student.id, name);
            },
          );
        },
      ),
    );
  }

  Widget _buildStudentDocuments(String studentUid, String studentName) {
    return Card(
      color: const Color(0xFF131A2A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(studentName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: MPesaTheme.mpesaGreen),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload feature coming soon in next update')));
                  },
                )
              ],
            ),
            const Divider(color: Colors.white24),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(studentUid)
                  .collection('documents')
                  .snapshots(),
              builder: (context, docSnap) {
                if (docSnap.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: MPesaTheme.mpesaGreen));
                }
                final docs = docSnap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No documents uploaded yet.', style: TextStyle(color: Colors.white54)),
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.description, color: MPesaTheme.mpesaGreen),
                      title: Text(d['name'] ?? 'Document', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(d['type'] ?? 'Unknown Type', style: const TextStyle(color: Colors.white70)),
                      trailing: const Icon(Icons.remove_red_eye, color: Colors.white54),
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document viewer opening...')));
                      },
                    );
                  }).toList(),
                );
              }
            )
          ],
        ),
      ),
    );
  }
}
