import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'د.إ',
    decimalDigits: 2,
    locale: 'ar_AE',
  );

  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final format = DateFormat('yyyy/MM/dd HH:mm', 'ar');
      return format.format(date);
    } catch (e) {
      return dateString;
    }
  }

  static String formatDateWithTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final arabicMonths = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];

      final month = arabicMonths[date.month - 1];
      final day = date.day;
      final year = date.year;
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour < 12 ? 'صباحاً' : 'مساءً';
      final hour12 = hour > 12 ? hour - 12 : hour;

      return '$day $month $year - $hour12:$minute $period';
    } catch (e) {
      return formatDate(dateString);
    }
  }

  static String formatDateOnly(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final format = DateFormat('yyyy/MM/dd', 'ar');
      return format.format(date);
    } catch (e) {
      return dateString;
    }
  }

  static String formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final format = DateFormat('hh:mm a', 'ar');
      return format.format(date);
    } catch (e) {
      return dateString;
    }
  }

  static String formatNumber(double number) {
    final format = NumberFormat('#,##0.00', 'ar');
    return format.format(number);
  }

  static String formatPhone(String phone) {
    if (phone.isEmpty) return '';
    if (phone.startsWith('0')) {
      return '+963${phone.substring(1)}';
    }
    return phone;
  }
}
