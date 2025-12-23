// screens/purchase_invoices_list_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/providers/purchase_invoice_provider.dart';
import 'package:shopmate/screens/purchase_invoice_details_page.dart';
import 'package:shopmate/utils/formatters.dart';
import 'package:shopmate/utils/date_formatter.dart';

class PurchaseInvoicesListPage extends StatefulWidget {
  const PurchaseInvoicesListPage({super.key});

  @override
  State<PurchaseInvoicesListPage> createState() =>
      _PurchaseInvoicesListPageState();
}

class _PurchaseInvoicesListPageState extends State<PurchaseInvoicesListPage> {
  // ألوان متناسقة
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _secondaryColor = Color(0xFF64748B);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _cardColor = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await context.read<PurchaseInvoiceProvider>().loadPurchaseInvoices();
    } catch (e) {
      _showSnackBar('خطأ في تحميل الفواتير: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _deleteInvoice(Map<String, dynamic> invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDeleteDialog(invoice),
    );

    if (confirm != true) return;

    try {
      await context.read<PurchaseInvoiceProvider>().deletePurchaseInvoice(
        invoice['id'],
      );
      _showSnackBar('تم حذف الفاتورة #${invoice['id']}', _successColor);
    } catch (e) {
      _showSnackBar('خطأ في الحذف: $e', Colors.red);
    }
  }

  AlertDialog _buildDeleteDialog(Map<String, dynamic> invoice) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'حذف الفاتورة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'هل أنت متأكد من حذف الفاتورة #${invoice['id']}؟',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'حذف',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final dateInfo = DateFormatter.formatDateTime(invoice['date']);
    final isCash = invoice['payment_type'] == 'cash';
    final totalAmount = invoice['total_cost'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => PurchaseInvoiceDetailsPage(invoice: invoice),
              ),
            );
          },
          splashColor: _primaryColor.withOpacity(0.1),
          highlightColor: _primaryColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العلامة الجانبية
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isCash ? _successColor : _warningColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),

                // محتوى البطاقة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الصف العلوي: رقم الفاتورة والمبلغ
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    color: _primaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '#${invoice['id']}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                invoice['supplier_name'] ?? 'غير معروف',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Formatters.formatCurrency(totalAmount),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _successColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isCash
                                          ? _successColor.withOpacity(0.1)
                                          : _warningColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isCash ? 'نقدي' : 'آجل',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isCash ? _successColor : _warningColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // الصف السفلي: التاريخ والإجراءات
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateInfo['short_date'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateInfo['time_12'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildActionButton(
                                icon: Icons.remove_red_eye,
                                color: _primaryColor,
                                onTap: () => _showInvoiceDialog(invoice),
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                icon: Icons.delete_outline,
                                color: Colors.red,
                                onTap: () => _deleteInvoice(invoice),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInvoiceDialog(Map<String, dynamic> invoice) {
    final dateInfo = DateFormatter.formatDateTime(invoice['date']);

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_primaryColor, _primaryColor.withOpacity(0.9)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.white,
                            size: 28,
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
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateInfo['full_datetime'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Details
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildDetailItem(
                          'المورد',
                          invoice['supplier_name'] ?? '-',
                        ),
                        _buildDetailItem(
                          'طريقة الدفع',
                          invoice['payment_type'] == 'cash' ? 'نقدي' : 'آجل',
                          isCash: invoice['payment_type'] == 'cash',
                        ),
                        _buildDetailItem(
                          'المبلغ الإجمالي',
                          Formatters.formatCurrency(
                            invoice['total_cost'] ?? 0.0,
                          ),
                          isAmount: true,
                        ),
                        if (invoice['note']?.toString().trim().isNotEmpty ??
                            false)
                          _buildDetailItem(
                            'الملاحظات',
                            invoice['note'].toString(),
                            isNote: true,
                          ),
                      ],
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('إغلاق'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => PurchaseInvoiceDetailsPage(
                                        invoice: invoice,
                                      ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('تفاصيل كاملة'),
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

  Widget _buildDetailItem(
    String label,
    String value, {
    bool isCash = false,
    bool isAmount = false,
    bool isNote = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textSecondary,
              ),
            ),
          ),
          Expanded(
            child:
                isNote
                    ? Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.right,
                    )
                    : isAmount
                    ? Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _successColor,
                      ),
                      textAlign: TextAlign.right,
                    )
                    : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isCash
                                ? _successColor.withOpacity(0.1)
                                : _warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCash ? _successColor : _warningColor,
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final invoices = context.watch<PurchaseInvoiceProvider>().invoices;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فواتير الشراء',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'إدارة وتتبع جميع فواتير الشراء',
                      style: TextStyle(fontSize: 14, color: _textSecondary),
                    ),
                  ],
                ),
              ),
              if (isDesktop) _buildStatsRow(invoices),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: _textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    focusNode: _searchFocusNode,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم الفاتورة أو اسم المورد...',
                      hintStyle: TextStyle(color: _textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(fontSize: 14, color: _textPrimary),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, color: _textSecondary, size: 18),
                    onPressed: () {
                      setState(() => _searchQuery = '');
                      _searchFocusNode.unfocus();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<Map<String, dynamic>> invoices) {
    final totalAmount = invoices.fold<double>(
      0,
      (sum, invoice) => sum + (invoice['total_cost'] ?? 0.0),
    );

    return Row(
      children: [
        _buildStatItem('${invoices.length}', 'فواتير', _primaryColor),
        const SizedBox(width: 20),
        _buildStatItem(
          Formatters.formatCurrency(totalAmount),
          'إجمالي',
          _successColor,
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: _textSecondary)),
      ],
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> invoices) {
    if (_isLoading && invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'جاري تحميل الفواتير...',
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
      );
    }

    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              'لا توجد فواتير',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بإنشاء أول فاتورة شراء',
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
      );
    }

    // تصفية النتائج حسب البحث
    final filteredInvoices =
        _searchQuery.isEmpty
            ? invoices
            : invoices.where((invoice) {
              final invoiceId = invoice['id'].toString();
              final supplierName =
                  invoice['supplier_name']?.toString().toLowerCase() ?? '';
              final searchLower = _searchQuery.toLowerCase();
              return invoiceId.contains(searchLower) ||
                  supplierName.contains(searchLower);
            }).toList();

    if (filteredInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرب كلمات بحث مختلفة',
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvoices,
      color: _primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: filteredInvoices.length,
          itemBuilder: (context, index) {
            return _buildInvoiceCard(filteredInvoices[index]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoices = context.watch<PurchaseInvoiceProvider>().invoices;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'فواتير الشراء',
        showAppBar: false,
        child: Scaffold(
          backgroundColor: _cardColor,
          body: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildContent(invoices)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/purchase-invoice');
            },
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: const Icon(Icons.add, size: 24),
          ),
        ),
      ),
    );
  }
}
