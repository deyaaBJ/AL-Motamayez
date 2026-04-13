import 'package:flutter/material.dart';
import '../../../../widgets/text_field.dart';
import '../controllers/unit_controller.dart';
import 'unit_offer_section.dart';

class UnitForm extends StatelessWidget {
  final int index;
  final UnitController controller;
  final bool isExisting;
  final VoidCallback onRemove;

  const UnitForm({
    super.key,
    required this.index,
    required this.controller,
    required this.isExisting,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'الوحدة ${index + 1}${isExisting ? ' (موجودة)' : ' (جديدة)'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A3093),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: controller.unitNameController,
            label: 'اسم الوحدة (مثال: كرتونة، علبة، باكيت)',
            prefixIcon: Icons.category,
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'يرجى إدخال اسم الوحدة';
              return null;
            },
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: controller.containQtyController,
            label: 'كم وحدة مرجعية تحتوي هذه الوحدة',
            prefixIcon: Icons.format_list_numbered,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'يرجى إدخال معامل التحويل';
              final factor = double.tryParse(value.trim());
              if (factor == null || factor <= 0)
                return 'أدخل رقمًا صحيحًا أو عشريًا أكبر من صفر';
              return null;
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'مثال: إذا كانت الوحدة المرجعية حبة: حبة = 1، باكيت = 6، كرتونة = 24',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: controller.sellPriceController,
            label: 'سعر بيع هذه الوحدة',
            prefixIcon: Icons.attach_money,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'يرجى إدخال السعر';
              if (double.tryParse(value) == null) return 'يرجى إدخال سعر صحيح';
              return null;
            },
          ),
          const SizedBox(height: 12),
          UnitOfferSection(controller: controller),
          const SizedBox(height: 12),
          CustomTextField(
            controller: controller.barcodeController,
            label: 'باركود الوحدة (اختياري)',
            prefixIcon: Icons.qr_code,
          ),
        ],
      ),
    );
  }
}
