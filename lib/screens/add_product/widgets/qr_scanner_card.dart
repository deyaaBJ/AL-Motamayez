import 'package:flutter/material.dart';
import '../../../../widgets/qr_scan_section.dart';

class QrScannerCard extends StatelessWidget {
  final TextEditingController qrController;
  final Function(String) onQRCodeChanged;

  const QrScannerCard({
    super.key,
    required this.qrController,
    required this.onQRCodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'مسح الباركود',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            QRScanSection(
              qrController: qrController,
              onQRCodeChanged: onQRCodeChanged,
            ),
          ],
        ),
      ),
    );
  }
}
