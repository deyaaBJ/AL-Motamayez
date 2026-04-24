import 'package:flutter/material.dart';
import '../../../../widgets/text_field.dart';

class PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const PriceField({super.key, required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: label,
      prefixIcon: Icons.attach_money,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null;
        }
        if (double.tryParse(value) == null) {
          return 'يرجى إدخال سعر صحيح';
        }
        return null;
      },
    );
  }
}
