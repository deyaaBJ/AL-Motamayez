// models/customer.dart
class Customer {
  int? id;
  final String name;
  final String? phone;
  final double debt; // إجمالي الدين
  final double totalCash; // إجمالي النقدي

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.debt = 0.0,
    this.totalCash = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      // لا نحتاج لحفظ debt و totalCash في قاعدة البيانات
      // لأنها تُحسب تلقائياً من الفواتير
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString(),
      debt: _safeToDouble(map['debt']),
      totalCash: _safeToDouble(map['total_cash']),
    );
  }

  // دالة مساعدة للتحويل الآمن إلى double
  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    double? debt,
    double? totalCash,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      debt: debt ?? this.debt,
      totalCash: totalCash ?? this.totalCash,
    );
  }
}
