import 'package:motamayez/models/product.dart';
import 'package:motamayez/models/product_unit.dart';

class CartItem {
  final Product product;
  double quantity;
  final List<ProductUnit> availableUnits;
  ProductUnit? selectedUnit;
  double? customPrice; // السعر المعدل للفاتورة فقط

  CartItem({
    required this.product,
    required this.quantity,
    this.availableUnits = const [],
    this.selectedUnit,
    this.customPrice,
  });

  // السعر المستخدم (إما المعدل أو الأصلي)
  double get unitPrice =>
      customPrice ?? (selectedUnit?.sellPrice ?? product.price);

  // السعر الإجمالي
  double get totalPrice => unitPrice * quantity;

  String get unitName => selectedUnit?.unitName ?? product.baseUnit;

  // تعيين سعر معدل
  void setCustomPrice(double? price) {
    customPrice = price;
  }

  // التحقق إذا كان السعر معدلاً
  bool get isPriceModified => customPrice != null;

  // السعر الأصلي
  double get originalPrice => selectedUnit?.sellPrice ?? product.price;
}
