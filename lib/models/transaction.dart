// models/transaction.dart

enum TransactionType { payment, withdrawal }

class Transaction {
  final int? id;
  final int customerId;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String? note;
  final DateTime? createdAt;

  Transaction({
    this.id,
    required this.customerId,
    required this.amount,
    required this.type,
    required this.date,
    this.note,
    this.createdAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      customerId: map['customer_id'],
      amount: (map['amount'] as num).toDouble(),
      type: _parseTransactionType(map['type']),
      date: DateTime.parse(map['date']),
      note: map['note'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  static TransactionType _parseTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return TransactionType.payment;
      case 'withdrawal':
        return TransactionType.withdrawal;
      default:
        return TransactionType.payment;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'type': type.name,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // دالة مساعدة لعرض النوع كنص بالعربية
  String get typeText {
    switch (type) {
      case TransactionType.payment:
        return 'تسديد دفعة';
      case TransactionType.withdrawal:
        return 'صرف رصيد';
    }
  }

  // دالة مساعدة للتحقق من النوع
  bool get isPayment => type == TransactionType.payment;
  bool get isWithdrawal => type == TransactionType.withdrawal;
}
