class Product {
  int? id;
  String name;
  String? barcode;
  String baseUnit;
  double price;
  double quantity;
  double costPrice;
  String? addedDate;
  bool hasExpiryDate; // ⬅️ جديد: لتحديد إذا كان للمنتج تاريخ صلاحية
  bool active; // ⬅️ جديد: حالة المنتج

  Product({
    this.id,
    required this.name,
    this.barcode,
    required this.baseUnit,
    required this.price,
    required this.quantity,
    required this.costPrice,
    this.addedDate,
    this.hasExpiryDate = false, // ⬅️ جديد: الافتراضي بدون تاريخ صلاحية
    this.active = true, // ⬅️ جديد: الافتراضي نشط
  });

  // Convert a Product object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode ?? '',
      'base_unit': baseUnit,
      'price': price,
      'quantity': quantity,
      'cost_price': costPrice,
      'added_date': addedDate,
      'has_expiry_date': hasExpiryDate ? 1 : 0, // ⬅️ جديد
      'active': active ? 1 : 0, // ⬅️ جديد
    };
  }

  // Create a Product object from a Map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      baseUnit: map['base_unit'] ?? 'piece',
      price: map['price']?.toDouble() ?? 0.0,
      quantity: map['quantity']?.toDouble() ?? 0.0,
      costPrice: map['cost_price']?.toDouble() ?? 0.0,
      addedDate: map['added_date'],
      hasExpiryDate: map['has_expiry_date'] == 1, // ⬅️ جديد
      active: map['active'] == 1, // ⬅️ جديد
    );
  }
}
