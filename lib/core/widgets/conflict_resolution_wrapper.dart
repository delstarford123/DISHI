import 'package:flutter/material.dart';

/// Wraps auth flows to handle the "Email Collision" offline scenario
/// detailed in security.txt.
class ConflictResolutionWrapper extends StatelessWidget {
  final Widget child;
  final bool hasCollision;
  final VoidCallback onMergeSelected;
  final VoidCallback onChangeEmailSelected;

  const ConflictResolutionWrapper({
    super.key,
    required this.child,
    required this.hasCollision,
    required this.onMergeSelected,
    required this.onChangeEmailSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasCollision) return child;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Email Already Exists',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'An account with this email already exists on DISHI. Would you like to merge your offline data into it, or use a different email?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onMergeSelected,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Login to Merge Data'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onChangeEmailSelected,
              child: const Text('Use a Different Email'),
            ),
          ],
        ),
      ),
    );
  }
}
