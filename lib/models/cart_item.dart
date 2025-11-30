import 'package:shopmate/models/product.dart';
import 'package:shopmate/models/product_unit.dart';

class CartItem {
  final Product product;
  double quantity;
  final List<ProductUnit> availableUnits;
  ProductUnit? selectedUnit;

  CartItem({
    required this.product,
    required this.quantity,
    this.availableUnits = const [],
    this.selectedUnit,
  });

  double get unitPrice => selectedUnit?.sellPrice ?? product.price;
  double get totalPrice => unitPrice * quantity;

  String get unitName => selectedUnit?.unitName ?? product.baseUnit;
}
