// models/supplier_model.dart
class SupplierModel {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final double balance;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    required this.balance,
    this.createdAt,
    this.updatedAt,
  });

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'] as int,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      balance: (map['balance'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }
}
