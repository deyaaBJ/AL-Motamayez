// screens/sales_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/providers/auth_provider.dart';
import '../providers/sales_provider.dart';
import '../widgets/SaleDetailsDialog.dart';
import '../models/sale.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // أول تحميل
    Future.microtask(() => context.read<SalesProvider>().fetchSales());

    // مراقبة التمرير لعمل lazy load
    _scrollController.addListener(() {
      final provider = context.read<SalesProvider>();
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !provider
              .isLoading && // <-- تم التغيير هنا: استخدم isLoading بدل _isLoading
          provider.hasMore) {
        provider.fetchSales(loadMore: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'سجل الفواتير',
          style: TextStyle(
            fontWeight: FontWeight.w700, // أكثر سماكة
            fontSize: 20, // أكبر
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // الفلاتر المدمجة والصغيرة
          _buildCompactFiltersSection(),
          const SizedBox(height: 12), // مسافة أكبر
          // جدول الفواتير
          Expanded(child: _buildSalesTable()),
        ],
      ),
    );
  }

  Widget _buildCompactFiltersSection() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.role;

    return Consumer<SalesProvider>(
      builder: (context, provider, _) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // الفلاتر في صف واحد
              Row(
                children: [
                  Expanded(child: _buildCompactPaymentFilter(provider)),
                  const SizedBox(width: 12),

                  Expanded(child: _buildCompactCustomerFilter(provider)),
                  const SizedBox(width: 12),

                  Expanded(child: _buildCompactDateFilter(provider)),
                  const SizedBox(width: 12),

                  if (role != 'tax') ...[
                    Expanded(child: _buildCompactTaxFilter(provider)),
                    const SizedBox(width: 12),
                  ],

                  _buildCompactClearButton(provider),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactTaxFilter(SalesProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع الضريبة',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: provider.selectedTaxFilter,
              items: [
                DropdownMenuItem(
                  value: 'الكل',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'الكل',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'مضمنه بالضرائب',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'مضمنه بالضرائب',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'غير مضمنه بالضرائب',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'غير مضمنه بالضرائب',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              onChanged: provider.setTaxFilter,
              icon: Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: Colors.grey[600],
              ),
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactPaymentFilter(SalesProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع البيع',
          style: TextStyle(
            fontSize: 14, // أكبر
            color: Colors.grey[700],
            fontWeight: FontWeight.w600, // أكثر سماكة
          ),
        ),
        const SizedBox(height: 6), // مسافة أكبر
        Container(
          height: 42, // أعلى قليلاً
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: provider.selectedPaymentType,
              items:
                  provider.paymentTypes.map((String type) {
                    String displayText = type;
                    if (type == 'cash') {
                      displayText = 'نقدي';
                    } else if (type == 'credit') {
                      displayText = 'آجل';
                    }
                    return DropdownMenuItem(
                      value: type,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ), // مسافة أكبر
                        child: Text(
                          displayText,
                          style: const TextStyle(
                            fontSize: 14, // أكبر
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: provider.setPaymentTypeFilter,
              icon: Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: Colors.grey[600],
              ), // أيقونة أكبر
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCustomerFilter(SalesProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المشتري',
          style: TextStyle(
            fontSize: 14, // أكبر
            color: Colors.grey[700],
            fontWeight: FontWeight.w600, // أكثر سماكة
          ),
        ),
        const SizedBox(height: 6), // مسافة أكبر
        Container(
          height: 42, // أعلى قليلاً
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: provider.selectedCustomer,
              items:
                  provider.customerNames.map((String name) {
                    return DropdownMenuItem(
                      value: name,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ), // مسافة أكبر
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14, // أكبر
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: provider.setCustomerFilter,
              icon: Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: Colors.grey[600],
              ), // أيقونة أكبر
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDateFilter(SalesProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التاريخ',
          style: TextStyle(
            fontSize: 14, // أكبر
            color: Colors.grey[700],
            fontWeight: FontWeight.w600, // أكثر سماكة
          ),
        ),
        const SizedBox(height: 6), // مسافة أكبر
        GestureDetector(
          onTap: () => _selectDate(context, provider),
          child: Container(
            height: 42, // أعلى قليلاً
            padding: const EdgeInsets.symmetric(horizontal: 12), // مسافة أكبر
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getDateText(provider),
                  style: TextStyle(
                    fontSize: 14, // أكبر
                    fontWeight: FontWeight.w500,
                    color:
                        provider.selectedDate == null
                            ? Colors.grey[500]
                            : Colors.black87,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.grey[600],
                ), // أيقونة أكبر
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactClearButton(SalesProvider provider) {
    return Column(
      children: [
        const SizedBox(height: 24), // للمحاذاة مع الحقول
        Container(
          height: 42, // أعلى قليلاً
          child: OutlinedButton(
            onPressed: provider.clearFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[400]!),
              padding: const EdgeInsets.symmetric(horizontal: 16), // مسافة أكبر
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Icon(Icons.clear, size: 20), // أيقونة أكبر
          ),
        ),
      ],
    );
  }

  String _getDateText(SalesProvider provider) {
    if (provider.selectedDate == null) {
      return 'اختر التاريخ';
    }
    final date = provider.selectedDate!;
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectDate(BuildContext context, SalesProvider provider) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      provider.setDateFilter(picked);
    }
  }

  Widget _buildSalesTable() {
    return Consumer<SalesProvider>(
      builder: (context, provider, _) {
        if (provider.sales.isEmpty && !provider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 70, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'لا توجد فواتير',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                controller: _scrollController, // ✅ هنا الكنترولر للـ Lazy Load
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    DataTable(
                      headingRowColor:
                          MaterialStateProperty.resolveWith<Color?>(
                            (Set<MaterialState> states) => Colors.blue[50],
                          ),
                      dataRowMaxHeight: 56,
                      dataRowMinHeight: 48,
                      headingTextStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                        fontSize: 15,
                      ),
                      dataTextStyle: const TextStyle(fontSize: 14),
                      columnSpacing: 70,
                      horizontalMargin: 20,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'رقم الفاتورة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'العميل',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'المبلغ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'الربح',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'النوع',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'التاريخ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'الوقت',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows:
                          provider.sales.asMap().entries.map((entry) {
                            final index = entry.key; // رقم تسلسلي (0,1,2,...)
                            final sale = entry.value; // عنصر الفاتورة

                            return DataRow(
                              onSelectChanged:
                                  (_) => _showSaleDetails(sale.id, context),
                              cells: [
                                DataCell(
                                  Text(
                                    (index + 1)
                                        .toString(), // الرقم التسلسلي بدل sale.id
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    sale.customerName ?? "بدون عميل",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${sale.totalAmount.toStringAsFixed(0)} ل.س',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${sale.totalProfit.toStringAsFixed(0)} ل.س',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPaymentTypeColor(
                                        sale.paymentType,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      sale.paymentType == 'cash'
                                          ? 'نقدي'
                                          : 'آجل',
                                      style: TextStyle(
                                        color: _getPaymentTypeColor(
                                          sale.paymentType,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    sale.formattedDate,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    sale.formattedTime,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: Icon(
                                      Icons.visibility,
                                      size: 20,
                                      color: Colors.blue[600],
                                    ),
                                    onPressed:
                                        () =>
                                            _showSaleDetails(sale.id, context),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),

                    // ✅ مؤشر التحميل في نهاية الجدول
                    if (provider.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    // ✅ رسالة عند انتهاء جميع الفواتير
                    if (!provider.hasMore && !provider.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'تم تحميل جميع الفواتير ✅',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getPaymentTypeColor(String paymentType) {
    switch (paymentType) {
      case 'cash':
        return Colors.green;
      case 'credit':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _showSaleDetails(int saleId, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SaleDetailsDialog(saleId: saleId),
    );
  }
}
