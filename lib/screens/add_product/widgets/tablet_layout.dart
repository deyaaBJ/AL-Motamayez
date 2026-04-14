import 'package:flutter/material.dart';
import 'qr_scanner_card.dart';
import 'product_info_section.dart';
import 'save_button.dart';
import '../../../../widgets/qr_scan_section.dart';

class TabletLayout extends StatelessWidget {
  final TextEditingController qrController;
  final Function(String) onQRCodeChanged;
  final GlobalKey<FormState> formKey;
  final Map<String, dynamic> formData;

  const TabletLayout({
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
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'مسح الباركود',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  QRScanSection(
                    qrController: qrController,
                    onQRCodeChanged: onQRCodeChanged,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 20), // مسافة إضافية في الأسفل
        ],
      ),
    );
  }
}
