// models/customer.dart
class Customer {
  int? id;
  final String name;
  final String? phone;

  Customer({this.id, required this.name, this.phone});

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
    );
  }

  // دالة مساعدة للتحويل الآمن إلى double

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
    );
  }
}
