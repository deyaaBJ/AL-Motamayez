// widgets/sale_details_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/helpers/helpers.dart';
import 'package:shopmate/models/customer.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/providers/settings_provider.dart';
import 'package:shopmate/widgets/customer_selection_dialog.dart';
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
  final SalesProvider _salesProvider = SalesProvider(); // إنشاء instance مباشر

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
        // إذا كان credit ولم يتم اختيار زبون، نفتح dialog اختيار الزبون
        await _showCustomerSelectionDialog(newPaymentType);
        return;
      }

      // استخدام الـ provider مباشرة
      await _salesProvider.updatePaymentType(
        widget.saleId,
        newPaymentType,
        customerId: selectedCustomer?.id,
      );

      _refreshSaleDetails(); // تحديث البيانات بعد التعديل

      // عرض رسالة نجاح
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
                Navigator.pop(context, customer); // إرجاع الزبون المختار
              },
            ),
      );

      if (selectedCustomer != null && mounted) {
        // إذا تم اختيار زبون، نكمل عملية التحديث
        await _updatePaymentType(
          paymentType,
          selectedCustomer: selectedCustomer,
        );
      } else if (mounted) {
        // إذا تم إلغاء العملية، نعرض رسالة فقط إذا كانت الصفحة مازالت مفتوحة
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
            title: const Text('تغيير نوع الدفع'),
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
                ),
                child: const Text('نقدي 💵'),
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
                ),
                child: const Text('آجل 📅'),
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
            title: const Text('تغيير حاله عرض الضرائب'),
            content: const Text('اختر حاله عرض الضرائب:'),
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
                ),
                child: const Text('تضمنه بالضرائب ✅'),
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
                ),
                child: const Text('غير تضمنه بالضرائب ❌'),
              ),
            ],
          ),
    );
  }

  // باقي الكود يبقى كما هو مع بعض التعديلات البسيطة...
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
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
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'جاري تحميل الفاتورة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
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
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInvoiceHeader(sale),
            const SizedBox(height: 24),
            _buildInvoiceInfo(context, sale),
            const SizedBox(height: 20),
            _buildProductsSection(items),
            const SizedBox(height: 20),
            _buildFinancialSummary(sale),
            const SizedBox(height: 24),
            _buildActionButtons(context, sale),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader(Sale sale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'فاتورة رقم #${sale.id}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(sale.formattedDate),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(sale.formattedTime),
            ],
          ),
        ],
      ),
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
      ),
      child: Column(
        children: [
          _buildEditablePaymentType(context, sale),
          const SizedBox(height: 12),
          _buildInfoItem(
            icon: Icons.person,
            title: 'العميل',
            value: sale.customerName ?? 'بدون عميل',
            valueColor: Colors.blue,
          ),
          const SizedBox(height: 12),
          if (role != 'tax') _buildEditShowForTax(context, sale),
        ],
      ),
    );
  }

  Widget _buildEditablePaymentType(BuildContext context, Sale sale) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.payment, size: 18, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'نوع الدفع',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                sale.paymentType == 'cash' ? 'نقدي 💵' : 'آجل 📅',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color:
                      sale.paymentType == 'cash' ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: () => _showPaymentTypeDialog(context, sale.paymentType),
          tooltip: 'تغيير نوع الدفع',
        ),
      ],
    );
  }

  Widget _buildEditShowForTax(BuildContext context, Sale sale) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.receipt, size: 18, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'عرض للضرائب',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                sale.showForTax ? 'مضمنه بالضرائب ✅' : 'غير مضمنه بالضرائب ❌',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color:
                      sale.showForTax
                          ? Colors.green
                          : const Color.fromARGB(255, 219, 91, 5),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: () => _showShowForTaxDialog(context, sale.showForTax),
          tooltip: 'تغيير حالة عرض الضرائب',
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSection(List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المنتجات المشتراة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('المنتج')),
                    Expanded(
                      child: Text('الوحدة', textAlign: TextAlign.center),
                    ),
                    Expanded(
                      child: Text('الكمية', textAlign: TextAlign.center),
                    ),
                    Expanded(child: Text('السعر', textAlign: TextAlign.center)),
                    Expanded(
                      child: Text('المجموع', textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
              // Items
              ...items.map((item) => _buildProductRow(item)).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductRow(Map<String, dynamic> item) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;

    final productName = item['product_name'] ?? 'منتج';
    final quantity = item['quantity'] as double;
    final price = item['price'] as double;
    final subtotal = item['subtotal'] as double;
    final unitType = item['unit_type'] as String;
    final customUnitName = item['custom_unit_name'] as String?;
    final productBaseUnit = item['product_base_unit'] as String;

    // تحديد اسم الوحدة المعروضة
    String displayUnit = _getDisplayUnit(
      unitType,
      customUnitName,
      productBaseUnit,
    );

    // تحديد الكمية المعروضة
    String displayQuantity = _getDisplayQuantity(quantity, unitType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(productName)),
          Expanded(
            child: Text(
              displayUnit,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
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
              '${price.toStringAsFixed(0)} ${settings.currencyName}',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${subtotal.toStringAsFixed(0)} ${settings.currencyName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(Sale sale) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            label: 'المبلغ الإجمالي',
            value:
                '${sale.totalAmount.toStringAsFixed(0)} ${settings.currencyName}',
            valueColor: Colors.blue[700]!,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            label: 'إجمالي الربح',
            value:
                '${sale.totalProfit.toStringAsFixed(0)} ${settings.currencyName}',
            valueColor: Colors.green[700]!,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Sale sale) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _showPaymentTypeDialog(context, sale.paymentType),
            child: const Text('تغيير نوع الدفع'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تمت المشاهدة'),
          ),
        ),
      ],
    );
  }

  Future<void> updateShowForTax(int saleId, bool bool) async {
    try {
      // استخدام الـ provider مباشرة
      await _salesProvider.updateShowForTax(widget.saleId, bool);

      _refreshSaleDetails(); // تحديث البيانات بعد التعديل

      // عرض رسالة نجاح
      if (mounted) {
        String message =
            bool
                ? 'تم تغيير نوع حالة عرض الضرائب إلى تضمنه بالضرائب ✅'
                : 'تم تغيير نوع حالة عرض الضرائب إلى غير تضمنه بالضرائب ❌';

        showAppToast(context, message, ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'فشل في تعديل نوع عرضه للضرائب: ${e.toString()}',
          ToastType.error,
        );
      }
    }
  }

  String _getDisplayUnit(
    String unitType,
    String? customUnitName,
    String baseUnit,
  ) {
    switch (unitType) {
      case 'piece':
        return 'قطعة';
      case 'kg':
        return 'كيلو';
      case 'custom':
        return customUnitName ?? 'وحدة';
      default:
        return baseUnit == 'kg' ? 'كيلو' : 'قطعة';
    }
  }

  String _getDisplayQuantity(double quantity, String unitType) {
    if (unitType == 'kg') {
      // إذا كانت بالكيلو، نعرض بعلامة عشرية إذا لزم الأمر
      return quantity % 1 == 0
          ? quantity.toInt().toString()
          : quantity.toStringAsFixed(2);
    } else {
      // إذا كانت قطع أو وحدات مخصصة، نعرض كعدد صحيح
      return quantity.toInt().toString();
    }
  }
}
