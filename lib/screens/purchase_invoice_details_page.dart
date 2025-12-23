// screens/purchase_invoice_details_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/providers/purchase_invoice_provider.dart';
import 'package:shopmate/providers/purchase_item_provider.dart';
import 'package:shopmate/utils/formatters.dart';
import 'package:shopmate/utils/date_formatter.dart';

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
  double _itemsTotal = 0.0;

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
        _itemsTotal = items.fold(0.0, (sum, item) {
          return sum + (item['subtotal']?.toDouble() ?? 0.0);
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل تفاصيل الفاتورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isImportant = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isImportant ? 16 : 14,
              fontWeight: isImportant ? FontWeight.w600 : FontWeight.w500,
              color: isImportant ? Colors.green : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItemCard(Map<String, dynamic> item, int index) {
    final quantity = (item['quantity'] as num).toDouble();
    final costPrice = (item['cost_price'] as num).toDouble();
    final subtotal = (item['subtotal'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2, color: Colors.blue, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['product_name'] ?? 'غير معروف',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              'المخزون الحالي: ${item['current_stock']} ${item['base_unit']}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        subtitle: Text(
          'الكمية: $quantity',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.formatNumber(costPrice),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              Formatters.formatCurrency(subtotal),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final dateInfo = DateFormatter.formatDateTime(invoice['date']);
    final isCash = invoice['payment_type'] == 'cash';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'تفاصيل الفاتورة',
        showAppBar: false,
        child: Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'فاتورة #${invoice['id']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            'تفاصيل المشتريات',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isCash
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isCash
                                  ? Colors.green.shade200
                                  : Colors.orange.shade200,
                        ),
                      ),
                      child: Text(
                        isCash ? 'نقدي' : 'آجل',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isCash
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('جاري تحميل التفاصيل...'),
                            ],
                          ),
                        )
                        : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Invoice Info Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Supplier Info
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person_outline,
                                            color: Colors.blue,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'المورد',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                invoice['supplier_name'] ??
                                                    'غير محدد',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Invoice Details
                                    _buildDetailRow(
                                      'رقم الفاتورة',
                                      '#${invoice['id']}',
                                    ),
                                    _buildDetailRow(
                                      'التاريخ',
                                      dateInfo['full_datetime'] ?? '',
                                    ),
                                    _buildDetailRow(
                                      'الوقت',
                                      dateInfo['time_12'] ?? '',
                                    ),
                                    if (invoice['note']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ??
                                        false)
                                      _buildDetailRow(
                                        'ملاحظات',
                                        invoice['note'].toString(),
                                      ),

                                    const SizedBox(height: 16),
                                    Divider(color: Colors.grey.shade200),
                                    const SizedBox(height: 16),

                                    // Totals
                                    _buildDetailRow(
                                      'عدد المنتجات',
                                      _purchaseItems.length.toString(),
                                    ),
                                    _buildDetailRow(
                                      'المجموع الفرعي',
                                      Formatters.formatCurrency(_itemsTotal),
                                    ),
                                    _buildDetailRow(
                                      'المبلغ الإجمالي',
                                      Formatters.formatCurrency(
                                        invoice['total_cost'] ?? 0.0,
                                      ),
                                      isImportant: true,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Products Section
                              if (_purchaseItems.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.shopping_cart,
                                              color: Colors.green,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'المنتجات المشتراة',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${_purchaseItems.length} منتج',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'قائمة المنتجات التي تم شراؤها من المورد',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Products List
                                      ..._purchaseItems.asMap().entries.map((
                                        entry,
                                      ) {
                                        return _buildProductItemCard(
                                          entry.value,
                                          entry.key,
                                        );
                                      }).toList(),

                                      const SizedBox(height: 20),

                                      // Products Summary
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'المجموع الكلي للفاتورة',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  Formatters.formatCurrency(
                                                    invoice['total_cost'] ??
                                                        0.0,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'مجموع المنتجات',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  _purchaseItems.length
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('رجوع'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // طباعة الفاتورة
                        },
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('طباعة الفاتورة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
  }
}
