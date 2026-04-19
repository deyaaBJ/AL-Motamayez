String? validateName(String? value) {
  if (value == null || value.isEmpty) return 'يرجى إدخال اسم المنتج';
  return null;
}

String? validatePrice(String? value) {
  if (value == null || value.isEmpty) return 'يرجى إدخال السعر';
  if (double.tryParse(value) == null) return 'يرجى إدخال سعر صحيح';
  return null;
}

String? validateQuantity(String? value) {
  if (value == null || value.isEmpty) return 'يرجى إدخال الكمية';
  final qty = double.tryParse(value);
  if (qty == null) return 'يرجى إدخال كمية صحيحة';
  if (qty < 0) return 'الكمية لا يمكن أن تكون سالبة';
  return null;
}

String? validateUnitFactor(String? value) {
  if (value == null || value.isEmpty) return 'يرجى إدخال معامل التحويل';
  final factor = double.tryParse(value.trim());
  if (factor == null || factor <= 0) {
    return 'أدخل رقمًا صحيحًا أو عشريًا أكبر من صفر';
  }
  return null;
}
