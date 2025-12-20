// widgets/quick_payment_dialog.dart - النسخة المحسنة
import 'package:flutter/material.dart';
import 'package:shopmate/models/customer.dart';

enum PaymentMode {
  payment, // تسديد دفعة (العميل يدفع للمتجر)
  withdrawal, // صرف رصيد (المتجر يدفع للعميل)
}

class QuickPaymentDialog {
  // دالة لفتح نافذة المبلغ المخصص لتسديد دفعة
  static void showPayment({
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
    _showAmountDialog(
      context: context,
      customer: customer,
      currentBalance: currentDebt,
      mode: PaymentMode.payment,
      onConfirm: onPayment,
    );
  }

  // دالة لفتح نافذة المبلغ المخصص لصرف رصيد
  static void showWithdrawal({
    required BuildContext context,
    required Customer customer,
    required double currentBalance,
    required Future<void> Function(
      Customer customer,
      double amount,
      String? note,
    )
    onWithdrawal,
  }) {
    _showAmountDialog(
      context: context,
      customer: customer,
      currentBalance: currentBalance,
      mode: PaymentMode.withdrawal,
      onConfirm: onWithdrawal,
    );
  }

  // الدالة الرئيسية لعرض نافذة إدخال المبلغ
  static void _showAmountDialog({
    required BuildContext context,
    required Customer customer,
    required double currentBalance,
    required PaymentMode mode,
    required Future<void> Function(
      Customer customer,
      double amount,
      String? note,
    )
    onConfirm,
  }) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
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

              // التحقق من الشروط بناءً على نوع العملية
              if (mode == PaymentMode.payment) {
                // في حالة تسديد دفعة: يجب ألا يتجاوز المبلغ الدين الحالي
                if (currentBalance <= 0) {
                  setState(() {
                    errorMessage = 'لا يوجد دين للعميل';
                    showError = true;
                  });
                  return;
                }

                if (amount > currentBalance) {
                  setState(() {
                    errorMessage =
                        '⚠️ المبلغ (${amount.toStringAsFixed(2)}) أكبر من الدين الحالي!\n'
                        'الدين الحالي: ${currentBalance.toStringAsFixed(2)} دينار\n'
                        'الفرق: ${(amount - currentBalance).toStringAsFixed(2)} دينار';
                    showError = true;
                  });
                  return;
                }
              } else if (mode == PaymentMode.withdrawal) {
                // في حالة صرف رصيد: يمكن سحب أي مبلغ (لا توجد حدود)
                // يمكنك إضافة شروط هنا إذا لزم الأمر
              }

              setState(() {
                errorMessage = null;
                showError = false;
              });
            }

            // تحديد النصوص بناءً على نوع العملية
            final titleText =
                mode == PaymentMode.payment ? 'تسديد دفعة' : 'صرف رصيد';
            final buttonText = mode == PaymentMode.payment ? 'تسديد' : 'صرف';
            final iconColor =
                mode == PaymentMode.payment ? Colors.green : Colors.blue;
            final buttonColor =
                mode == PaymentMode.payment ? Colors.green : Colors.blue;
            final hintText =
                mode == PaymentMode.payment
                    ? 'أدخل مبلغ التسديد'
                    : 'أدخل مبلغ الصرف';
            final labelText =
                mode == PaymentMode.payment
                    ? 'مبلغ التسديد (دينار)'
                    : 'مبلغ الصرف (دينار)';

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
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      mode == PaymentMode.payment ? Icons.payment : Icons.money,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
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
                        hintText: hintText,
                        labelText: labelText,
                        prefixIcon: Icon(Icons.money, color: iconColor),
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
                          borderSide: BorderSide(color: iconColor, width: 2),
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
                        prefixIcon: const Icon(Icons.note, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.grey,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    // عرض الرصيد الحالي
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            mode == PaymentMode.payment
                                ? 'الدين الحالي:'
                                : 'الرصيد الحالي:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${currentBalance.toStringAsFixed(2)} دينار',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  mode == PaymentMode.payment
                                      ? Colors.red
                                      : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // رسالة التحذير إذا كان هناك خطأ
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

                            if (amount == null || amount <= 0) {
                              return;
                            }

                            // التحقق الإضافي للتأكد
                            if (mode == PaymentMode.payment &&
                                (currentBalance <= 0 ||
                                    amount > currentBalance)) {
                              return;
                            }

                            setState(() => isProcessing = true);

                            try {
                              await onConfirm(
                                customer,
                                amount,
                                noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                              );

                              // إغلاق الديلوج
                              Navigator.pop(context);

                              // عرض رسالة النجاح
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    mode == PaymentMode.payment
                                        ? 'تم تسديد ${amount.toStringAsFixed(2)} دينار بنجاح'
                                        : 'تم صرف ${amount.toStringAsFixed(2)} دينار بنجاح',
                                  ),
                                  backgroundColor: buttonColor,
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
                    backgroundColor: buttonColor,
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
                          : Text(buttonText),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
