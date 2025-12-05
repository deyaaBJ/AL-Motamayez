import 'package:flutter/material.dart';
import 'package:shopmate/helpers/helpers.dart';
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
    showAppToast(context, 'يرجى ملء جميع الحقول المطلوبة', ToastType.error);

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

    showAppToast(
      context,
      '$action المنتج "${product.name}" بنجاح',
      ToastType.success,
    );
  } catch (e) {
    onEnd();

    showAppToast(context, 'حدث خطأ أثناء حفظ المنتج: $e', ToastType.error);
  }
}
