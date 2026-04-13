import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../widgets/text_field.dart';

class QuantitySection extends StatelessWidget {
  final bool isNewProduct;
  final double? existingQuantity;
  final TextEditingController quantityController;
  final String selectedUnit;

  const QuantitySection({
    super.key,
    required this.isNewProduct,
    this.existingQuantity,
    required this.quantityController,
    required this.selectedUnit,
  });

  @override
  Widget build(BuildContext context) {
    if (!isNewProduct && existingQuantity != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الكمية الحالية: ${existingQuantity!.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: quantityController,
            label:
                selectedUnit == 'piece'
                    ? 'الكمية المراد إضافتها (قطعة)'
                    : 'الكمية المراد إضافتها (كيلو)',
            prefixIcon: Icons.add,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'يرجى إدخال الكمية';
              final qty = double.tryParse(value);
              if (qty == null) return 'يرجى إدخال كمية صحيحة';
              if (qty < 0) return 'الكمية لا يمكن أن تكون سالبة';
              return null;
            },
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
          ),
        ],
      );
    } else {
      return CustomTextField(
        controller: quantityController,
        label: selectedUnit == 'piece' ? 'الكمية (قطعة)' : 'الكمية (كيلو)',
        prefixIcon: Icons.shopping_cart,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          if (value == null || value.isEmpty) return 'يرجى إدخال الكمية';
          final qty = double.tryParse(value);
          if (qty == null) return 'يرجى إدخال كمية صحيحة';
          if (qty < 0) return 'الكمية لا يمكن أن تكون سالبة';
          return null;
        },
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
      );
    }
  }
}
