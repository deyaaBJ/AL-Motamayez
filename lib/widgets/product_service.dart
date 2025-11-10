import 'package:flutter/material.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';

Future<void> saveProduct({
  required BuildContext context,
  required Product product,
  required bool isNewProduct,
  required VoidCallback onStart,
  required VoidCallback onEnd,
}) async {
  if (product.name.isEmpty ||
      product.price == 0.0 ||
      product.costPrice == 0.0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('يرجى ملء جميع الحقول المطلوبة'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  onStart(); // مثلاً لتغيير حالة _isLoading

  final provider = ProductProvider();
  try {
    if (isNewProduct) {
      await provider.addProduct(product);
    } else {
      await provider.updateProduct(product);
    }

    onEnd();

    final action = isNewProduct ? 'تمت إضافة' : 'تم تحديث';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action المنتج "${product.name}" بنجاح'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    onEnd();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('حدث خطأ أثناء حفظ المنتج: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
