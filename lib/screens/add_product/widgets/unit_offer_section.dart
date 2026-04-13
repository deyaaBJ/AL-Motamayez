import 'package:flutter/material.dart';
import '../../../../widgets/text_field.dart';
import '../controllers/unit_controller.dart';
import 'custom_date_picker_field.dart';
import '../helpers/date_helper.dart';

class UnitOfferSection extends StatefulWidget {
  final UnitController controller;
  const UnitOfferSection({super.key, required this.controller});

  @override
  State<UnitOfferSection> createState() => _UnitOfferSectionState();
}

class _UnitOfferSectionState extends State<UnitOfferSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              const Icon(Icons.local_offer_outlined, color: Colors.deepOrange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'عرض مؤقت لهذه الوحدة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: widget.controller.offerEnabled,
                activeThumbColor: Colors.deepOrange,
                onChanged: (value) {
                  setState(() {
                    widget.controller.offerEnabled = value;
                    if (value && widget.controller.offerStartDate == null) {
                      widget.controller.offerStartDate = today();
                    } else if (!value) {
                      widget.controller.clearOffer();
                    }
                  });
                },
              ),
            ],
          ),
          if (widget.controller.offerEnabled) ...[
            const SizedBox(height: 12),
            CustomTextField(
              controller: widget.controller.offerPriceController,
              label: 'سعر عرض الوحدة',
              prefixIcon: Icons.sell,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomDatePickerField(
                    label: 'من',
                    value: widget.controller.offerStartDate,
                    onTap: () async {
                      final picked = await pickDate(
                        context,
                        widget.controller.offerStartDate ?? today(),
                      );
                      if (picked != null) {
                        setState(() {
                          widget.controller.offerStartDate = picked;
                          widget.controller.offerEndDate ??= picked;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomDatePickerField(
                    label: 'إلى',
                    value: widget.controller.offerEndDate,
                    onTap: () async {
                      final picked = await pickDate(
                        context,
                        widget.controller.offerEndDate ??
                            widget.controller.offerStartDate ??
                            today(),
                      );
                      if (picked != null) {
                        setState(() {
                          widget.controller.offerEndDate = picked;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() => widget.controller.clearOffer());
              },
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
