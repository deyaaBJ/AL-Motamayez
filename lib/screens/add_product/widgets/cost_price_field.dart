import 'package:flutter/material.dart';
import '../../../../widgets/text_field.dart';

class CostPriceField extends StatelessWidget {
  final TextEditingController controller;
  const CostPriceField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: 'متوسط تكلفة محسوب تلقائيًا',
      prefixIcon: Icons.money,
      readOnly: true,
    );
  }
}
