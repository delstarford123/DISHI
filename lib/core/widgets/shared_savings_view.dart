import 'package:flutter/material.dart';
import '../theme/mpesa_theme.dart';
import '../utils/deposit_helper.dart';

class SharedSavingsView extends StatelessWidget {
  final double currentVaultBalance;
  final String parentPhoneNumber;

  const SharedSavingsView({
    super.key,
    required this.currentVaultBalance,
    required this.parentPhoneNumber,
  });

  void _triggerVaultFunding(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: MPesaTheme.surfaceColor,
          title: const Text('Fund Vault', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Amount (KSH)',
              labelStyle: TextStyle(color: MPesaTheme.textSecondaryColor),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: MPesaTheme.surfaceLightColor)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: MPesaTheme.mpesaGreen)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: MPesaTheme.textSecondaryColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.mpesaGreen),
              onPressed: () {
                final double? amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.pop(context);
                  DepositHelper.initiateStkPush(
                    phoneNumber: parentPhoneNumber,
                    amount: amount,
                    accountReference: 'VAULT_FUND',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('STK Push sent for KSH $amount to your M-PESA'), backgroundColor: MPesaTheme.mpesaGreen),
                  );
                }
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MPesaTheme.primaryGreen, Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Savings Vault',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Icon(Icons.shield, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'KSH \${currentVaultBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _triggerVaultFunding(context),
            icon: const Icon(Icons.add, color: MPesaTheme.primaryGreen),
            label: const Text('Fund Vault via M-PESA', style: TextStyle(color: MPesaTheme.primaryGreen)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
