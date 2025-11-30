class SaleItem {
  final int id;
  final int saleId;
  final int productId;
  final int? unitId;
  final double quantity;
  final String unitType;
  final String? customUnitName;
  final double price;
  final double costPrice;
  final double subtotal;
  final double profit;
  final String productName;
  final String productBaseUnit;
  final String? unitName;
  final double? unitContainQty;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    this.unitId,
    required this.quantity,
    required this.unitType,
    this.customUnitName,
    required this.price,
    required this.costPrice,
    required this.subtotal,
    required this.profit,
    required this.productName,
    required this.productBaseUnit,
    this.unitName,
    this.unitContainQty,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'],
      productId: map['product_id'],
      unitId: map['unit_id'],
      quantity: map['quantity']?.toDouble() ?? 0.0,
      unitType: map['unit_type'] ?? 'piece',
      customUnitName: map['custom_unit_name'],
      price: map['price']?.toDouble() ?? 0.0,
      costPrice: map['cost_price']?.toDouble() ?? 0.0,
      subtotal: map['subtotal']?.toDouble() ?? 0.0,
      profit: map['profit']?.toDouble() ?? 0.0,
      productName: map['product_name'] ?? '',
      productBaseUnit: map['product_base_unit'] ?? 'piece',
      unitName: map['custom_unit_name'],
      unitContainQty: map['unit_contain_qty']?.toDouble(),
    );
  }

  // دالة مساعدة للحصول على اسم الوحدة المعروضة
  String get displayUnit {
    switch (unitType) {
      case 'piece':
        return 'قطعة';
      case 'kg':
        return 'كيلو';
      case 'custom':
        return customUnitName ?? 'وحدة';
      default:
        return productBaseUnit == 'kg' ? 'كيلو' : 'قطعة';
    }
  }

  // دالة مساعدة للحصول على الكمية المعروضة
  String get displayQuantity {
    if (unitType == 'kg') {
      return quantity % 1 == 0
          ? quantity.toInt().toString()
          : quantity.toStringAsFixed(2);
    } else {
      return quantity.toInt().toString();
    }
  }
}
