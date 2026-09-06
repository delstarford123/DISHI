import 'dart:math';

class VendorAgentService {
  static const double _maxDailyCommission = 500.0;

  /// Calculates the commission a Vendor earns for topping up a student.
  /// Rules: Under 100 KES = Flat 2 KES. 100 KES and above = 0.5%.
  static double calculateTopUpCommission(double amount) {
    if (amount <= 0) return 0.0;
    if (amount < 100) {
      return 2.0; // Flat 2 KES
    } else {
      return amount * 0.005; // 0.5%
    }
  }

  /// Verifies if a Vendor is eligible for commission based on the strict Anti-Fraud rules.
  static bool isEligibleForCommission({
    required double topUpAmount,
    required double totalFoodSalesVolume,
    required double totalTopUpVolume,
    required double commissionsEarnedToday,
  }) {
    // 1. Daily Cap Check (Cannot exceed 500 KES per day)
    final pendingCommission = calculateTopUpCommission(topUpAmount);
    if ((commissionsEarnedToday + pendingCommission) > _maxDailyCommission) {
      return false; 
    }

    // 2. Wash Trading Ratio Check (1:1 Ratio)
    // Vendors cannot earn commission if their total top-up volume is greater than their legitimate food sales volume.
    final newTopUpVolume = totalTopUpVolume + topUpAmount;
    if (newTopUpVolume > totalFoodSalesVolume) {
      return false;
    }

    return true;
  }

  static bool isWashTradingSuspected() {
    // Mock implementation for UI compilation.
    return false;
  }
}
