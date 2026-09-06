import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'KSH ',
    decimalDigits: 2,
  );

  static String format(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return 'KSH \${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return 'KSH \${(amount / 1000).toStringAsFixed(1)}K';
    }
    return 'KSH \${amount.toStringAsFixed(0)}';
  }
}
