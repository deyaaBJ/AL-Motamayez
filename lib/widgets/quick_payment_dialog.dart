// widgets/quick_payment_dialog.dart - النسخة المصححة
import 'package:flutter/material.dart';
import 'package:shopmate/models/customer.dart';

class QuickPaymentDialog {
  // دالة لفتح نافذة المبلغ المخصص مباشرة
  static void show({
    required BuildContext context,
    required Customer customer,
    required double currentDebt,
    required Future<void> Function(
      Customer customer,
      double amount,
      String? note,
    )
    onPayment,
  }) {
    if (currentDebt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد دين للعميل'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _showCustomAmountDialog(context, customer, currentDebt, onPayment);
  }

  // دالة لعرض نافذة المبلغ المخصص
  static void _showCustomAmountDialog(
    BuildContext outerContext,
    Customer customer,
    double currentDebt,
    Future<void> Function(Customer customer, double amount, String? note)
    onPayment,
  ) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: outerContext,
      builder: (dialogContext) {
        String? errorMessage;
        bool showError = false;
        bool isProcessing = false;

        return StatefulBuilder(
          builder: (context, setState) {
            void validateAmount(String value) {
              if (value.isEmpty) {
                setState(() {
                  errorMessage = null;
                  showError = false;
                });
                return;
              }

              // السماح بالنقطة أو الفاصلة
              final normalizedValue = value.replaceAll(',', '.');
              final amount = double.tryParse(normalizedValue);

              if (amount == null) {
                setState(() {
                  errorMessage = 'يرجى إدخال رقم صحيح (مثال: 10.5 أو 10,5)';
                  showError = true;
                });
                return;
              }

              if (amount <= 0) {
                setState(() {
                  errorMessage = 'المبلغ يجب أن يكون أكبر من صفر';
                  showError = true;
                });
                return;
              }

              // التحقق من أن المبلغ لا يتجاوز الدين الحالي
              if (amount > currentDebt) {
                setState(() {
                  errorMessage =
                      '⚠️ المبلغ (${amount.toStringAsFixed(2)}) أكبر من الدين الحالي!\n'
                      'الدين الحالي: ${currentDebt.toStringAsFixed(2)} دينار\n'
                      'الفرق: ${(amount - currentDebt).toStringAsFixed(2)} دينار';
                  showError = true;
                });
                return;
              }

              setState(() {
                errorMessage = null;
                showError = false;
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.payment,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تسديد دفعة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          customer.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // حقل إدخال المبلغ
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'أدخل المبلغ',
                        labelText: 'المبلغ (دينار)',
                        prefixIcon: const Icon(
                          Icons.money,
                          color: Colors.green,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            amountController.clear();
                            setState(() {
                              errorMessage = null;
                              showError = false;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.green,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        validateAmount(value);
                      },
                    ),

                    const SizedBox(height: 16),

                    // حقل الملاحظة
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'ملاحظة (اختياري)',
                        labelText: 'ملاحظة',
                        prefixIcon: const Icon(Icons.note, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    // عرض الدين الحالي
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الدين الحالي:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${currentDebt.toStringAsFixed(2)} دينار',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // رسالة التحذير إذا كان المبلغ أكبر من الدين
                    if (showError && errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed:
                      (errorMessage != null ||
                              amountController.text.isEmpty ||
                              isProcessing)
                          ? null
                          : () async {
                            final normalizedValue = amountController.text
                                .replaceAll(',', '.');
                            final amount = double.tryParse(normalizedValue);

                            if (amount == null ||
                                amount <= 0 ||
                                amount > currentDebt) {
                              return;
                            }

                            setState(() => isProcessing = true);

                            try {
                              await onPayment(
                                customer,
                                amount,
                                noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                              );

                              // إغلاق الديلوج
                              Navigator.pop(context);

                              // عرض رسالة النجاح في الـ outerContext (الكونتكس الأصلي)
                              ScaffoldMessenger.of(outerContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم تسديد ${amount.toStringAsFixed(2)} دينار بنجاح',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              // في حالة خطأ، لا نغلق الديلوج ونعرض رسالة الخطأ
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('خطأ: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            } finally {
                              setState(() => isProcessing = false);
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey[400],
                  ),
                  child:
                      isProcessing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('تسديد'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
