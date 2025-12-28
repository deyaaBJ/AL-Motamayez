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
  bool _loadingInvoices = true;
  int? _selectedInvoiceId;
  List<Map<String, dynamic>> _invoices = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Future<void> _loadInvoices() async {
    setState(() => _loadingInvoices = true);

    try {
      // ============================================
      // **المنطق الجديد: التحقق من حالة الرصيد**
      // ============================================
      if (widget.currentBalance <= 0) {
        // إذا كان المورد مدين لنا أو مسدد
        setState(() {
          _invoices = [];
          _loadingInvoices = false;
        });
        return;
      }

      // إذا كنا نحن مدينين للمورد (currentBalance > 0)
      final provider = Provider.of<SupplierProvider>(context, listen: false);

      final invoices = await provider.getSupplierInvoicesForDropdown(
        widget.supplierId,
      );

      setState(() {
        _invoices = invoices;
        _loadingInvoices = false;
      });
    } catch (e) {
      print('❌ خطأ في تحميل الفواتير: $e');
      _showError('تعذر تحميل الفواتير');
      setState(() => _loadingInvoices = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'إضافة دفعة',
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildBalanceInfo(),
                        const SizedBox(height: 20),
                        Expanded(child: _buildPaymentForm()),
                        const SizedBox(height: 20),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.payment, size: 36, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'دفعة للمورد: ${widget.supplierName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'تسديد جزء من المبلغ المستحق',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
    final isWeOweSupplier = widget.currentBalance > 0;
    final isSupplierOwesUs = widget.currentBalance < 0;

    Color getStatusColor() {
      if (isWeOweSupplier) return Colors.red.shade700;
      if (isSupplierOwesUs) return Colors.green.shade700;
      return Colors.blue.shade700;
    }

    String getStatusText() {
      if (isWeOweSupplier) return 'أنت مدين للمورد';
      if (isSupplierOwesUs) return 'المورد مدين لك';
      return 'لا يوجد دين';
    }

    String getDetailedStatusText() {
      if (isWeOweSupplier) {
        return 'أنت مدين للمورد بمبلغ ${Formatters.formatCurrency(widget.currentBalance)}';
      } else if (isSupplierOwesUs) {
        return 'المورد مدين لك بمبلغ ${Formatters.formatCurrency(widget.currentBalance.abs())}';
      } else {
        return 'لا يوجد دين بينك وبين المورد';
      }
    }

    return Card(
      color:
          isWeOweSupplier
              ? Colors.red.shade50
              : isSupplierOwesUs
              ? Colors.green.shade50
              : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الرصيد الحالي:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  Formatters.formatCurrency(widget.currentBalance.abs()),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: getStatusColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              getStatusText(),
              style: TextStyle(
                fontSize: 18,
                color: getStatusColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              getDetailedStatusText(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تفاصيل الدفعة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // المبلغ
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'المبلغ *',
                labelStyle: TextStyle(fontSize: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.attach_money, size: 28),
                hintText: 'أدخل المبلغ المراد دفعه',
                hintStyle: TextStyle(fontSize: 16),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال المبلغ';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'يرجى إدخال مبلغ صحيح أكبر من الصفر';
                }

                // ============================================
                // **تحقق خاص حسب حالة الرصيد**
                // ============================================
                if (widget.currentBalance > 0) {
                  // نحن مدينين للمورد
                  if (amount > widget.currentBalance) {
                    return 'المبلغ أكبر من الرصيد المستحق';
                  }
                } else if (widget.currentBalance < 0) {
                  // المورد مدين لنا
                  // يمكن أن يكون المبلغ أي قيمة (لأننا نستقبل مصاري من المورد)
                }
                // إذا كان الرصيد = 0 يمكن أن يكون المبلغ أي قيمة (دفعة مسبقة)

                return null;
              },
            ),
            const SizedBox(height: 20),

            // اختيار الفاتورة
            _buildInvoiceSelector(),
            const SizedBox(height: 20),

            // الملاحظات
            TextFormField(
              controller: _noteController,
              style: TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                labelStyle: TextStyle(fontSize: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.note, size: 28),
                hintText: 'أدخل ملاحظات حول الدفعة',
                hintStyle: TextStyle(fontSize: 16),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSelector() {
    // ============================================
    // **المنطق الجديد: التحقق من حالة الرصيد**
    // ============================================
    final isWeOweSupplier = widget.currentBalance > 0;
    final isSupplierOwesUs = widget.currentBalance < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ربط الدفعة بفاتورة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // ============================================
        // **رسالة خاصة حسب حالة الرصيد**
        // ============================================
        if (isWeOweSupplier)
          Text(
            'اختياري - إذا تركت فارغاً ستكون دفعة عامة',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          )
        else if (isSupplierOwesUs)
          Text(
            'الفاتورة غير متاحة - المورد مدين لك',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            'الفاتورة غير متاحة - لا يوجد دين',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),

        const SizedBox(height: 12),

        if (_loadingInvoices)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (!isWeOweSupplier)
          // ============================================
          // **الحالة: المورد مدين لنا أو مسدد**
          // ============================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              color:
                  isSupplierOwesUs ? Colors.green.shade50 : Colors.blue.shade50,
            ),
            child: Row(
              children: [
                Icon(
                  isSupplierOwesUs ? Icons.money : Icons.check_circle,
                  size: 24,
                  color:
                      isSupplierOwesUs
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isSupplierOwesUs ? 'المورد مدين لك' : 'لا يوجد دين',
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isSupplierOwesUs
                                  ? Colors.green.shade800
                                  : Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSupplierOwesUs
                            ? 'يمكنك استلام دفعة عامة فقط'
                            : 'الدفعة ستكون دفعة عامة (لا توجد فواتير معلقة)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (_invoices.isEmpty)
          // ============================================
          // **الحالة: نحن مدينين للمورد ولكن لا توجد فواتير**
          // ============================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 24, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'لا توجد فواتير معلقة لهذا المورد',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
          )
        else
          // ============================================
          // **الحالة: نحن مدينين للمورد وهناك فواتير**
          // ============================================
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // زر لفتح Dialog لاختيار الفاتورة
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showInvoiceSelectionDialog(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt,
                            color: Colors.blue.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedInvoiceId == null
                                      ? 'اختر فاتورة للدفع'
                                      : 'فاتورة #$_selectedInvoiceId',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                if (_selectedInvoiceId != null)
                                  const SizedBox(height: 4),
                                if (_selectedInvoiceId != null)
                                  Text(
                                    'انقر لتغيير الاختيار',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // عرض تفاصيل الفاتورة المختارة
              if (_selectedInvoiceId != null) ...[
                const SizedBox(height: 12),
                _buildSelectedInvoiceCard(),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildSelectedInvoiceCard() {
    Map<String, dynamic>? selectedInvoice;
    for (var invoice in _invoices) {
      if (invoice['id'] == _selectedInvoiceId) {
        selectedInvoice = invoice;
        break;
      }
    }

    if (selectedInvoice == null) return const SizedBox();

    final totalCost = _toDouble(selectedInvoice['total_cost']);
    final remaining = _toDouble(selectedInvoice['remaining_amount']);
    final paid = _toDouble(selectedInvoice['paid_amount']);
    final paymentPercentage =
        totalCost > 0 ? ((paid / totalCost) * 100).round() : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, size: 24, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'فاتورة #${selectedInvoice['id']}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        paymentPercentage >= 100
                            ? Colors.green.shade100
                            : paymentPercentage >= 50
                            ? Colors.orange.shade100
                            : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color:
                          paymentPercentage >= 100
                              ? Colors.green.shade300
                              : paymentPercentage >= 50
                              ? Colors.orange.shade300
                              : Colors.red.shade300,
                    ),
                  ),
                  child: Text(
                    '$paymentPercentage%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color:
                          paymentPercentage >= 100
                              ? Colors.green.shade800
                              : paymentPercentage >= 50
                              ? Colors.orange.shade800
                              : Colors.red.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.grey.shade700,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedInvoiceId = null;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإجمالي',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.formatCurrency(totalCost),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المدفوع',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.formatCurrency(paid),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المتبقي',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.formatCurrency(remaining),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInvoiceSelectionDialog() async {
    // ============================================
    // **المنطق الجديد: التحقق من حالة الرصيد**
    // ============================================
    if (widget.currentBalance <= 0) {
      return; // لا تفتح الـ Dialog إذا لم نكن مدينين للمورد
    }

    final selectedId = await showDialog<int>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 500, minWidth: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'اختر فاتورة للدفع',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // List of invoices
                  Expanded(
                    child:
                        _invoices.isEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'لا توجد فواتير معلقة',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            )
                            : ListView.separated(
                              padding: const EdgeInsets.all(0),
                              shrinkWrap: true,
                              itemCount: _invoices.length + 1,
                              separatorBuilder:
                                  (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return ListTile(
                                    leading: Icon(
                                      Icons.payment,
                                      color: Colors.green.shade700,
                                      size: 28,
                                    ),
                                    title: Text(
                                      'دفعة عامة',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'دفعة غير مرتبطة بفاتورة محددة',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context, null);
                                    },
                                    tileColor:
                                        _selectedInvoiceId == null
                                            ? Colors.green.shade50
                                            : null,
                                  );
                                }

                                final invoice = _invoices[index - 1];
                                final invoiceId = invoice['id'] as int;
                                final totalCost = _toDouble(
                                  invoice['total_cost'],
                                );
                                final remaining = _toDouble(
                                  invoice['remaining_amount'],
                                );
                                final paid = _toDouble(invoice['paid_amount']);
                                final paymentPercentage =
                                    totalCost > 0
                                        ? ((paid / totalCost) * 100).round()
                                        : 0;

                                return ListTile(
                                  leading: Icon(
                                    Icons.receipt,
                                    color: Colors.blue.shade700,
                                    size: 28,
                                  ),
                                  title: Text(
                                    'فاتورة #${invoice['id']}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'الإجمالي',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  Formatters.formatCurrency(
                                                    totalCost,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'المدفوع',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  Formatters.formatCurrency(
                                                    paid,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.green.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'المتبقي',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  Formatters.formatCurrency(
                                                    remaining,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.orange.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing:
                                      _selectedInvoiceId == invoiceId
                                          ? Icon(
                                            Icons.check,
                                            color: Colors.green.shade700,
                                            size: 28,
                                          )
                                          : null,
                                  onTap: () {
                                    Navigator.pop(context, invoiceId);
                                  },
                                  tileColor:
                                      _selectedInvoiceId == invoiceId
                                          ? Colors.blue.shade50
                                          : null,
                                );
                              },
                            ),
                  ),

                  // Footer buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context, _selectedInvoiceId);
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'تأكيد الاختيار',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selectedId != null) {
      setState(() {
        _selectedInvoiceId = selectedId;
      });
    }
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_isLoading || _loadingInvoices) ? null : _savePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child:
            _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 28, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      'تسجيل الدفعة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showError('يرجى إدخال مبلغ صحيح');
      return;
    }

    // ============================================
    // **التحقق من المبلغ حسب حالة الرصيد**
    // ============================================
    if (widget.currentBalance > 0 && amount > widget.currentBalance) {
      _showError('المبلغ أكبر من الرصيد المستحق');
      return;
    }

    // إذا كانت الدفعة مرتبطة بفاتورة
    if (_selectedInvoiceId != null) {
      double remaining = 0.0;
      bool foundInvoice = false;

      for (var invoice in _invoices) {
        if (invoice['id'] == _selectedInvoiceId) {
          remaining = _toDouble(invoice['remaining_amount']);
          foundInvoice = true;
          break;
        }
      }

      if (!foundInvoice) {
        _showError('الفاتورة المحددة لم تعد متاحة');
        return;
      }

      if (amount > remaining) {
        _showError('المبلغ أكبر من المتبقي في الفاتورة');
        return;
      }
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

      _showSuccess('✅ تم تسجيل الدفعة بنجاح');

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        final newBalance = widget.currentBalance - amount;
        Navigator.pop(context, newBalance);
      }
    } catch (e) {
      _showError('خطأ في حفظ الدفعة: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
