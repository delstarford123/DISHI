import 'package:flutter/material.dart';
import '../../../core/widgets/conflict_resolution_wrapper.dart';
import 'login_view.dart';
// Note: In production, this wrapper would listen to a global Provider or BLoC
// that streams the current `auth_sync` status from OfflineSyncService.

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Simulating the state listener for email collisions
  bool _hasEmailCollision = false;

  void _triggerMergeFlow() {
    setState(() => _hasEmailCollision = false);
    // Logic to route user to login so they can merge their offline session
  }

  void _triggerChangeEmailFlow() {
    setState(() => _hasEmailCollision = false);
    // Logic to prompt user for a new email, then retry the sync queue
  }

  @override
  Widget build(BuildContext context) {
    return ConflictResolutionWrapper(
      hasCollision: _hasEmailCollision,
      onMergeSelected: _triggerMergeFlow,
      onChangeEmailSelected: _triggerChangeEmailFlow,
      // The child is the root of the app routing. If not logged in, show LoginView.
      child: const LoginView(), 
    );
  }
}
