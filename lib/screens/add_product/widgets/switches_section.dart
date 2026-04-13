import 'package:flutter/material.dart';

class SwitchesSection extends StatelessWidget {
  final bool isProductActive;
  final bool hasExpiryDate;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onExpiryChanged;

  const SwitchesSection({
    super.key,
    required this.isProductActive,
    required this.hasExpiryDate,
    required this.onActiveChanged,
    required this.onExpiryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إعدادات المنتج',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A3093),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  isProductActive ? Icons.check_circle : Icons.cancel,
                  color: isProductActive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حالة المنتج',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        isProductActive
                            ? 'المنتج نشط وجاهز للبيع'
                            : 'المنتج معطل وغير متاح للبيع',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isProductActive,
                  activeThumbColor: Colors.green,
                  inactiveTrackColor: Colors.red[200],
                  inactiveThumbColor: Colors.red,
                  onChanged: onActiveChanged,
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade300),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  hasExpiryDate
                      ? Icons.calendar_today
                      : Icons.calendar_today_outlined,
                  color: hasExpiryDate ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تاريخ الصلاحية',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        hasExpiryDate
                            ? 'هذا المنتج يحتوي على تاريخ صلاحية'
                            : 'هذا المنتج لا يحتوي على تاريخ صلاحية',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: hasExpiryDate,
                  activeThumbColor: Colors.blue,
                  onChanged: onExpiryChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
