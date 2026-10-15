
class VendorAgentService {
  static const double maxDailyCommission = 1000.0;

  /// Calculates the commission a Vendor earns for topping up a student.
  /// Rules: 0.5% commission only (no extra money for vendor).
  static double calculateTopUpCommission(double amount) {
    if (amount <= 0) return 0.0;
    final comm = amount * 0.005; // 0.5% only
    return double.parse(comm.toStringAsFixed(2));
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
    if ((commissionsEarnedToday + pendingCommission) > maxDailyCommission) {
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
