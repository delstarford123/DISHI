import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import '../../../core/services/secure_storage_service.dart';

class ChangePinView extends StatefulWidget {
  const ChangePinView({super.key});

  @override
  State<ChangePinView> createState() => _ChangePinViewState();
}

class _ChangePinViewState extends State<ChangePinView> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  Future<void> _updatePin() async {
    final currentSavedPin = await SecureStorageService.getOfflinePin();
    
    if (_oldPinController.text != currentSavedPin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect old PIN')));
      return;
    }
    if (_newPinController.text != _confirmPinController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New PINs do not match')));
      return;
    }

    await SecureStorageService.saveOfflinePin(_newPinController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN updated successfully')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN'), backgroundColor: MPesaTheme.primaryGreen),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _oldPinController,
              decoration: const InputDecoration(labelText: 'Old PIN'),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPinController,
              decoration: const InputDecoration(labelText: 'New 4-digit PIN'),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPinController,
              decoration: const InputDecoration(labelText: 'Confirm New PIN'),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _updatePin,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: MPesaTheme.primaryGreen,
              ),
              child: const Text('Update PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
