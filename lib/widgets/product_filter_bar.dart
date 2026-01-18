import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/models/productFilter.dart';
import 'package:motamayez/providers/settings_provider.dart';
import '../models/product.dart';

// ==================== دالة الفلترة ====================
bool matchesFilter(
  BuildContext context,
  Product product,
  ProductFilter currentFilter,
) {
  final settingsProvider = Provider.of<SettingsProvider>(
    context,
    listen: false,
  );
  final threshold = settingsProvider.lowStockThreshold;

  switch (currentFilter) {
    case ProductFilter.all:
      return true;

    case ProductFilter.available:
      return product.quantity > 0;

    case ProductFilter.unavailable:
      return product.quantity == 0;

    case ProductFilter.lowStock:
      return product.quantity > 0 && product.quantity <= threshold;
  }
}

// ==================== Filter Bar ====================
class ProductFilterBar extends StatelessWidget {
  final ProductFilter currentFilter;
  final Function(ProductFilter) onFilterChanged;

  const ProductFilterBar({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('الكــل', ProductFilter.all),
            const SizedBox(width: 8),
            _buildFilterChip('🔄 متوفر', ProductFilter.available),
            const SizedBox(width: 8),
            _buildFilterChip('⏸️ غير متوفر', ProductFilter.unavailable),
            const SizedBox(width: 8),
            _buildFilterChip('📊 منخفض', ProductFilter.lowStock),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ProductFilter filter) {
    final isSelected = currentFilter == filter;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF6A3093),
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF8B5FBF),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF8B5FBF) : const Color(0xFFE1D4F7),
      ),
      onSelected: (_) => onFilterChanged(filter),
    );
  }
}
