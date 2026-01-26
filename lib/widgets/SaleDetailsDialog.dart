import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/models/customer.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/widgets/customer_selection_dialog.dart';
import '../models/sale.dart';
import '../providers/sales_provider.dart';

class SaleDetailsDialog extends StatefulWidget {
  final int saleId;

  const SaleDetailsDialog({super.key, required this.saleId});

  @override
  State<SaleDetailsDialog> createState() => _SaleDetailsDialogState();
}

class _SaleDetailsDialogState extends State<SaleDetailsDialog> {
  late Future<Map<String, dynamic>> _saleDetailsFuture;
  final SalesProvider _salesProvider = SalesProvider();

  @override
  void initState() {
    super.initState();
    _refreshSaleDetails();
  }

  void _refreshSaleDetails() {
    setState(() {
      _saleDetailsFuture = _salesProvider.getSaleDetails(widget.saleId);
    });
  }

  Future<void> _updatePaymentType(
    String newPaymentType, {
    Customer? selectedCustomer,
  }) async {
    try {
      if (newPaymentType == 'credit' && selectedCustomer == null) {
        await _showCustomerSelectionDialog(newPaymentType);
        return;
      }

      await _salesProvider.updatePaymentType(
        widget.saleId,
        newPaymentType,
        customerId: selectedCustomer?.id,
      );

      _refreshSaleDetails();

      if (mounted) {
        String message =
            newPaymentType == 'cash'
                ? 'تم تغيير نوع الدفع إلى نقدي'
                : 'تم تغيير نوع الدفع إلى آجل للزبون ${selectedCustomer?.name}';
        showAppToast(context, message, ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'فشل في تعديل نوع الدفع: ${e.toString()}',
          ToastType.error,
        );
      }
    }
  }

  Future<void> _showCustomerSelectionDialog(String paymentType) async {
    try {
      final Customer? selectedCustomer = await showDialog<Customer>(
        context: context,
        builder:
            (context) => CustomerSelectionDialog(
              onSaleCompleted: (customer) {
                Navigator.pop(context, customer);
              },
            ),
      );

      if (selectedCustomer != null && mounted) {
        await _updatePaymentType(
          paymentType,
          selectedCustomer: selectedCustomer,
        );
      } else if (mounted) {
        showAppToast(context, 'تم إلغاء تغيير نوع الدفع', ToastType.warning);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'حدث خطأ أثناء اختيار الزبون: ${e.toString()}',
          ToastType.error,
        );
      }
    }
  }

  void _showPaymentTypeDialog(BuildContext context, String currentPaymentType) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'تغيير نوع الدفع',
              style: TextStyle(fontSize: 18),
            ),
            content: const Text('اختر نوع الدفع الجديد:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updatePaymentType('cash');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      currentPaymentType == 'cash'
                          ? Colors.green
                          : Colors.grey[300],
                  foregroundColor:
                      currentPaymentType == 'cash'
                          ? Colors.white
                          : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.money, size: 18),
                    SizedBox(width: 6),
                    Text('نقدي'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updatePaymentType('credit');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      currentPaymentType == 'credit'
                          ? Colors.orange
                          : Colors.grey[300],
                  foregroundColor:
                      currentPaymentType == 'credit'
                          ? Colors.white
                          : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 18),
                    SizedBox(width: 6),
                    Text('آجل'),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  void _showShowForTaxDialog(BuildContext context, bool currentShowForTax) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'تغيير حالة عرض الضرائب',
              style: TextStyle(fontSize: 18),
            ),
            content: const Text('اختر حالة عرض الضرائب:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  updateShowForTax(widget.saleId, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      currentShowForTax ? Colors.green : Colors.grey[300],
                  foregroundColor:
                      currentShowForTax ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 18),
                    SizedBox(width: 6),
                    Text('مضمنة'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  updateShowForTax(widget.saleId, false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      currentShowForTax ? Colors.orange : Colors.grey[300],
                  foregroundColor:
                      currentShowForTax ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, size: 18),
                    SizedBox(width: 6),
                    Text('غير مضمنة'),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Future<void> updateShowForTax(int saleId, bool showTax) async {
    try {
      await _salesProvider.updateShowForTax(widget.saleId, showTax);
      _refreshSaleDetails();

      if (mounted) {
        String message =
            showTax
                ? 'تم تغيير حالة عرض الضرائب إلى مضمنة'
                : 'تم تغيير حالة عرض الضرائب إلى غير مضمنة';
        showAppToast(context, message, ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'فشل في تعديل حالة عرض الضرائب: ${e.toString()}',
          ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _saleDetailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return _buildErrorState(context);
            }

            final saleData = snapshot.data!;
            final sale = saleData['sale'] as Sale;
            final items = saleData['items'] as List<dynamic>;

            return _buildSuccessState(context, sale, items);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'جاري تحميل الفاتورة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'خطأ في التحميل',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'تعذر تحميل تفاصيل الفاتورة',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(
    BuildContext context,
    Sale sale,
    List<dynamic> items,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with close button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فاتورة رقم #${sale.id}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sale.formattedDate,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sale.formattedTime,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 24),
                onPressed: () => Navigator.pop(context),
                color: Colors.grey[600],
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInvoiceInfo(context, sale),
                const SizedBox(height: 24),
                _buildProductsTable(items),
                const SizedBox(height: 24),
                _buildFinancialSummary(sale),
                const SizedBox(height: 24),
                _buildActionButtons(context, sale),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceInfo(BuildContext context, Sale sale) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.role;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.payment,
            label: 'نوع الدفع',
            value: sale.paymentType == 'cash' ? 'نقدي' : 'آجل',
            valueColor:
                sale.paymentType == 'cash' ? Colors.green : Colors.orange,
            isEditable: true,
            onEdit: () => _showPaymentTypeDialog(context, sale.paymentType),
          ),
          const Divider(height: 20),
          _buildInfoRow(
            icon: Icons.person,
            label: 'العميل',
            value: sale.customerName ?? 'بدون عميل',
            valueColor: Colors.blue,
          ),
          if (role != 'tax') ...[
            const Divider(height: 20),
            _buildInfoRow(
              icon: Icons.receipt,
              label: 'عرض الضرائب',
              value: sale.showForTax ? 'مضمنة' : 'غير مضمنة',
              valueColor: sale.showForTax ? Colors.green : Colors.orange,
              isEditable: true,
              onEdit: () => _showShowForTaxDialog(context, sale.showForTax),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    bool isEditable = false,
    VoidCallback? onEdit,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        if (isEditable && onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: onEdit,
            color: Colors.blue,
            tooltip: 'تعديل',
          ),
      ],
    );
  }

  Widget _buildProductsTable(List<dynamic> items) {
    // فصل المنتجات عن الخدمات
    final products =
        items.where((item) => item['unit_type'] != 'service').toList();
    final services =
        items.where((item) => item['unit_type'] == 'service').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان القسم
        const Text(
          'عناصر الفاتورة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),

        // جدول المنتجات (إذا وجدت)
        if (products.isNotEmpty) ...[
          _buildSectionTitle('المنتجات', Icons.shopping_bag, Colors.green),
          const SizedBox(height: 12),
          _buildItemsTable(products, isService: false),
          const SizedBox(height: 24),
        ],

        // جدول الخدمات (إذا وجدت)
        if (services.isNotEmpty) ...[
          _buildSectionTitle('الخدمات', Icons.design_services, Colors.purple),
          const SizedBox(height: 12),
          _buildItemsTable(services, isService: true),
        ],

        // إذا كانت الفاتورة فارغة
        if (products.isEmpty && services.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text(
                  'لا توجد عناصر في الفاتورة',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsTable(List<dynamic> items, {required bool isService}) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currency = settings.currencyName;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isService ? Colors.purple[50] : Colors.green[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    isService ? 'اسم الخدمة' : 'اسم المنتج',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'الوحدة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'الكمية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'السعر',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'المجموع',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            final index = entry.key;
            final isLast = index == items.length - 1;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border:
                    isLast
                        ? null
                        : Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: _buildItemRow(item, isService, currency),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    Map<String, dynamic> item,
    bool isService,
    String currency,
  ) {
    // استخدم item_name بدلاً من product_name
    final itemName = item['item_name'] ?? 'غير معروف';
    final quantity = item['quantity'] as double;
    final price = item['price'] as double;
    final subtotal = item['subtotal'] as double;
    final unitType = item['unit_type'] as String;
    final customUnitName = item['custom_unit_name'] as String?;
    final productBaseUnit = item['product_base_unit'] as String?;

    // تحديد اسم الوحدة المعروضة
    String displayUnit = _getDisplayUnit(
      unitType,
      customUnitName,
      productBaseUnit,
    );

    // تحديد الكمية المعروضة
    String displayQuantity = _getDisplayQuantity(quantity, unitType);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isService ? Colors.purple : Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  itemName, // استخدام item_name هنا
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isService ? Colors.purple[700] : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              displayUnit,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
                backgroundColor:
                    isService ? Colors.purple[50] : Colors.green[50],
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            displayQuantity,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            '${price.toStringAsFixed(2)} $currency',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            '${subtotal.toStringAsFixed(2)} $currency',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSummary(Sale sale) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currency = settings.currencyName;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            label: 'المبلغ الإجمالي',
            icon: Icons.monetization_on,
            value: '${sale.totalAmount.toStringAsFixed(2)} $currency',
            valueColor: Colors.blue[700]!,
          ),
          const Divider(height: 20),
          _buildSummaryRow(
            label: 'إجمالي الربح',
            icon: Icons.trending_up,
            value: '${sale.totalProfit.toStringAsFixed(2)} $currency',
            valueColor: Colors.green[700]!,
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required IconData icon,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Sale sale) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.role;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _showPaymentTypeDialog(context, sale.paymentType),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment, size: 18),
                SizedBox(width: 6),
                Text('تغيير الدفع'),
              ],
            ),
          ),
        ),
        if (role != 'tax') ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showShowForTaxDialog(context, sale.showForTax),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt, size: 18),
                  SizedBox(width: 6),
                  Text('تغيير الضرائب'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 18),
                SizedBox(width: 6),
                Text('تمت المشاهدة'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getDisplayUnit(
    String unitType,
    String? customUnitName,
    String? baseUnit,
  ) {
    switch (unitType) {
      case 'piece':
        return 'قطعة';
      case 'kg':
        return 'كيلو';
      case 'service':
        return 'خدمة'; // إضافة هذا
      case 'custom':
        return customUnitName ?? 'وحدة';
      default:
        return baseUnit == 'kg' ? 'كيلو' : 'قطعة';
    }
  }

  String _getDisplayQuantity(double quantity, String unitType) {
    if (unitType == 'kg' || unitType == 'custom') {
      // إذا كانت بالكيلو أو وحدة مخصصة، نعرض بعلامة عشرية إذا لزم الأمر
      return quantity % 1 == 0
          ? quantity.toInt().toString()
          : quantity.toStringAsFixed(2);
    } else {
      // إذا كانت قطع أو خدمات، نعرض كعدد صحيح
      return quantity.toInt().toString();
    }
  }
}
