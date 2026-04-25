import 'package:flutter/material.dart';
import 'product_info_section.dart';
import 'save_button.dart';

class TabletLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final Map<String, dynamic> formData;

  const TabletLayout({
    super.key,
    required this.formKey,
    required this.formData,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ProductInfoSection(
            formKey: formKey,
            formData: formData,
            screenType: 'tablet',
          ),
          const SizedBox(height: 30),
          SaveButton(
            isLoading: formData['isLoading'],
            isNewProduct: formData['isNewProduct'],
            onPressed: formData['onSave'],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
