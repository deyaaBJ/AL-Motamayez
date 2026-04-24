import 'package:flutter/material.dart';
import 'package:motamayez/models/cart_item.dart';
import 'package:motamayez/models/product_unit.dart';
import 'package:motamayez/widgets/cart_item_widget.dart';
import 'package:motamayez/widgets/table_header_widget.dart';

class PosCartTable extends StatelessWidget {
  final List<CartItem> cartItems;
  final Function(CartItem, double) onQuantityChange;
  final Function(CartItem, double) onSetQuantity;
  final Function(CartItem) onRemove;
  final Function(CartItem, ProductUnit?) onUnitChange;
  final Function(CartItem, double?) onPriceChange;

  const PosCartTable({
    super.key,
    required this.cartItems,
    required this.onQuantityChange,
    required this.onSetQuantity,
    required this.onRemove,
    required this.onUnitChange,
    required this.onPriceChange,
  });

  @override
  Widget build(BuildContext context) {
    if (cartItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'لا توجد عناصر في السلة',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const TableHeaderWidget(),
            ...cartItems.asMap().entries.map(
              (entry) => CartItemWidget(
                key: ValueKey(
                  'cart_item_${entry.key}_${entry.value.product?.barcode}',
                ),
                item: entry.value,
                onQuantityChange: onQuantityChange,
                onSetQuantity: onSetQuantity,
                onRemove: onRemove,
                onUnitChange: onUnitChange,
                onPriceChange: onPriceChange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
