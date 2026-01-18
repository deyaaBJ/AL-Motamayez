// models/expense.dart
class Expense {
  final int? id;
  final String type;
  final double amount;
  final String date;
  final String? paymentType; // cash, transfer, check
  final String? note;
  final String createdAt;

  Expense({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.paymentType,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'date': date,
      'payment_type': paymentType,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      type: map['type'],
      amount: map['amount'].toDouble(),
      date: map['date'],
      paymentType: map['payment_type'],
      note: map['note'],
      createdAt: map['created_at'] ?? '',
    );
  }
}
