import 'package:flutter/material.dart';

class QRScanSection extends StatelessWidget {
  final TextEditingController qrController;
  final Function(String) onQRCodeChanged;

  const QRScanSection({
    super.key,
    required this.qrController,
    required this.onQRCodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B5FBF), Color(0xFF6A3093)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'مسح QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qrController,
              decoration: InputDecoration(
                hintText: 'أدخل QR Code أو انقر لمسح',
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: onQRCodeChanged,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
