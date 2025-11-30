class ProductUnit {
  int? id;
  int productId;
  String unitName; // "كرتونة", "علبة", "باكيت"...
  String? barcode;
  double containQty; // كم تحتوي من الوحدة الأساسية
  double sellPrice; // سعر بيع هذه الوحدة

  ProductUnit({
    this.id,
    required this.productId,
    required this.unitName,
    this.barcode,
    required this.containQty,
    required this.sellPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'unit_name': unitName,
      'barcode': barcode,
      'contain_qty': containQty,
      'sell_price': sellPrice,
    };
  }

  factory ProductUnit.fromMap(Map<String, dynamic> map) {
    return ProductUnit(
      id: map['id'],
      productId: map['product_id'],
      unitName: map['unit_name'],
      barcode: map['barcode'],
      containQty: map['contain_qty']?.toDouble() ?? 0.0,
      sellPrice: map['sell_price']?.toDouble() ?? 0.0,
    );
  }
}
