import 'package:flutter/material.dart';
import '../../../../widgets/text_field.dart';
import 'custom_date_picker_field.dart';
import '../helpers/date_helper.dart';

class OfferSection extends StatefulWidget {
  final bool offerEnabled;
  final TextEditingController offerPriceController;
  final DateTime? offerStartDate;
  final DateTime? offerEndDate;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final VoidCallback onClear;

  const OfferSection({
    super.key,
    required this.offerEnabled,
    required this.offerPriceController,
    required this.offerStartDate,
    required this.offerEndDate,
    required this.onEnabledChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onClear,
  });

  @override
  State<OfferSection> createState() => _OfferSectionState();
}

class _OfferSectionState extends State<OfferSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, color: Colors.deepOrange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'عرض مؤقت للسعر الأساسي',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: widget.offerEnabled,
                activeThumbColor: Colors.deepOrange,
                onChanged: (value) {
                  widget.onEnabledChanged(value);
                  if (value && widget.offerStartDate == null) {
                    widget.onStartDateChanged(today());
                  }
                },
              ),
            ],
          ),
          if (widget.offerEnabled) ...[
            const SizedBox(height: 12),
            CustomTextField(
              controller: widget.offerPriceController,
              label: 'سعر العرض',
              prefixIcon: Icons.price_change,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomDatePickerField(
                    label: 'تاريخ البداية',
                    value: widget.offerStartDate,
                    onTap: () async {
                      final picked = await pickDate(
                        context,
                        widget.offerStartDate ?? today(),
                      );
                      if (picked != null) {
                        widget.onStartDateChanged(picked);
                        if (widget.offerEndDate == null)
                          widget.onEndDateChanged(picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomDatePickerField(
                    label: 'تاريخ النهاية',
                    value: widget.offerEndDate,
                    onTap: () async {
                      final picked = await pickDate(
                        context,
                        widget.offerEndDate ?? widget.offerStartDate ?? today(),
                      );
                      if (picked != null) widget.onEndDateChanged(picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onClear,
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text(
                'إلغاء العرض',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
