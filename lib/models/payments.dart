class Payment {
  final int? id;
  final int customerId;
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime? createdAt;

  Payment({
    this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    this.note,
    this.createdAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      customerId: map['customer_id'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
