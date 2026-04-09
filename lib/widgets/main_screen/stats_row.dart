import 'package:flutter/material.dart';
import 'package:motamayez/widgets/main_screen/stat_card.dart';

class StatsRow extends StatelessWidget {
  final String salesValue;
  final String productsValue;
  final String lowStockValue;
  final bool compact;

  const StatsRow({
    super.key,
    required this.salesValue,
    required this.productsValue,
    required this.lowStockValue,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                // ignore: deprecated_member_use
                const Color(0xFF7C3AED).withOpacity(0.12),
                // ignore: deprecated_member_use
                const Color(0xFF6D28D9).withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              // ignore: deprecated_member_use
              color: const Color(0xFF7C3AED).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Color(0xFF7C3AED),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'ملخص الإحصائيات',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4C1D95),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'المبيعات',
                value: salesValue,
                subtitle: 'اليوم',
                icon: Icons.trending_up,
                color: const Color(0xFF7C3AED),
                compact: compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'المنتجات',
                value: productsValue,
                subtitle: 'الإجمالي',
                icon: Icons.inventory_2,
                color: const Color(0xFF6D28D9),
                compact: compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'مخزون منخفض',
                value: lowStockValue,
                subtitle: 'حاليًا',
                icon: Icons.warning_amber,
                color: const Color(0xFFF59E0B),
                compact: compact,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
