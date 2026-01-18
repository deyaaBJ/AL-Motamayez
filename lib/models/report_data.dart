// models/report_data.dart
class ReportData {
  final String period;
  final DateTime fromDate;
  final DateTime toDate;
  final Map<String, dynamic> statistics;
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> topCustomers;
  final List<Map<String, dynamic>> weeklySales;
  final String currency;

  ReportData({
    required this.period,
    required this.fromDate,
    required this.toDate,
    required this.statistics,
    required this.topProducts,
    required this.topCustomers,
    required this.weeklySales,
    required this.currency,
  });

  Map<String, dynamic> toMap() {
    return {
      'period': period,
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'statistics': statistics,
      'topProducts': topProducts,
      'topCustomers': topCustomers,
      'weeklySales': weeklySales,
      'currency': currency,
      'generatedDate': DateTime.now().toIso8601String(),
    };
  }
}
