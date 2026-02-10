class CashierActivityModel {
  final int userId;
  final String userName;
  final String userEmail;
  final int totalInvoices;
  final double totalSales;
  final List<InvoiceSummary> invoices;

  CashierActivityModel({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.totalInvoices,
    required this.totalSales,
    required this.invoices,
  });

  factory CashierActivityModel.fromMap(
    Map<String, dynamic> map,
    List<InvoiceSummary> invoices,
  ) {
    return CashierActivityModel(
      userId: map['user_id'] ?? 0,
      userName: map['user_name'] ?? '',
      userEmail: map['user_email'] ?? '',
      totalInvoices: map['total_invoices'] ?? 0,
      totalSales: (map['total_sales'] as num?)?.toDouble() ?? 0.0,
      invoices: invoices,
    );
  }
}

class InvoiceSummary {
  final int saleId;
  final DateTime date;
  final double totalAmount;
  final double totalProfit;
  final String paymentType;
  final String? customerName;

  InvoiceSummary({
    required this.saleId,
    required this.date,
    required this.totalAmount,
    required this.totalProfit,
    required this.paymentType,
    this.customerName,
  });

  factory InvoiceSummary.fromMap(Map<String, dynamic> map) {
    return InvoiceSummary(
      saleId: map['id'] ?? 0,
      date: DateTime.parse(map['date']),
      totalAmount: (map['total_amount'] as num).toDouble(),
      totalProfit: (map['total_profit'] as num).toDouble(),
      paymentType: map['payment_type'] ?? 'cash',
      customerName: map['customer_name'],
    );
  }
}
