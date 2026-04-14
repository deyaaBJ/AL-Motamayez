import 'package:flutter/material.dart';
import 'qr_scanner_card.dart';
import 'product_info_section.dart';
import 'save_button.dart';

class DesktopLayout extends StatelessWidget {
  final TextEditingController qrController;
  final Function(String) onQRCodeChanged;
  final GlobalKey<FormState> formKey;
  final Map<String, dynamic> formData;

  const DesktopLayout({
    super.key,
    required this.qrController,
    required this.onQRCodeChanged,
    required this.formKey,
    required this.formData,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // ✅ إضافة السكرول هنا
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: ProductInfoSection(
                  formKey: formKey,
                  formData: formData,
                  screenType: 'desktop',
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: QrScannerCard(
                  qrController: qrController,
                  onQRCodeChanged: onQRCodeChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SaveButton(
            isLoading: formData['isLoading'],
            isNewProduct: formData['isNewProduct'],
            onPressed: formData['onSave'],
          ),
          const SizedBox(height: 20), // مسافة إضافية في الأسفل
        ],
      ),
    );
  }
}
