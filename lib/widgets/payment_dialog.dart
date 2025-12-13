// widgets/payment_dialog.dart - النسخة المحدثة
import 'package:flutter/material.dart';
import 'package:shopmate/models/customer.dart';

class PaymentDialog extends StatefulWidget {
  final Customer customer;
  final double currentDebt;
  final Function(double amount, String? note) onPayment;

  const PaymentDialog({
    Key? key,
    required this.customer,
    required this.currentDebt,
    required this.onPayment,
  }) : super(key: key);

  @override
  _PaymentDialogState createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _validateAmount(String value) {
    if (value.isEmpty) {
      setState(() => _errorMessage = null);
      return;
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      setState(() => _errorMessage = 'يرجى إدخال رقم صحيح');
      return;
    }

    if (amount <= 0) {
      setState(() => _errorMessage = 'المبلغ يجب أن يكون أكبر من صفر');
      return;
    }

    if (amount > widget.currentDebt) {
      setState(() {
        _errorMessage =
            'المبلغ أكبر من الدين الحالي (${widget.currentDebt.toStringAsFixed(2)} دينار)';
      });
      return;
    }

    setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.payment, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            'تسديد دفعة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات العميل
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
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
                          widget.customer.name.substring(0, 1),
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
                            widget.customer.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'الدين الحالي: ${widget.currentDebt.toStringAsFixed(2)} دينار',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  widget.currentDebt > 0
                                      ? Colors.red
                                      : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // حقل إدخال المبلغ
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ (دينار)',
                  hintText: 'أدخل المبلغ',
                  prefixIcon: const Icon(Icons.money),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _amountController.clear();
                      setState(() => _errorMessage = null);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                onChanged: _validateAmount,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال المبلغ';
                  }

                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return 'يرجى إدخال رقم صحيح';
                  }

                  if (amount <= 0) {
                    return 'المبلغ يجب أن يكون أكبر من صفر';
                  }

                  if (amount > widget.currentDebt) {
                    return 'المبلغ أكبر من الدين الحالي';
                  }

                  return null;
                },
              ),

              // عرض رسالة الخطأ
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // اقتراحات المبالغ السريعة
              if (widget.currentDebt > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اقتراحات سريعة:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _buildQuickAmountButtons(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // حقل الملاحظة
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  hintText: 'أدخل ملاحظة عن الدفعة',
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed:
              _errorMessage != null || _amountController.text.isEmpty
                  ? null
                  : () {
                    if (_formKey.currentState!.validate()) {
                      final amount = double.parse(_amountController.text);
                      final note =
                          _noteController.text.isEmpty
                              ? null
                              : _noteController.text;
                      widget.onPayment(amount, note);
                      Navigator.pop(context);
                    }
                  },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            disabledBackgroundColor: Colors.grey[400],
          ),
          child: const Text('تسديد الدفعة'),
        ),
      ],
    );
  }

  List<Widget> _buildQuickAmountButtons() {
    final suggestions = <double>[];

    if (widget.currentDebt >= 5) suggestions.add(5);
    if (widget.currentDebt >= 10) suggestions.add(10);
    if (widget.currentDebt >= 20) suggestions.add(20);
    if (widget.currentDebt >= 50) suggestions.add(50);
    if (widget.currentDebt >= 100) suggestions.add(100);
    if (widget.currentDebt >= 200) suggestions.add(200);

    // إضافة ربع الدين ونصف الدين
    if (widget.currentDebt >= 1) {
      suggestions.add(widget.currentDebt * 0.25);
      suggestions.add(widget.currentDebt * 0.5);
      suggestions.add(widget.currentDebt); // الدين الكامل
    }

    // إزالة التكرارات وتصفية المبالغ الزائدة
    final uniqueSuggestions =
        suggestions
            .where((amount) => amount <= widget.currentDebt)
            .toSet()
            .toList()
          ..sort();

    return uniqueSuggestions.map((amount) {
      return ChoiceChip(
        label: Text(
          amount == widget.currentDebt
              ? 'كل الدين (${amount.toStringAsFixed(2)})'
              : amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2),
          style: TextStyle(
            color: amount <= widget.currentDebt ? Colors.green : Colors.grey,
            fontSize: 12,
          ),
        ),
        selected:
            _amountController.text.isNotEmpty &&
            double.tryParse(_amountController.text) == amount,
        onSelected:
            amount <= widget.currentDebt
                ? (selected) {
                  if (selected) {
                    _amountController.text = amount.toStringAsFixed(2);
                    _validateAmount(amount.toStringAsFixed(2));
                  }
                }
                : null,
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.green.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color:
                amount <= widget.currentDebt ? Colors.green : Colors.grey[300]!,
          ),
        ),
      );
    }).toList();
  }
}
