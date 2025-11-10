// models/sale_item.dart
class SaleItem {
  final int id;
  final int saleId;
  final int productId;
  final int quantity;
  final double price;
  final double costPrice;
  final double subtotal;
  final double profit;
  final String productName;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.costPrice,
    required this.subtotal,
    required this.profit,
    required this.productName,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      price: map['price']?.toDouble() ?? 0.0,
      costPrice: map['cost_price']?.toDouble() ?? 0.0,
      subtotal: map['subtotal']?.toDouble() ?? 0.0,
      profit: map['profit']?.toDouble() ?? 0.0,
      productName: map['product_name'],
    );
  }
}
