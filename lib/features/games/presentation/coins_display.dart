import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';

class CoinsDisplay extends StatelessWidget {
  final String uid;
  final int sessionCoins; // Coins earned in the current session

  const CoinsDisplay({super.key, required this.uid, this.sessionCoins = 0});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        int baseCoins = 0;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['dishi_coins'] != null) {
            baseCoins = (data['dishi_coins'] as num).toInt();
          }
        }
        
        int totalDisplayCoins = baseCoins + sessionCoins;

        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Center(
            child: ElasticIn(
              key: ValueKey<int>(totalDisplayCoins),
              duration: const Duration(milliseconds: 800),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    '$totalDisplayCoins',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (sessionCoins > 0) ...[
                    const SizedBox(width: 4),
                    FadeInUp(
                      key: ValueKey<int>(sessionCoins),
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        '+$sessionCoins',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
