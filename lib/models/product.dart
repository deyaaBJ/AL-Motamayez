class Product {
  int? id;
  String name;
  String barcode;
  double price;
  double costPrice;
  int quantity;
  String? addedDate;

  Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.costPrice,
    required this.quantity,
    this.addedDate,
  });

  // Convert a Product object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'cost_price': costPrice,
      'quantity': quantity,
      'added_date': addedDate,
    };
  }

  // Create a Product object from a Map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      price: map['price'],
      costPrice: map['cost_price'],
      quantity: map['quantity'],
      addedDate: map['added_date'],
    );
  }
}
