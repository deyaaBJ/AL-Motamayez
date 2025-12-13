// utils/date_formatter.dart
class DateFormatter {
  static Map<String, String> formatDateTime(String dateString) {
    try {
      // تنظيف السلسلة النصية
      String formattedDateString = dateString.trim();

      // التعامل مع تنسيقات التاريخ المختلفة
      if (formattedDateString.contains('T') &&
          formattedDateString.contains('Z')) {
        // تنسيق ISO مع الوقت العالمي
        formattedDateString = formattedDateString
            .replaceAll('T', ' ')
            .replaceAll('Z', '');
      } else if (formattedDateString.contains('T')) {
        // تنسيق ISO بدون الوقت العالمي
        formattedDateString = formattedDateString.replaceAll('T', ' ');
      }

      // تحليل التاريخ
      DateTime date;
      try {
        date = DateTime.parse(formattedDateString);
      } catch (e) {
        // محاولة تحليل التاريخ بصيغة أخرى
        final parts = formattedDateString.split(' ');
        if (parts.isNotEmpty) {
          date = DateTime.parse(parts[0]);
        } else {
          return {'date': dateString, 'time': '', 'formatted': dateString};
        }
      }

      // الأشهر العربية
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

      // أيام الأسبوع العربية
      const arabicDays = [
        'الأحد',
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
      ];

      // تنسيق التاريخ
      final dayName = arabicDays[date.weekday % 7];
      final day = date.day.toString().padLeft(2, '0');
      final month = arabicMonths[date.month - 1];
      final year = date.year.toString();

      // التاريخ القصير (بدون يوم الأسبوع)
      final shortDate = '$day $month $year';

      // التاريخ الطويل
      final longDate = '$dayName، $day $month $year';

      // التاريخ برقم الشهر
      final numericDate =
          '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

      // تنسيق الوقت
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final second = date.second.toString().padLeft(2, '0');
      final period = hour < 12 ? 'ص' : 'م';
      final hour12 = hour % 12;
      final formattedHour = (hour12 == 0 ? 12 : hour12).toString();

      // الوقت بصيغة 24 ساعة
      final time24 = '${hour.toString().padLeft(2, '0')}:$minute';

      // الوقت بصيغة 12 ساعة
      final time12 = '$formattedHour:$minute $period';

      // الوقت مع الثواني
      final timeWithSeconds = '$formattedHour:$minute:$second $period';

      // تاريخ ووقت كامل
      final fullDateTime = '$longDate - $time12';

      return {
        'date': longDate,
        'time': time12,
        'short_date': shortDate,
        'numeric_date': numericDate,
        'day_name': dayName,
        'day': day,
        'month': month,
        'month_number': date.month.toString().padLeft(2, '0'),
        'year': year,
        'time_24': time24,
        'time_12': time12,
        'time_with_seconds': timeWithSeconds,
        'hour': hour.toString(),
        'minute': minute,
        'second': second,
        'period': period,
        'full_datetime': fullDateTime,
        'timestamp': date.millisecondsSinceEpoch.toString(),
        'iso_date': date.toIso8601String(),
      };
    } catch (e) {
      // في حالة حدوث خطأ، إرجاع البيانات الأساسية
      return {
        'date': dateString,
        'time': '',
        'full_datetime': dateString,
        'error': e.toString(),
      };
    }
  }

  // دالة إضافية للحصول على التاريخ الحالي
  static Map<String, String> getCurrentDateTime() {
    final now = DateTime.now();
    return formatDateTime(now.toIso8601String());
  }

  // دالة لتحويل timestamp إلى تاريخ مقروء
  static Map<String, String> formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return formatDateTime(date.toIso8601String());
  }

  // دالة للحصول على الفرق بين تاريخين - تصحيح الخطأ
  static String getTimeDifference(String dateString) {
    try {
      final Map<String, String> formattedDate = formatDateTime(dateString);
      final date = DateTime.parse(
        dateString.contains('T') ? dateString : '${dateString}T00:00:00',
      );
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return 'قبل $years سنة';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return 'قبل $months شهر';
      } else if (difference.inDays > 0) {
        return 'قبل ${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return 'قبل ${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return 'قبل ${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (e) {
      // تصحيح الخطأ: استخدام dateString مباشرة بدلاً من formattedDate
      return dateString;
    }
  }

  // دالة بديلة لصياغة التاريخ والوقت فقط
  static String formatDateTimeString(String dateString) {
    final Map<String, String> formatted = formatDateTime(dateString);
    return formatted['full_datetime'] ?? dateString;
  }

  // دالة لصياغة التاريخ فقط
  static String formatDateOnly(String dateString) {
    final Map<String, String> formatted = formatDateTime(dateString);
    return formatted['date'] ?? dateString;
  }

  // دالة لصياغة الوقت فقط
  static String formatTimeOnly(String dateString) {
    final Map<String, String> formatted = formatDateTime(dateString);
    return formatted['time'] ?? '';
  }
}
