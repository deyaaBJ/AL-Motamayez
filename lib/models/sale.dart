// models/sale.dart
class Sale {
  final int id;
  final String date;
  final double totalAmount;
  final double totalProfit;
  final int? customerId;
  final String paymentType;
  final String? customerName;

  Sale({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.totalProfit,
    this.customerId,
    required this.paymentType,
    this.customerName,
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
    );
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
      return '';
    }
  }
}
