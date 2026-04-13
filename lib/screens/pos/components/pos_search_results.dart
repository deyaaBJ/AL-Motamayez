import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/models/product_unit.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';

class PosSearchResults extends StatelessWidget {
  final List<dynamic> results;
  final VoidCallback onClear;
  final Function(Product) onProductTap;
  final Function(ProductUnit, Product) onUnitTap;

  const PosSearchResults({
    super.key,
    required this.results,
    required this.onClear,
    required this.onProductTap,
    required this.onUnitTap,
  });

  String _getCurrency(BuildContext context) =>
      Provider.of<SettingsProvider>(context, listen: false).currencyName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  results.isNotEmpty && results.first is ProductUnit
                      ? Icons.inventory_2
                      : Icons.search,
                  color: const Color(0xFF6A3093),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'نتائج البحث (${results.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A3093),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClear,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                results.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 32, color: Colors.grey),
                          SizedBox(height: 4),
                          Text(
                            'لا توجد نتائج',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (ctx, index) {
                        final item = results[index];
                        if (item is Product) {
                          return _ProductResultTile(
                            product: item,
                            currency: _getCurrency(ctx),
                            onTap: () => onProductTap(item),
                          );
                        } else if (item is ProductUnit) {
                          return FutureBuilder<Product?>(
                            future: Provider.of<ProductProvider>(
                              ctx,
                              listen: false,
                            ).getProductById(item.productId),
                            builder: (ctx2, snapshot) {
                              final product = snapshot.data;
                              if (product == null)
                                return const SizedBox.shrink();
                              return _UnitResultTile(
                                unit: item,
                                product: product,
                                currency: _getCurrency(ctx2),
                                onTap: () => onUnitTap(item, product),
                              );
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _ProductResultTile extends StatelessWidget {
  final Product product;
  final String currency;
  final VoidCallback onTap;

  const _ProductResultTile({
    required this.product,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.shopping_bag,
          color: Color(0xFF6A3093),
          size: 16,
        ),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'باركود: ${product.barcode}',
            style: const TextStyle(fontSize: 10),
          ),
          Text(
            'سعر: $currency${product.price.toStringAsFixed(2)} | مخزون: ${product.quantity}',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
      trailing:
          product.quantity > 0
              ? IconButton(
                icon: const Icon(
                  Icons.add_shopping_cart,
                  color: Colors.green,
                  size: 16,
                ),
                onPressed: onTap,
              )
              : const Text(
                'نفذ',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
      onTap: onTap,
    );
  }
}

class _UnitResultTile extends StatelessWidget {
  final ProductUnit unit;
  final Product product;
  final String currency;
  final VoidCallback onTap;

  const _UnitResultTile({
    required this.unit,
    required this.product,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.inventory_2,
          color: Color(0xFF2196F3),
          size: 16,
        ),
      ),
      title: Text(
        '${product.name} - ${unit.unitName}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'باركود الوحدة: ${unit.barcode ?? "لا يوجد"}',
            style: const TextStyle(fontSize: 10),
          ),
          Text(
            'سعر الوحدة: $currency${unit.effectivePrice.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
      trailing:
          product.quantity > 0
              ? IconButton(
                icon: const Icon(
                  Icons.add_shopping_cart,
                  color: Colors.blue,
                  size: 16,
                ),
                onPressed: onTap,
              )
              : const Text(
                'نفذ',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
      onTap: onTap,
    );
  }
}
