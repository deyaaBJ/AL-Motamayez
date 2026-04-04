// screens/purchase_invoice_details_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/providers/purchase_item_provider.dart';
import 'package:motamayez/utils/formatters.dart';
import 'package:motamayez/utils/date_formatter.dart';

class PurchaseInvoiceDetailsPage extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const PurchaseInvoiceDetailsPage({super.key, required this.invoice});

  @override
  State<PurchaseInvoiceDetailsPage> createState() =>
      _PurchaseInvoiceDetailsPageState();
}

class _PurchaseInvoiceDetailsPageState
    extends State<PurchaseInvoiceDetailsPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _purchaseItems = [];

  String _translateUnit(String? unit) {
    switch (unit?.toLowerCase()) {
      case 'piece':
        return 'قطعة';
      case 'kg':
        return 'كيلو';
      default:
        final trimmedUnit = unit?.trim() ?? '';
        return trimmedUnit.isEmpty ? 'قطعة' : trimmedUnit;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInvoiceItems();
  }

  Future<void> _loadInvoiceItems() async {
    setState(() => _isLoading = true);

    try {
      final purchaseItemProvider = context.read<PurchaseItemProvider>();
      final items = await purchaseItemProvider.getPurchaseItemsWithProducts(
        widget.invoice['id'],
      );

      setState(() {
        _purchaseItems = items;
      });
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل تفاصيل الفاتورة: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==================== Widget Builder Methods ====================

  /// رأس الصفحة المُحسَّن
  Widget _buildHeader(BuildContext context, Map<String, dynamic> invoice) {
    final isCash = invoice['payment_type'] == 'cash';
    final dateInfo = DateFormatter.formatDateTime(invoice['date']);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصف العلوي: الرجوع والمعلومات الأساسية
          Row(
            children: [
              // زر الرجوع المُبسَّط
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.grey.shade800,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فاتورة مشتريات #${invoice['id']}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dateInfo['date']} • ${dateInfo['time_12']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // حالة الدفع
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isCash ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isCash ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCash ? Icons.money : Icons.credit_card,
                      size: 16,
                      color:
                          isCash
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCash ? 'نقدي' : 'آجل',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color:
                            isCash
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بطاقة معلومات المورد والإجمالي
  Widget _buildInvoiceInfoCard(Map<String, dynamic> invoice) {
    final supplierName = invoice['supplier_name'] ?? 'غير محدد';
    final note = invoice['note']?.toString().trim() ?? '';
    final totalCost = invoice['total_cost']?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // المورد والإجمالي في صف واحد
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المورد',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.store,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            supplierName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // خط فاصل عمودي
              Container(
                height: 50,
                width: 1,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // الإجمالي
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإجمالي',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.formatCurrency(totalCost),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // الملاحظات إذا وجدت
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, color: Colors.orange.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// بناء الجدول الاحترافي
  Widget _buildProductsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // رأس الجدول
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                // رقم
                SizedBox(
                  width: 40,
                  child: Text(
                    'رقم',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // اسم المنتج
                Expanded(
                  flex: 3,
                  child: Text(
                    'اسم المنتج',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),

                // الكمية
                SizedBox(
                  width: 70,
                  child: Text(
                    'الكمية',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // سعر الحبة
                SizedBox(
                  width: 85,
                  child: Text(
                    'السعر',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // المجموع
                SizedBox(
                  width: 90,
                  child: Text(
                    'المجموع',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // جسم الجدول
          ..._purchaseItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final quantity =
                ((item['display_quantity'] ?? item['quantity']) as num)
                    .toDouble();
            final costPrice = (item['cost_price'] as num).toDouble();
            final subtotal = (item['subtotal'] as num).toDouble();
            final displayCostPrice =
                quantity > 0 ? subtotal / quantity : costPrice;
            final productName = item['product_name'] ?? 'غير معروف';
            final displayUnit = _translateUnit(item['display_unit'] as String?);

            // تحديد لون الصف (تبديل الألوان)
            final isEvenRow = index % 2 == 0;

            return Container(
              decoration: BoxDecoration(
                color: isEvenRow ? Colors.white : Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: index == _purchaseItems.length - 1 ? 0 : 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // رقم
                    SizedBox(
                      width: 40,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // اسم المنتج
                    Expanded(
                      flex: 3,
                      child: Text(
                        productName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // الكمية
                    SizedBox(
                      width: 70,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              quantity.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayUnit,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // سعر الحبة
                    SizedBox(
                      width: 85,
                      child: Text(
                        Formatters.formatNumber(displayCostPrice),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // المجموع
                    SizedBox(
                      width: 90,
                      child: Text(
                        Formatters.formatCurrency(subtotal),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// قسم المنتجات مع الجدول
  Widget _buildProductsSection(Map<String, dynamic> invoice) {
    if (_purchaseItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد منتجات في هذه الفاتورة',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final totalCost = invoice['total_cost']?.toDouble() ?? 0.0;
    final itemsCount = _purchaseItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان القسم
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'تفاصيل الفاتورة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$itemsCount منتج',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // الجدول
        _buildProductsTable(),

        const SizedBox(height: 16),

        // ملخص الفاتورة
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإجمالي النهائي',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemsCount منتجات',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Text(
                Formatters.formatCurrency(totalCost),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// حالة التحميل المُحسَّنة
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل تفاصيل الفاتورة...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// أزرار التنقل المُحسَّنة
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // زر الرجوع
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 20),
              label: const Text(
                'رجوع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade800,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // زر الطباعة
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print_outlined, size: 20),
              label: const Text(
                'طباعة الفاتورة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Main Build Method ====================

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'تفاصيل الفاتورة',
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header
                _buildHeader(context, invoice),

                // Content
                Expanded(
                  child:
                      _isLoading
                          ? _buildLoadingState()
                          : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                // Invoice Info Card
                                _buildInvoiceInfoCard(invoice),

                                const SizedBox(height: 16),

                                // Products Section
                                _buildProductsSection(invoice),

                                const SizedBox(
                                  height: 80,
                                ), // مساحة للأزرار السفلية
                              ],
                            ),
                          ),
                ),

                // Action Buttons
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
