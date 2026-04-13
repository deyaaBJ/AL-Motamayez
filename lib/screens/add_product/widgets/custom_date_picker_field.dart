import 'package:flutter/material.dart';
import '../helpers/date_helper.dart';

class CustomDatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const CustomDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Color(0xFF6A3093)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null ? label : '$label: ${formatDate(value!)}',
                style: TextStyle(
                  color: value == null ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
