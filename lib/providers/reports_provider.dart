// reports_provider.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';

class ReportsProvider extends ChangeNotifier {
  final dynamic _db = DBHelper();

  // حالة التحميل
  bool isLoading = false;
  void _setLoading(bool v) {
    isLoading = v;
    notifyListeners();
  }

  // --- بيانات ملخّصة ---
  double totalSalesPeriod = 0;
  double totalProfitPeriod = 0;
  int invoicesCount = 0;
  double avgInvoice = 0;
  Map<String, double> paymentDistribution =
      {}; // { 'cash': 1000.0, 'card': 500.0 }
  List<Map<String, dynamic>> topProducts =
      []; // [{product_id, name, total_sold}]
  List<Map<String, dynamic>> salesByDate =
      []; // [{date: '2025-11-05', total_amount: 100, total_profit: 20}]

  // تحميل كل البيانات لفترة معينة (start, end) كـ DateTime
  Future<void> loadAll({required DateTime start, required DateTime end}) async {
    _setLoading(true);
    try {
      await _loadTotals(start: start, end: end);
      await _loadTopProducts(start: start, end: end);
      await _loadPaymentDistribution(start: start, end: end);
      await _loadSalesByDate(start: start, end: end);
      _calcKpis();
    } finally {
      _setLoading(false);
    }
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadTotals({
    required DateTime start,
    required DateTime end,
  }) async {
    final s = _formatDate(start);
    final e = _formatDate(end);
    final sql = '''
      SELECT 
        IFNULL(SUM(total_amount), 0) as total_sales,
        IFNULL(SUM(total_profit), 0) as total_profit,
        COUNT(*) as invoices_count
      FROM sales
      WHERE date(date) BETWEEN date(?) AND date(?);
    ''';
    final res = await _db.rawQuery(sql, [s, e]);
    if (res.isNotEmpty) {
      totalSalesPeriod = (res[0]['total_sales'] as num).toDouble();
      totalProfitPeriod = (res[0]['total_profit'] as num).toDouble();
      invoicesCount = (res[0]['invoices_count'] as num).toInt();
    } else {
      totalSalesPeriod = 0;
      totalProfitPeriod = 0;
      invoicesCount = 0;
    }
  }

  Future<void> _loadTopProducts({
    required DateTime start,
    required DateTime end,
    int limit = 5,
  }) async {
    final s = _formatDate(start);
    final e = _formatDate(end);
    final sql = '''
      SELECT p.id as product_id, p.name, SUM(si.quantity) as total_sold
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      JOIN products p ON si.product_id = p.id
      WHERE date(s.date) BETWEEN date(?) AND date(?)
      GROUP BY si.product_id
      ORDER BY total_sold DESC
      LIMIT ?;
    ''';
    final res = await _db.rawQuery(sql, [s, e, limit]);
    topProducts =
        res
            .map(
              (r) => {
                'product_id': r['product_id'],
                'name': r['name'],
                'total_sold': r['total_sold'],
              },
            )
            .toList();
  }

  Future<void> _loadPaymentDistribution({
    required DateTime start,
    required DateTime end,
  }) async {
    final s = _formatDate(start);
    final e = _formatDate(end);
    final sql = '''
      SELECT payment_type, IFNULL(SUM(total_amount),0) as amount
      FROM sales
      WHERE date(date) BETWEEN date(?) AND date(?)
      GROUP BY payment_type;
    ''';
    final res = await _db.rawQuery(sql, [s, e]);
    paymentDistribution = {};
    for (final r in res) {
      paymentDistribution[r['payment_type'] as String] =
          (r['amount'] as num).toDouble();
    }
  }

  Future<void> _loadSalesByDate({
    required DateTime start,
    required DateTime end,
  }) async {
    final s = _formatDate(start);
    final e = _formatDate(end);
    final sql = '''
      SELECT date(date) as day, IFNULL(SUM(total_amount),0) as total_amount, IFNULL(SUM(total_profit),0) as total_profit
      FROM sales
      WHERE date(date) BETWEEN date(?) AND date(?)
      GROUP BY date(date)
      ORDER BY date(date) ASC;
    ''';
    final res = await _db.rawQuery(sql, [s, e]);
    salesByDate =
        res
            .map(
              (r) => {
                'date': r['day'],
                'total_amount': (r['total_amount'] as num).toDouble(),
                'total_profit': (r['total_profit'] as num).toDouble(),
              },
            )
            .toList();
  }

  void _calcKpis() {
    avgInvoice = invoicesCount > 0 ? totalSalesPeriod / invoicesCount : 0;
    // مؤشرات أخرى ممكن تحسب هنا
    notifyListeners();
  }

  // دوال إضافية للفلترة أو إعادة تحميل
  Future<void> reloadForLastNDays(int days) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    await loadAll(start: start, end: end);
  }
}
