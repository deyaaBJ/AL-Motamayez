import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/models/product.dart';
import 'package:shopmate/providers/settings_provider.dart';
import 'package:shopmate/providers/product_provider.dart';
import 'package:shopmate/screens/add_product_screen.dart';

class ProductItem extends StatelessWidget {
  final Product product;
  final ProductProvider provider;
  final VoidCallback onUpdate;

  const ProductItem({
    Key? key,
    required this.product,
    required this.provider,
    required this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // صورة المنتج
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE1D4F7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.shopping_bag, color: Color(0xFF6A3093)),
            ),
            const SizedBox(width: 12),

            // معلومات المنتج
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    product.barcode,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            // السعر
            Expanded(
              flex: 2,
              child: Text(
                '${settings.currencyName} ${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5FBF),
                ),
              ),
            ),

            // سعر التكلفة
            Expanded(
              flex: 2,
              child: Text(
                '${settings.currencyName} ${product.costPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5FBF),
                ),
              ),
            ),

            // الكمية
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getQuantityColor(context, product.quantity),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  product.quantity.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        product.quantity == 0
                            ? Colors.white
                            : const Color(0xFF6A3093),
                  ),
                ),
              ),
            ),

            // الحالة
            Expanded(
              flex: 1,
              child: Icon(
                product.quantity > 0 ? Icons.check_circle : Icons.cancel,
                color: product.quantity > 0 ? Colors.green : Colors.red,
                size: 20,
              ),
            ),

            // الإجراءات
            Expanded(
              flex: 1,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) => _onProductAction(context, value),
                itemBuilder:
                    (BuildContext context) => [
                      const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      const PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getQuantityColor(BuildContext context, double quantity) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final threshold = settingsProvider.lowStockThreshold;

    if (quantity == 0) return Colors.red;
    if (quantity <= threshold) return Colors.orange[100]!;
    return Colors.green[100]!;
  }

  void _onProductAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddProductScreen(productId: product.id),
          ),
        ).then((result) {
          if (result == true) onUpdate();
        });
        break;
      case 'delete':
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('حذف المنتج'),
                content: Text('هل أنت متأكد من حذف "${product.name}"؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('حذف'),
                    onPressed: () async {
                      await provider.deleteProduct(product.id.toString());
                      onUpdate();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم حذف ${product.name} بنجاح')),
                      );
                    },
                  ),
                ],
              ),
        );
        break;
    }
  }
}
