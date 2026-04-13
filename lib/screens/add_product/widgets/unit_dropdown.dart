import 'package:flutter/material.dart';

class UnitDropdown extends StatelessWidget {
  final String selectedUnit;
  final ValueChanged<String?> onChanged;

  const UnitDropdown({
    super.key,
    required this.selectedUnit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedUnit,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6A3093)),
          items: const [
            DropdownMenuItem(value: 'piece', child: Text('قطعة')),
            DropdownMenuItem(value: 'kg', child: Text('كيلو')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
