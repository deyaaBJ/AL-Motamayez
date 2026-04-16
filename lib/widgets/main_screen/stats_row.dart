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
    return Row(
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
    );
  }
}
