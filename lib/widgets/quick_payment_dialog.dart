// widgets/quick_payment_dialog.dart - بدون تكرار
import 'package:flutter/material.dart';
import 'package:shopmate/models/customer.dart';

class QuickPaymentDialog extends StatelessWidget {
  final Customer customer;
  final double currentDebt;
  final Function(Customer customer, double amount) onPayment;

  const QuickPaymentDialog({
    Key? key,
    required this.customer,
    required this.currentDebt,
    required this.onPayment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // العنوان
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'دفعة سريعة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          // معلومات العميل والدين
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: currentDebt > 0 ? Colors.red[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A3093).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      customer.name.substring(0, 1),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A3093),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'الدين الحالي: ${currentDebt.toStringAsFixed(2)} دينار',
                        style: TextStyle(
                          fontSize: 12,
                          color: currentDebt > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // التحذير إذا كان الدين صفر
          if (currentDebt <= 0)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا يوجد دين للعميل',
                      style: TextStyle(fontSize: 14, color: Colors.green[700]),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      currentDebt > 0
                          ? () => _showCustomAmountDialog(context)
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'تسديد دفعة',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showCustomAmountDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();
    String? errorMessage;
    bool showError = false;

    showDialog(
      context: context,
      builder: (context) {
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
              title: const Text('مبلغ مخصص'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'أدخل المبلغ',
                        prefixIcon: const Icon(Icons.money),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
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
                      ),
                      onChanged: (value) {
                        validateAmount(value);
                      },
                    ),

                    // عرض الدين الحالي
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الدين الحالي:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
                          borderRadius: BorderRadius.circular(8),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'تحذير!',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      errorMessage != null || amountController.text.isEmpty
                          ? null
                          : () {
                            final normalizedValue = amountController.text
                                .replaceAll(',', '.');
                            final amount = double.tryParse(normalizedValue);

                            if (amount == null ||
                                amount <= 0 ||
                                amount > currentDebt) {
                              return;
                            }
                            onPayment(customer, amount);
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey[400],
                  ),
                  child: const Text('تسديد'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
