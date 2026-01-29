// lib/widgets/batch_item.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:motamayez/models/batch.dart';
import 'package:motamayez/providers/batch_provider.dart';
import 'package:motamayez/screens/product_details_screen.dart';

class BatchItem extends StatelessWidget {
  final Batch batch;
  final BatchProvider provider;
  final VoidCallback onUpdate;

  const BatchItem({
    super.key,
    required this.batch,
    required this.provider,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // اسم المنتج
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch.productName ?? 'غير معروف',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: _getStatusColor(),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (batch.productBarcode != null &&
                      batch.productBarcode!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        batch.productBarcode!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            // الكمية المتبقية
            Expanded(
              flex: 1,
              child: Text(
                '${batch.remainingQuantity.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color:
                      batch.remainingQuantity == 0 ? Colors.red : Colors.green,
                ),
              ),
            ),

            // سعر الشراء
            Expanded(
              flex: 1,
              child: Text(
                '${batch.costPrice.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),

            // تاريخ الإنتاج
            Expanded(
              flex: 1,
              child: Text(
                batch.productionDate != null
                    ? dateFormat.format(DateTime.parse(batch.productionDate!))
                    : '--/--/--',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),

            // تاريخ الانتهاء
            Expanded(
              flex: 1,
              child: Text(
                dateFormat.format(DateTime.parse(batch.expiryDate)),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: _getStatusColor(),
                ),
              ),
            ),

            // الأيام المتبقية
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: _getDaysRemainingColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  batch.daysRemaining >= 0 ? '${batch.daysRemaining}' : 'انتهى',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // الحالة
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: _getStatusBackgroundColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: _getStatusColor(),
                  ),
                ),
              ),
            ),

            // الإجراءات
            Expanded(
              flex: 1,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 16),
                onSelected: (value) => _onBatchAction(context, value),
                itemBuilder:
                    (BuildContext context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue, size: 14),
                            SizedBox(width: 6),
                            Text('تعديل', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'product_details',
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.purple, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'تفاصيل المنتج',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // خيار جديد: التخلص من الدفعة
                      PopupMenuItem(
                        value: 'dispose',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_sweep,
                              color: Colors.orange,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'تخلص من الدفعة',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_forever,
                              color: Colors.red,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'حذف نهائي',
                              style: TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ],
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

  Color _getStatusColor() {
    if (batch.daysRemaining < 0) return Colors.red;
    if (batch.daysRemaining <= 30) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText() {
    if (batch.daysRemaining < 0) return 'منتهي';
    if (batch.daysRemaining <= 30) return 'قريب';
    return 'جيد';
  }

  Color _getStatusBackgroundColor() {
    if (batch.daysRemaining < 0) return Colors.red.withOpacity(0.1);
    if (batch.daysRemaining <= 30) return Colors.orange.withOpacity(0.1);
    return Colors.green.withOpacity(0.1);
  }

  Color _getDaysRemainingColor() {
    if (batch.daysRemaining < 0) return Colors.red;
    if (batch.daysRemaining <= 7) return Colors.red;
    if (batch.daysRemaining <= 30) return Colors.orange;
    return Colors.green;
  }

  void _onBatchAction(BuildContext context, String action) async {
    switch (action) {
      case 'edit':
        await _editBatch(context);
        break;
      case 'product_details':
        _viewProductDetails(context);
        break;
      case 'dispose':
        await _disposeBatch(context);
        break;
      case 'delete':
        await _deleteBatch(context);
        break;
    }
  }

  Future<void> _editBatch(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ميزة التعديل قيد التطوير'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _viewProductDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(productId: batch.productId),
      ),
    );
  }

  Future<void> _disposeBatch(BuildContext context) async {
    // تحقق إذا كانت الدفعة فارغة أصلاً
    if (batch.remainingQuantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هذه الدفعة فارغة بالفعل!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // طلب الكمية للتخلص منها
    final disposedQuantity = await _showDisposeDialog(context);
    if (disposedQuantity == null || disposedQuantity <= 0) return;

    if (disposedQuantity > batch.remainingQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الكمية المدخلة أكبر من الكمية المتبقية!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تخلص من الدفعة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('هل تريد التخلص من $disposedQuantity من هذه الدفعة؟'),
                SizedBox(height: 8),
                Text(
                  'سيبقى في الدفعة: ${(batch.remainingQuantity - disposedQuantity).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد التخلص'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // استخدم دالة provider الجديدة بدلاً من _updateRemainingQuantity
        await provider.disposeBatch(batch.id!, disposedQuantity);
        onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم التخلص من $disposedQuantity من الدفعة'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التخلص: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<double?> _showDisposeDialog(BuildContext context) {
    final controller = TextEditingController(
      text: batch.remainingQuantity.toStringAsFixed(2),
    );

    return showDialog<double>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('كمية التخلص'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('أدخل الكمية التي تريد التخلص منها:'),
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'الكمية',
                    suffixText:
                        'المتبقي: ${batch.remainingQuantity.toStringAsFixed(2)}',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  final value = double.tryParse(controller.text);
                  Navigator.pop(context, value);
                },
                child: const Text('متابعة'),
              ),
            ],
          ),
    );
  }

  // حذف دالة _updateRemainingQuantity القديمة كلياً
  // لأنها موجودة الآن في provider

  Future<void> _deleteBatch(BuildContext context) async {
    final confirmed = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('حذف نهائي للدفعة'),
            content: const Text(
              '⚠️ هل أنت متأكد من الحذف النهائي للدفعة؟ هذا الإجراء لا يمكن التراجع عنه.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف نهائي'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await provider.deleteBatch(batch.id!);
        onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحذف النهائي للدفعة'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحذف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
