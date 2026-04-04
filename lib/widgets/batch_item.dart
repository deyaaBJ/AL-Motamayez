// lib/widgets/batch_item.dart

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
              flex: 1,
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
            // ✅ المورد (جديد)
            Expanded(
              flex: 1,
              child: Text(
                batch.supplierName ?? 'غير محدد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // الكمية المتبقية
            Expanded(
              flex: 1,
              child: Text(
                batch.remainingQuantity.toStringAsFixed(2),
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
                batch.costPrice.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),

            // تاريخ الانتهاء
            Expanded(
              flex: 1,
              child: Text(
                batch.hasExpiry
                    ? dateFormat.format(DateTime.parse(batch.expiryDate))
                    : 'بدون صلاحية',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: batch.hasExpiry ? _getStatusColor() : Colors.grey,
                ),
              ),
            ),

            // الأيام المتبقية
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      batch.hasExpiry
                          ? _getDaysRemainingColor()
                          : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  batch.hasExpiry
                      ? (batch.daysRemaining >= 0
                          ? '${batch.daysRemaining}'
                          : 'انتهى')
                      : '---',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color:
                        batch.hasExpiry ? Colors.white : Colors.grey.shade700,
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
                  color:
                      batch.hasExpiry
                          ? _getStatusBackgroundColor()
                          : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  batch.status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color:
                        batch.hasExpiry
                            ? _getStatusColor()
                            : Colors.grey.shade600,
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
                        value: 'return_to_supplier',
                        child: Row(
                          children: [
                            Icon(
                              Icons.assignment_return,
                              color: Colors.blue,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'إرجاع للمورد',
                              style: TextStyle(fontSize: 12),
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

  Color _getStatusBackgroundColor() {
    // ignore: deprecated_member_use
    if (batch.daysRemaining < 0) return Colors.red.withOpacity(0.1);
    // ignore: deprecated_member_use
    if (batch.daysRemaining <= 30) return Colors.orange.withOpacity(0.1);
    // ignore: deprecated_member_use
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
      case 'product_details':
        _viewProductDetails(context);
        break;
      case 'dispose':
        await _disposeBatch(context);
        break;
      case 'return_to_supplier':
        await _returnToSupplier(context);
        break;
    }
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
    if (batch.remainingQuantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هذه الدفعة فارغة بالفعل!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final disposedQuantity = await _showDisposeDialog(context);
    if (disposedQuantity == null || disposedQuantity <= 0) return;

    if (disposedQuantity > batch.remainingQuantity) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الكمية المدخلة أكبر من الكمية المتبقية!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog(
      // ignore: use_build_context_synchronously
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
        await provider.disposeBatch(batch.id!, disposedQuantity);
        onUpdate();
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم التخلص من $disposedQuantity من الدفعة'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // ignore: use_build_context_synchronously
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

  Future<void> _returnToSupplier(BuildContext context) async {
    if (batch.remainingQuantity == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('هذه الدفعة فارغة!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final returnQuantity = await _showReturnDialog(context);
    if (returnQuantity == null || returnQuantity <= 0) return;

    if (returnQuantity > batch.remainingQuantity) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الكمية المدخلة أكبر من الكمية المتبقية!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final returnAmount = returnQuantity * batch.costPrice;

    final confirmed = await showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('إرجاع للمورد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الكمية المُرجَعة: ${returnQuantity.toStringAsFixed(2)}'),
                SizedBox(height: 6),
                Text(
                  'المبلغ المُسترجَع: ${returnAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'سيبقى في الدفعة: ${(batch.remainingQuantity - returnQuantity).toStringAsFixed(2)}',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد الإرجاع'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await provider.returnBatchToSupplier(batch.id!, returnQuantity);
        onUpdate();

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرجاع $returnQuantity وحدة'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<double?> _showReturnDialog(BuildContext context) {
    final controller = TextEditingController(
      text: batch.remainingQuantity.toStringAsFixed(2),
    );

    return showDialog<double>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('كمية الإرجاع'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('أدخل الكمية التي تريد إرجاعها للمورد:'),
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
                SizedBox(height: 8),
                Text(
                  'سعر الشراء: ${batch.costPrice.toStringAsFixed(2)} لكل وحدة',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
}
