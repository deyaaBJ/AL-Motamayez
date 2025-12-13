class CustomerBalance {
  final int customerId;
  final double balance;
  final DateTime? lastUpdated;

  CustomerBalance({
    required this.customerId,
    required this.balance,
    this.lastUpdated,
  });

  // من Map (من قاعدة البيانات)
  factory CustomerBalance.fromMap(Map<String, dynamic> map) {
    return CustomerBalance(
      customerId: map['customer_id'],
      balance: (map['balance'] as num).toDouble(),
      lastUpdated:
          map['last_updated'] != null
              ? DateTime.parse(map['last_updated'])
              : null,
    );
  }

  // إلى Map (للحفظ في قاعدة البيانات)
  Map<String, dynamic> toMap() {
    return {
      'customer_id': customerId,
      'balance': balance,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }
}
