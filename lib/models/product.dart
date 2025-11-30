class Product {
  int? id;
  String name;
  String barcode;
  String baseUnit; // piece أو kg
  double price;
  double quantity;
  double costPrice;
  String? addedDate;

  // حذف الحقول القديمة
  // double? packPrice;
  // double? packSize;
  // int allowPack;
  // String unit;

  Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.baseUnit,
    required this.price,
    required this.quantity,
    required this.costPrice,
    this.addedDate,
  });

  // Convert a Product object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'base_unit': baseUnit,
      'price': price,
      'quantity': quantity,
      'cost_price': costPrice,
      'added_date': addedDate,
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
    );
  }
}
