import 'package:flutter/material.dart';
import '../../../../widgets/text_field.dart';

class ProductNameField extends StatelessWidget {
  final TextEditingController controller;
  const ProductNameField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: 'اسم المنتج',
      prefixIcon: Icons.shopping_bag,
      validator: (value) {
        if (value == null || value.isEmpty) return 'يرجى إدخال اسم المنتج';
        return null;
      },
    );
  }
}
