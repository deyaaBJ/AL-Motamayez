import 'package:motamayez/models/product.dart';
import 'package:motamayez/models/product_unit.dart';

class CartItem {
  final Product? product;
  final bool isService;
  final String? serviceName;
  double quantity;
  final List<ProductUnit> availableUnits;
  ProductUnit? selectedUnit;
  double? customPrice;

  CartItem.product({
    required this.product,
    required this.quantity,
    this.availableUnits = const [],
    this.selectedUnit,
    this.customPrice,
  }) : isService = false,
       serviceName = null;

  CartItem.service({required this.serviceName, required double price})
    : isService = true,
      product = null,
      quantity = 1,
      availableUnits = const [],
      selectedUnit = null,
      customPrice = price;

  double get unitPrice =>
      customPrice ??
      (isService ? 0 : (selectedUnit?.sellPrice ?? product!.price));

  double get totalPrice => unitPrice * quantity;

  String get itemName => isService ? serviceName! : product!.name;

  String get unitName =>
      isService ? 'خدمة' : (selectedUnit?.unitName ?? product!.baseUnit);

  // أضف هذه الدالة لتعديل السعر
  void setCustomPrice(double? price) {
    customPrice = price;
  }
}
