import 'package:flutter/material.dart';
import '../controllers/unit_controller.dart';
import 'unit_form.dart';

class UnitsSection extends StatelessWidget {
  final bool showUnitsSection;
  final List<UnitController> unitControllers;
  final List<int> unitIds;
  final VoidCallback onToggleShow;
  final VoidCallback onAddUnit;
  final void Function(int) onRemoveUnit;
  final double totalQuantity;
  final String baseUnit;

  const UnitsSection({
    super.key,
    required this.showUnitsSection,
    required this.unitControllers,
    required this.unitIds,
    required this.onToggleShow,
    required this.onAddUnit,
    required this.onRemoveUnit,
    required this.totalQuantity,
    required this.baseUnit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: Color(0xFF6A3093)),
              const SizedBox(width: 8),
              const Text(
                'إدارة الوحدات الإضافية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Switch(
                value: showUnitsSection,
                activeThumbColor: const Color(0xFF6A3093),
                onChanged: (value) {
                  onToggleShow();
                  if (value && unitControllers.isEmpty) onAddUnit();
                },
              ),
            ],
          ),
        ),
        if (showUnitsSection) ...[
          const SizedBox(height: 16),
          if (unitControllers.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'لا توجد وحدات مضافة. اضغط على زر "إضافة وحدة" لبدء إدارة الوحدات.',
                      style: TextStyle(color: Colors.amber),
                    ),
                  ),
                ],
              ),
            )
          else
            ...unitControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return UnitForm(
                index: index,
                controller: controller,
                isExisting: unitIds.length > index && unitIds[index] != -1,
                onRemove: () => onRemoveUnit(index),
                totalQuantity: totalQuantity,
                baseUnit: baseUnit,
              );
            }).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, color: Color(0xFF6A3093)),
              label: const Text(
                'إضافة وحدة جديدة',
                style: TextStyle(color: Color(0xFF6A3093)),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFF6A3093)),
              ),
              onPressed: onAddUnit,
            ),
          ),
        ],
      ],
    );
  }
}
