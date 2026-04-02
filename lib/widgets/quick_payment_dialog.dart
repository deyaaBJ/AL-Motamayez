import 'package:flutter/material.dart';
import 'package:motamayez/models/customer.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:provider/provider.dart';

enum PaymentMode {
  payment,
  deposit,
  withdrawal,
}

class QuickPaymentDialog {
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

  static void showDeposit({
    required BuildContext context,
    required Customer customer,
    required double currentBalance,
    required Future<void> Function(
      Customer customer,
      double amount,
      String? note,
    )
    onDeposit,
  }) {
    _showAmountDialog(
      context: context,
      customer: customer,
      currentBalance: currentBalance,
      mode: PaymentMode.deposit,
      onConfirm: onDeposit,
    );
  }

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
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;

    showDialog(
      context: context,
      builder: (dialogContext) {
        String? errorMessage;
        bool showError = false;
        bool isProcessing = false;

        return StatefulBuilder(
          builder: (context, setState) {
            void clearError() {
              setState(() {
                errorMessage = null;
                showError = false;
              });
            }

            void validateAmount(String value) {
              if (value.isEmpty) {
                clearError();
                return;
              }

              final normalizedValue = value.replaceAll(',', '.');
              final amount = double.tryParse(normalizedValue);

              if (amount == null) {
                setState(() {
                  errorMessage = 'يرجى إدخال رقم صحيح مثل 10.5';
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

              if (mode == PaymentMode.payment) {
                if (currentBalance <= 0) {
                  setState(() {
                    errorMessage = 'لا يوجد دين على العميل لتسديده';
                    showError = true;
                  });
                  return;
                }

                if (amount > currentBalance) {
                  setState(() {
                    errorMessage =
                        'المبلغ أكبر من الدين الحالي.\n'
                        'الدين الحالي: ${currentBalance.toStringAsFixed(2)} $currencyName';
                    showError = true;
                  });
                  return;
                }
              }

              if (mode == PaymentMode.withdrawal) {
                if (currentBalance >= 0) {
                  setState(() {
                    errorMessage = 'لا يوجد رصيد متاح للعميل ليتم صرفه';
                    showError = true;
                  });
                  return;
                }

                final availableBalance = currentBalance.abs();
                if (amount > availableBalance) {
                  setState(() {
                    errorMessage =
                        'المبلغ أكبر من الرصيد المتاح.\n'
                        'الرصيد المتاح: ${availableBalance.toStringAsFixed(2)} $currencyName';
                    showError = true;
                  });
                  return;
                }
              }

              clearError();
            }

            final config = _DialogModeConfig.from(
              mode: mode,
              currentBalance: currentBalance,
              currencyName: currencyName,
            );

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
                      color: config.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(config.icon, color: config.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.title,
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
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: config.amountHint,
                        labelText: config.amountLabel,
                        prefixIcon: Icon(Icons.money, color: config.color),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            amountController.clear();
                            clearError();
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: config.color,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: validateAmount,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'ملاحظة اختيارية',
                        labelText: 'ملاحظة',
                        prefixIcon: const Icon(Icons.note, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
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
                            config.balanceLabel,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            config.balanceValue,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: config.balanceColor,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                  fontSize: 13,
                                  height: 1.4,
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
                  onPressed:
                      isProcessing ? null : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed:
                      isProcessing
                          ? null
                          : () async {
                            validateAmount(amountController.text.trim());
                            if (showError) return;

                            final normalizedValue = amountController.text
                                .trim()
                                .replaceAll(',', '.');
                            final amount = double.tryParse(normalizedValue);
                            if (amount == null || amount <= 0) return;

                            setState(() => isProcessing = true);

                            try {
                              await onConfirm(
                                customer,
                                amount,
                                noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                              );

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                setState(() => isProcessing = false);
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: config.color,
                    foregroundColor: Colors.white,
                  ),
                  child:
                      isProcessing
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(config.buttonText),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DialogModeConfig {
  final String title;
  final String buttonText;
  final String amountHint;
  final String amountLabel;
  final String balanceLabel;
  final String balanceValue;
  final IconData icon;
  final Color color;
  final Color balanceColor;

  const _DialogModeConfig({
    required this.title,
    required this.buttonText,
    required this.amountHint,
    required this.amountLabel,
    required this.balanceLabel,
    required this.balanceValue,
    required this.icon,
    required this.color,
    required this.balanceColor,
  });

  factory _DialogModeConfig.from({
    required PaymentMode mode,
    required double currentBalance,
    required String currencyName,
  }) {
    switch (mode) {
      case PaymentMode.payment:
        return _DialogModeConfig(
          title: 'تسديد دفعة',
          buttonText: 'تسديد',
          amountHint: 'أدخل مبلغ التسديد',
          amountLabel: 'مبلغ التسديد ($currencyName)',
          balanceLabel: 'الدين الحالي:',
          balanceValue: '${currentBalance.toStringAsFixed(2)} $currencyName',
          icon: Icons.payment,
          color: Colors.green,
          balanceColor: Colors.red,
        );
      case PaymentMode.deposit:
        final hasCredit = currentBalance < 0;
        return _DialogModeConfig(
          title: 'إيداع رصيد',
          buttonText: 'إيداع',
          amountHint: 'أدخل مبلغ الإيداع',
          amountLabel: 'مبلغ الإيداع ($currencyName)',
          balanceLabel: hasCredit ? 'الرصيد الحالي:' : 'الحساب الحالي:',
          balanceValue:
              '${currentBalance.abs().toStringAsFixed(2)} $currencyName',
          icon: Icons.account_balance_wallet,
          color: Colors.teal,
          balanceColor: hasCredit ? Colors.teal : Colors.orange,
        );
      case PaymentMode.withdrawal:
        return _DialogModeConfig(
          title: 'صرف رصيد',
          buttonText: 'صرف',
          amountHint: 'أدخل مبلغ الصرف',
          amountLabel: 'مبلغ الصرف ($currencyName)',
          balanceLabel: 'الرصيد المتاح:',
          balanceValue:
              '${currentBalance.abs().toStringAsFixed(2)} $currencyName',
          icon: Icons.money,
          color: Colors.blue,
          balanceColor: Colors.blue,
        );
    }
  }
}
