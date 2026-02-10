import 'package:flutter/material.dart';
import 'package:motamayez/db/db_helper.dart';
import '../models/cashier_activity_model.dart';

class CashierActivityProvider with ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  // ========== المتغيرات ==========
  List<CashierActivityModel> _cashierActivities = [];
  DateFilter _currentFilter = DateFilter.today;
  DateTime? _customDay; // ⬅️ جديد: يوم واحد مخصص
  bool _isLoading = false;
  String? _error;

  // ========== Getters ==========
  List<CashierActivityModel> get cashierActivities => _cashierActivities;
  DateFilter get currentFilter => _currentFilter;
  DateTime? get customDay => _customDay; // ⬅️ جديد
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ========== الفلاتر الزمنية ==========
  Map<String, dynamic> _getDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (_currentFilter) {
      case DateFilter.today:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case DateFilter.yesterday:
        start = DateTime(now.year, now.month, now.day - 1);
        end = DateTime(now.year, now.month, now.day);
        break;
      case DateFilter.thisWeek:
        final weekDay = now.weekday;
        start = DateTime(now.year, now.month, now.day - weekDay + 1);
        end = start.add(const Duration(days: 7));
        break;
      case DateFilter.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;
      case DateFilter.thisYear:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1);
        break;
      case DateFilter.customDay: // ⬅️ جديد
        if (_customDay != null) {
          start = DateTime(
            _customDay!.year,
            _customDay!.month,
            _customDay!.day,
          );
          end = start.add(const Duration(days: 1));
        } else {
          start = DateTime(now.year, now.month, now.day);
          end = start.add(const Duration(days: 1));
        }
        break;
    }

    return {'start': start.toIso8601String(), 'end': end.toIso8601String()};
  }

  // ========== تحميل البيانات ==========
  Future<void> loadCashierActivities() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final db = await _dbHelper.db;
      final dateRange = _getDateRange();

      // ⬅️ تعديل: LEFT JOIN مع users عشان البيانات القديمة ما تضيع
      final results = await db.rawQuery(
        '''
        SELECT 
          s.user_id,
          u.name as user_name,
          u.email as user_email,
          COUNT(s.id) as total_invoices,
          COALESCE(SUM(s.total_amount), 0) as total_sales,
          GROUP_CONCAT(s.id) as sale_ids
        FROM sales s
        LEFT JOIN users u ON s.user_id = u.id
        WHERE s.date >= ? AND s.date < ?
        GROUP BY s.user_id, u.name, u.email
        ORDER BY total_sales DESC
      ''',
        [dateRange['start'], dateRange['end']],
      );

      List<CashierActivityModel> activities = [];

      for (var row in results) {
        final userId = row['user_id'] as int?;
        final userName = row['user_name'] as String? ?? 'غير معروف';
        final userEmail = row['user_email'] as String? ?? '';

        // ⬅️ تخطي الفواتير اللي ما فيها user_id (البيانات القديمة)
        if (userId == null) continue;

        final saleIdsStr = row['sale_ids'] as String;
        final saleIds = saleIdsStr.split(',').map(int.parse).toList();

        // جلب تفاصيل الفواتير
        final invoicesData = await db.rawQuery('''
          SELECT 
            s.id,
            s.date,
            s.total_amount,
            s.total_profit,
            s.payment_type,
            c.name as customer_name
          FROM sales s
          LEFT JOIN customers c ON s.customer_id = c.id
          WHERE s.id IN (${saleIds.map((_) => '?').join(',')})
          ORDER BY s.date DESC
        ''', saleIds);

        final invoices =
            invoicesData.map((e) => InvoiceSummary.fromMap(e)).toList();

        activities.add(
          CashierActivityModel.fromMap({
            'user_id': userId,
            'user_name': userName,
            'user_email': userEmail,
            'total_invoices': row['total_invoices'],
            'total_sales': row['total_sales'],
          }, invoices),
        );
      }

      _cashierActivities = activities;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل البيانات: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========== تغيير الفلتر ==========
  void setFilter(DateFilter filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      if (filter != DateFilter.customDay) {
        _customDay = null;
      }
      loadCashierActivities();
    }
  }

  // ⬅️ جديد: تعيين يوم مخصص
  void setCustomDay(DateTime day) {
    _currentFilter = DateFilter.customDay;
    _customDay = day;
    loadCashierActivities();
  }

  // ========== تحديث ==========
  Future<void> refresh() async {
    await loadCashierActivities();
  }

  // ========== مسح البيانات ==========
  void clear() {
    _cashierActivities = [];
    _currentFilter = DateFilter.today;
    _customDay = null;
    _error = null;
    notifyListeners();
  }
}

// ========== enum DateFilter ==========
enum DateFilter {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  thisYear,
  customDay, // ⬅️ جديد: يوم واحد مخصص
}

extension DateFilterExtension on DateFilter {
  String get displayName {
    switch (this) {
      case DateFilter.today:
        return 'اليوم';
      case DateFilter.yesterday:
        return 'أمس';
      case DateFilter.thisWeek:
        return 'هذا الأسبوع';
      case DateFilter.thisMonth:
        return 'هذا الشهر';
      case DateFilter.thisYear:
        return 'هذه السنة';
      case DateFilter.customDay:
        return 'يوم محدد'; // ⬅️ جديد
    }
  }
}
