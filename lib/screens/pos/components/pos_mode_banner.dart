import 'package:flutter/material.dart';

class PosModeBanner extends StatelessWidget {
  final int? saleId;
  const PosModeBanner({super.key, this.saleId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      // ignore: deprecated_member_use
      color: Colors.blueAccent.withOpacity(0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.edit, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(
            'وضع التعديل - الفاتورة #$saleId',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
