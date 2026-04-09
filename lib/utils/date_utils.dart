// utils/date_utils.dart
class DateUtils {
  static String getCurrentDate() {
    final now = DateTime.now();
    const arabicMonths = [
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
    return '${now.day} ${arabicMonths[now.month - 1]} ${now.year}';
  }
}
