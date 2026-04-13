import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../widgets/text_field.dart';

class LowStockThresholdSection extends StatelessWidget {
  final bool useCustomLowStockThreshold;
  final TextEditingController lowStockThresholdController;
  final ValueChanged<bool?> onCheckboxChanged;

  const LowStockThresholdSection({
    super.key,
    required this.useCustomLowStockThreshold,
    required this.lowStockThresholdController,
    required this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'إذا تركته فارغًا سيتم استخدام الإعداد العام',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Colors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'تخصيص حد أدنى لهذا المنتج',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Checkbox(
                  value: useCustomLowStockThreshold,
                  onChanged: onCheckboxChanged,
                ),
              ],
            ),
            Text(
              useCustomLowStockThreshold
                  ? 'سيتم استخدام هذا الحد بدل الإعداد العام لهذا المنتج فقط.'
                  : 'عند تعطيل هذا الخيار سيتم استخدام الحد الافتراضي من الإعدادات.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            if (useCustomLowStockThreshold) ...[
              const SizedBox(height: 12),
              CustomTextField(
                controller: lowStockThresholdController,
                label: 'الحد الأدنى للمخزون',
                prefixIcon: Icons.warning_amber_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (!useCustomLowStockThreshold) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال الحد الأدنى أو إلغاء التخصيص';
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed < 0) {
                    return 'أدخل رقمًا صحيحًا يساوي صفر أو أكبر';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'إذا تركته فارغًا سيتم استخدام الإعداد العام',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
