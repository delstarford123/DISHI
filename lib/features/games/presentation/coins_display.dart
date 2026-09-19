import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CoinsDisplay extends StatelessWidget {
  final String uid;

  const CoinsDisplay({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        int currentCoins = 0;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['dishi_coins'] != null) {
            currentCoins = data['dishi_coins'] as int;
          }
        }
        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                const SizedBox(width: 6),
                Text(
                  '$currentCoins',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
