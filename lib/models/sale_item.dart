class SaleItem {
  final int id;
  final int saleId;

  final String itemType; // product | service

  final int? productId;
  final int? unitId;

  final double quantity;
  final String unitType;
  final String? customUnitName;

  final double price;
  final double costPrice;
  final double subtotal;
  final double profit;

  final String itemName; // اسم المنتج أو اسم الخدمة
  final String? productBaseUnit;

  final String? unitName;
  final double? unitContainQty;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.itemType,
    this.productId,
    this.unitId,
    required this.quantity,
    required this.unitType,
    this.customUnitName,
    required this.price,
    required this.costPrice,
    required this.subtotal,
    required this.profit,
    required this.itemName,
    this.productBaseUnit,
    this.unitName,
    this.unitContainQty,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['sale_id'],
      itemType: map['item_type'] ?? 'product',
      productId: map['product_id'],
      unitId: map['unit_id'],
      quantity: map['quantity']?.toDouble() ?? 1.0,
      unitType: map['unit_type'] ?? 'piece',
      customUnitName: map['custom_unit_name'],
      price: map['price']?.toDouble() ?? 0.0,
      costPrice: map['cost_price']?.toDouble() ?? 0.0,
      subtotal: map['subtotal']?.toDouble() ?? 0.0,
      profit: map['profit']?.toDouble() ?? 0.0,

      // ⬇️ المهم
      itemName: map['item_name'] ?? map['product_name'] ?? 'خدمة',
      productBaseUnit: map['product_base_unit'],
      unitName: map['unit_name'],
      unitContainQty: map['unit_contain_qty']?.toDouble(),
    );
  }

  /// اسم الوحدة المعروض
  String get displayUnit {
    if (itemType == 'service') return 'خدمة';

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

  /// الكمية المعروضة
  String get displayQuantity {
    if (itemType == 'service') return '1';

    if (unitType == 'kg') {
      return quantity % 1 == 0
          ? quantity.toInt().toString()
          : quantity.toStringAsFixed(2);
    } else {
      return quantity.toInt().toString();
    }
  }
}
