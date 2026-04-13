import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/settings_provider.dart';

Future<Map<String, double>?> showPaymentDialog(
  BuildContext context,
  double finalAmount,
) async {
  final settings = Provider.of<SettingsProvider>(context, listen: false);
  final currency = settings.currencyName;
  final paidController = TextEditingController();
  double changeAmount = 0;
  double dueAmount = 0;

  return showDialog<Map<String, double>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          void calculate() {
            final paid = double.tryParse(paidController.text) ?? 0;
            if (paid >= finalAmount) {
              changeAmount = paid - finalAmount;
              dueAmount = 0;
            } else {
              changeAmount = 0;
              dueAmount = finalAmount - paid;
            }
            setState(() {});
          }

          return AlertDialog(
            title: const Text('تفاصيل الدفع', textAlign: TextAlign.right),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currency ${finalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                    const Text(
                      'المجموع النهائي:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: paidController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المدفوع ($currency)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  onChanged: (_) => calculate(),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                if (changeAmount > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$currency ${changeAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text('الباقي للزبون:'),
                      ],
                    ),
                  ),
                if (dueAmount > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$currency ${dueAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text('المبلغ المستحق:'),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                onPressed:
                    paidController.text.isEmpty
                        ? null
                        : () {
                          final paid =
                              double.tryParse(paidController.text) ?? 0;
                          Navigator.pop(ctx, {
                            'paid': paid,
                            'change': changeAmount,
                            'due': dueAmount,
                          });
                        },
                icon: const Icon(Icons.print),
                label: const Text('طباعة الفاتورة'),
              ),
            ],
          );
        },
      );
    },
  );
}
