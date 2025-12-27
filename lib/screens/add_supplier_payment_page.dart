import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import '../providers/supplier_provider.dart';
import '../providers/purchase_invoice_provider.dart';
import '../utils/formatters.dart';

class AddSupplierPaymentPage extends StatefulWidget {
  final int supplierId;
  final String supplierName;
  final double currentBalance;

  const AddSupplierPaymentPage({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.currentBalance,
  });

  @override
  State<AddSupplierPaymentPage> createState() => _AddSupplierPaymentPageState();
}

class _AddSupplierPaymentPageState extends State<AddSupplierPaymentPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;
  int? _selectedInvoiceId;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    try {
      final provider = Provider.of<PurchaseInvoiceProvider>(
        context,
        listen: false,
      );
      await provider.loadPurchaseInvoices();

      // تصفية الفواتير الخاصة بهذا المورد
      final allInvoices = provider.invoices;
      _invoices =
          allInvoices.where((invoice) {
            return invoice['supplier_id'] == widget.supplierId &&
                (invoice['remaining_amount'] as num).toDouble() > 0;
          }).toList();

      setState(() {});
    } catch (e) {
      print('خطأ في تحميل الفواتير: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(currentPage: 'إضافة دفعة', child: _buildContent()),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildBalanceInfo(),
          const SizedBox(height: 20),
          _buildPaymentForm(),
          const SizedBox(height: 20),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.payment, size: 32, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'دفعة للمورد: ${widget.supplierName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'تسديد جزء من المبلغ المستحق',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceInfo() {
    final isDebt = widget.currentBalance > 0;

    return Card(
      color: isDebt ? Colors.orange.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الرصيد الحالي:', style: TextStyle(fontSize: 16)),
                Text(
                  Formatters.formatCurrency(widget.currentBalance.abs()),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDebt ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isDebt ? 'المورد مدين بهذا المبلغ' : 'المورد دائن',
              style: TextStyle(color: isDebt ? Colors.orange : Colors.green),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفاصيل الدفعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // المبلغ
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'المبلغ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                hintText: 'أدخل المبلغ المراد دفعه',
              ),
            ),
            const SizedBox(height: 16),
            // ربط بفاتورة (اختياري)
            if (_invoices.isNotEmpty) ...[
              const Text(
                'ربط بفاتورة (اختياري)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'اختر الفاتورة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.receipt),
                ),
                value: _selectedInvoiceId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('دفعة عامة (غير مرتبطة بفاتورة)'),
                  ),
                  ..._invoices.map((invoice) {
                    final invoiceId = invoice['id'] as int;
                    final totalCost = (invoice['total_cost'] as num).toDouble();
                    final remaining =
                        (invoice['remaining_amount'] as num).toDouble();

                    return DropdownMenuItem<int>(
                      value: invoiceId,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('فاتورة #$invoiceId'),
                          Text(
                            'المتبقي: ${Formatters.formatCurrency(remaining)} من ${Formatters.formatCurrency(totalCost)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedInvoiceId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            // الملاحظات
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _savePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'حفظ الدفعة',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
      ),
    );
  }

  Future<void> _savePayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('يرجى إدخال المبلغ');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('يرجى إدخال مبلغ صحيح');
      return;
    }

    if (widget.currentBalance > 0 && amount > widget.currentBalance) {
      _showError('المبلغ أكبر من الرصيد المستحق');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<SupplierProvider>(context, listen: false);

      await provider.addSupplierPayment(
        supplierId: widget.supplierId,
        purchaseInvoiceId: _selectedInvoiceId,
        amount: amount,
        note:
            _noteController.text.isNotEmpty
                ? _noteController.text
                : _selectedInvoiceId != null
                ? 'دفعة على فاتورة #$_selectedInvoiceId'
                : 'دفعة عامة',
      );

      _showSuccess('تم حفظ الدفعة بنجاح');

      // الانتقال للخلف بعد تأخير قصير
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('خطأ في حفظ الدفعة: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
