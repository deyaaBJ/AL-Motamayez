import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/settings_provider.dart';

class PosAddServiceDialog extends StatelessWidget {
  final Function(String name, double price) onAdd;
  const PosAddServiceDialog({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.design_services, color: Colors.blue),
          SizedBox(width: 8),
          Text('إضافة خدمة جديدة'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'اسم الخدمة',
              hintText: 'أدخل اسم الخدمة',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'المبلغ',
              hintText: '0.00',
              suffixText: settings.currencyName,
              border: const OutlineInputBorder(),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = nameController.text.trim();
            final priceText = priceController.text.trim();
            if (name.isEmpty) {
              _showError(context, 'الرجاء إدخال اسم الخدمة');
              return;
            }
            if (priceText.isEmpty) {
              _showError(context, 'الرجاء إدخال المبلغ');
              return;
            }
            final price = double.tryParse(priceText);
            if (price == null || price < 0) {
              _showError(context, 'الرجاء إدخال مبلغ صحيح');
              return;
            }
            onAdd(name, price);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
          ),
          child: const Text('إضافة', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
