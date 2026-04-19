// models/sale.dart
class Sale {
  final int id;
  final String date;
  final double totalAmount;
  final double totalProfit;
  final int? customerId;
  final String paymentType;
  final String? customerName;
  final double paidAmount;
  final double remainingAmount;
  final bool showForTax; // الحقل الجديد

  Sale({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.totalProfit,
    this.customerId,
    required this.paymentType,
    this.customerName,
    required this.paidAmount,
    required this.remainingAmount,
    required this.showForTax, // إضافة في الكونستركتور
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      date: map['date'],
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
      totalProfit: map['total_profit']?.toDouble() ?? 0.0,
      customerId: map['customer_id'],
      paymentType: map['payment_type'] ?? 'cash',
      customerName: map['customer_name'],
      paidAmount: map['paid_amount']?.toDouble() ?? 0.0,
      remainingAmount:
          map['remaining_amount']?.toDouble() ??
          ((map['payment_type'] ?? 'cash') == 'credit'
              ? map['total_amount']?.toDouble() ?? 0.0
              : 0.0),
      showForTax: (map['show_for_tax'] ?? 0) == 1, // تحويل 0/1 إلى bool
    );
  }

  bool get isFullyPaid => remainingAmount <= 0.0001;
  bool get isPartiallyPaid => paidAmount > 0.0001 && remainingAmount > 0.0001;
  bool get isUnpaid =>
      paymentType == 'credit' && !isFullyPaid && !isPartiallyPaid;

  String get creditStatusLabel {
    if (paymentType != 'credit') return 'نقدي';
    if (isFullyPaid) return 'مسدد';
    if (isPartiallyPaid) return 'جزئي';
    return 'دين';
  }

  String get formattedDate {
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  String get formattedTime {
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date;
    }
  }
}
