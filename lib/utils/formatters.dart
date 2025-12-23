import 'package:intl/intl.dart';

class Formatters {
  /// تهيئة الـ locale حسب اللغة العربية
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'ar_SA',
    symbol: 'د.إ',
    decimalDigits: 2,
  );

  static final NumberFormat _numberFormatter = NumberFormat(
    '#,##0.00',
    'ar_SA',
  );
  static final NumberFormat _integerFormatter = NumberFormat('#,##0', 'ar_SA');
  static final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy', 'ar_SA');
  static final DateFormat _dateTimeFormatter = DateFormat(
    'dd/MM/yyyy hh:mm a',
    'ar_SA',
  );
  static final DateFormat _timeFormatter = DateFormat('hh:mm a', 'ar_SA');

  /// تنسيق التاريخ فقط (يوم/شهر/سنة)
  static String formatDate(DateTime date) {
    return _dateFormatter.format(date);
  }

  /// تنسيق التاريخ مع الوقت (يوم/شهر/سنة ساعة:دقيقة)
  static String formatDateTime(DateTime date) {
    return _dateTimeFormatter.format(date);
  }

  /// تنسيق الوقت فقط (ساعة:دقيقة)
  static String formatTime(DateTime date) {
    return _timeFormatter.format(date);
  }

  /// تنسيق العملة (باستخدام الـ locale العربي)
  static String formatCurrency(double amount) {
    if (amount == 0) return '٠.٠٠ د.إ';
    return _currencyFormatter.format(amount);
  }

  /// تنسيق الأرقام مع فواصل الآلاف (٢٥,٠٠٠.٠٠)
  static String formatNumber(double number) {
    return _numberFormatter.format(number);
  }

  /// تنسيق الأعداد الصحيحة مع فواصل الآلاف (٢٥,٠٠٠)
  static String formatInteger(int number) {
    return _integerFormatter.format(number);
  }

  /// تنسيق الرقم كرقم عربي (تحويل 123 إلى ١٢٣)
  static String toArabicDigits(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    String result = text;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }

  /// تنسيق الكمية مع الوحدة (مثال: ٢٥.٠٠ كجم)
  static String formatQuantity(double quantity, String unit) {
    return '${formatNumber(quantity)} $unit';
  }

  /// تنسيق المدة الزمنية (من ... إلى ...)
  static String formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '${formatDate(start)} من ${formatTime(start)} إلى ${formatTime(end)}';
    }
    return 'من ${formatDateTime(start)} إلى ${formatDateTime(end)}';
  }

  /// تنسيق رقم الهاتف (٩٧١-٥٠-١٢٣٤٥٦٧)
  static String formatPhoneNumber(String phone) {
    if (phone.isEmpty) return '';

    // إزالة جميع الأحرف غير رقمية
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length <= 3) return digits;
    if (digits.length <= 6)
      return '${digits.substring(0, 3)}-${digits.substring(3)}';

    return '${digits.substring(0, 3)}-${digits.substring(3, 5)}-${digits.substring(5)}';
  }

  /// تنسيق الباركود مع مسافات كل 4 أرقام
  static String formatBarcode(String barcode) {
    if (barcode.isEmpty) return '';

    String result = '';
    for (int i = 0; i < barcode.length; i++) {
      if (i > 0 && i % 4 == 0) result += ' ';
      result += barcode[i];
    }
    return result;
  }

  /// تنسيق الملاحظات مع قص النص وإضافة ...
  static String formatNote(String note, {int maxLength = 50}) {
    if (note.length <= maxLength) return note;
    return '${note.substring(0, maxLength)}...';
  }

  /// تحويل الحالة إلى نص عربي (مثال: active → نشط)
  static String formatStatus(String status) {
    const statusMap = {
      'active': 'نشط',
      'inactive': 'غير نشط',
      'pending': 'قيد الانتظار',
      'completed': 'مكتمل',
      'cancelled': 'ملغى',
      'cash': 'نقدي',
      'credit': 'آجل',
      'paid': 'مدفوع',
      'unpaid': 'غير مدفوع',
      'partial': 'مدفوع جزئياً',
    };

    return statusMap[status.toLowerCase()] ?? status;
  }

  /// تنسيق النسبة المئوية (٩٩.٩٩٪)
  static String formatPercentage(double value) {
    return '${formatNumber(value)}٪';
  }

  /// تحويل الثواني إلى تنسيق الوقت (ساعة:دقيقة:ثانية)
  static String formatSeconds(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// تنسيق حجم الملف (بايت، كيلوبايت، ميجابايت)
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} ك.بايت';
    return '${(bytes / 1048576).toStringAsFixed(1)} م.بايت';
  }
}
