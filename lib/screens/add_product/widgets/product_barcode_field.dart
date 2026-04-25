import 'package:flutter/material.dart';
import '../../../../widgets/text_field.dart';

class ProductBarcodeField extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const ProductBarcodeField({
    super.key,
    required this.controller,
    required this.readOnly,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: 'الباركود',
      prefixIcon: Icons.qr_code,
      onChanged: onChanged,
    );
  }
}
