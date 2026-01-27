import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/screens/add_product_screen.dart';

class ProductItem extends StatelessWidget {
  final Product product;
  final ProductProvider provider;
  final VoidCallback onUpdate;

  const ProductItem({
    super.key,
    required this.product,
    required this.provider,
    required this.onUpdate,
  });

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
                    product.barcode ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  // ⬅️ جديد: عرض حالة التنشيط
                  if (!product.active)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red, width: 0.5),
                      ),
                      child: Text(
                        'غير نشط',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  // ⬅️ جديد: عرض إذا كان له صلاحية
                  if (product.hasExpiryDate)
                    Container(
                      margin: EdgeInsets.only(top: 2),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue, width: 0.5),
                      ),
                      child: Text(
                        'له صلاحية',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
              child: Column(
                children: [
                  Icon(
                    product.quantity > 0 ? Icons.check_circle : Icons.cancel,
                    color: product.quantity > 0 ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  SizedBox(height: 4),
                  // ⬅️ جديد: مؤشر حالة التنشيط
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: product.active ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ],
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
                      PopupMenuItem(
                        value: 'toggle_active',
                        child: Text(product.active ? 'إلغاء التنشيط' : 'تفعيل'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'حذف نهائي',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
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
      case 'toggle_active':
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(product.active ? 'إلغاء التنشيط' : 'تفعيل المنتج'),
                content: Text(
                  product.active
                      ? 'هل أنت متأكد من إلغاء تنشيط "${product.name}"؟'
                      : 'هل تريد تفعيل المنتج "${product.name}"؟',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          product.active ? Colors.orange : Colors.green,
                    ),
                    child: Text(product.active ? 'إلغاء التنشيط' : 'تفعيل'),
                    onPressed: () async {
                      try {
                        await provider.toggleProductActive(product.id!);
                        onUpdate();
                        Navigator.pop(context);
                        showAppToast(
                          context,
                          product.active
                              ? 'تم إلغاء تنشيط ${product.name}'
                              : 'تم تفعيل ${product.name}',
                          ToastType.success,
                        );
                      } catch (e) {
                        Navigator.pop(context);
                        showAppToast(context, 'خطأ: $e', ToastType.error);
                      }
                    },
                  ),
                ],
              ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('حذف نهائي'),
                content: Text(
                  'هل أنت متأكد من الحذف النهائي للمنتج "${product.name}"؟\n\n⚠️ هذه العملية لا يمكن التراجع عنها!',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('حذف نهائي'),
                    onPressed: () async {
                      try {
                        await provider.deleteProduct(product.id.toString());
                        onUpdate();
                        Navigator.pop(context);
                        showAppToast(
                          context,
                          'تم حذف ${product.name} نهائياً',
                          ToastType.success,
                        );
                      } catch (e) {
                        Navigator.pop(context);
                        showAppToast(
                          context,
                          'خطأ في الحذف: $e',
                          ToastType.error,
                        );
                      }
                    },
                  ),
                ],
              ),
        );
        break;
    }
  }
}
