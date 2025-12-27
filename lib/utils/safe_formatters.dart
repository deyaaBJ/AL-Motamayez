import 'formatters.dart';

class SafeFormatters {
  static String formatDate(DateTime date) {
    try {
      return Formatters.formatDate(date);
    } catch (e) {
      // بديل إذا فشل Formatters
      final year = date.year;
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$year/$month/$day $hour:$minute';
    }
  }

  static String formatCurrency(double amount) {
    return Formatters.formatCurrency(amount);
  }

  static String formatNumber(double number) {
    return Formatters.formatNumber(number);
  }

  // يمكنك إضافة باقي الدوال حسب الحاجة
}
