import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/providers/purchase_invoice_provider.dart';
import 'package:motamayez/screens/purchase_invoice_details_page.dart';
import 'dart:developer';

class PurchaseInvoicesListPage extends StatefulWidget {
  const PurchaseInvoicesListPage({super.key});

  @override
  State<PurchaseInvoicesListPage> createState() =>
      _PurchaseInvoicesListPageState();
}

class _PurchaseInvoicesListPageState extends State<PurchaseInvoicesListPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  Timer? _searchTimer;
  String _lastSearchQuery = '';

  // دالة لتنسيق العملة
  String _formatCurrency(double amount) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
    return '${amount.toStringAsFixed(2)} $currencyName';
  }

  // دالة لتنسيق التاريخ
  Map<String, String> _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final year = date.year;
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return {'short_date': '$year/$month/$day', 'time_12': '$hour:$minute'};
    } catch (e) {
      return {'short_date': dateString, 'time_12': ''};
    }
  }

  @override
  void initState() {
    super.initState();

    // تأجيل إعادة تعيين البحث حتى تكتمل عملية البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resetSearch();
      }
    });

    // إعداد listener للتمرير
    _scrollController.addListener(_scrollListener);

    // إعداد listener لحقل البحث
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // تأجيل تحميل الفواتير حتى تكتمل عملية البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final provider = Provider.of<PurchaseInvoiceProvider>(
        context,
        listen: false,
      );

      // تحميل الفواتير أول مرة فقط إذا لم تكن محملة
      if (provider.invoices.isEmpty && !provider.isLoading) {
        _loadInvoices(provider);
      }
    });
  }

  void _scrollListener() {
    if (!mounted) return;

    final provider = Provider.of<PurchaseInvoiceProvider>(
      context,
      listen: false,
    );

    if (!provider.hasMore || provider.isLoading) return;

    // تحميل المزيد عندما نصل لنهاية الصفحة
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMoreInvoices(provider);
    }
  }

  void _onSearchChanged() {
    // إلغاء أي عملية بحث سابقة
    _searchTimer?.cancel();

    final query = _searchController.text.trim();

    // تحديث query المحلية
    setState(() {
      _searchQuery = query;
    });

    // إذا كان البحث فارغاً، إعادة تحميل الكل فوراً
    if (query.isEmpty) {
      _searchInvoices();
      return;
    }

    // إجراء البحث بعد تأخير 500 مللي ثانية
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _searchInvoices();
      }
    });
  }

  Future<void> _loadInvoices(PurchaseInvoiceProvider provider) async {
    try {
      await provider.refreshInvoices();
    } catch (e) {
      if (mounted) {
        log('خطأ في تحميل الفواتير: $e');
        _showSnackBar('خطأ في تحميل الفواتير: ${e.toString()}', Colors.red);
      }
    }
  }

  Future<void> _searchInvoices() async {
    final query = _searchController.text.trim();

    // إذا كان نفس البحث السابق، تخطي
    if (query == _lastSearchQuery) {
      log('⏭️ نفس البحث السابق، تخطي');
      return;
    }

    _lastSearchQuery = query;

    final provider = Provider.of<PurchaseInvoiceProvider>(
      context,
      listen: false,
    );

    log('🚀 تنفيذ البحث: "$query"');

    try {
      await provider.searchInvoices(query);
    } catch (e) {
      if (mounted) {
        log('❌ خطأ في البحث: $e');
        _showSnackBar('خطأ في البحث: ${e.toString()}', Colors.red);
      }
    }
  }

  Future<void> _loadMoreInvoices(PurchaseInvoiceProvider provider) async {
    try {
      await provider.loadMoreInvoices();
    } catch (e) {
      if (mounted) {
        log('خطأ في تحميل المزيد: $e');
        _showSnackBar('خطأ في تحميل المزيد: ${e.toString()}', Colors.red);
      }
    }
  }

  // دالة لإعادة تعيين البحث وعرض جميع الفواتير
  Future<void> _resetSearch() async {
    _searchController.clear();
    _lastSearchQuery = '';
    setState(() => _searchQuery = '');

    // تأجيل التنفيذ حتى تكتمل عملية البناء
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final provider = Provider.of<PurchaseInvoiceProvider>(
        context,
        listen: false,
      );

      // إعادة تعيين البحث
      await provider.resetSearch();
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildHeader(PurchaseInvoiceProvider provider) {
    final invoices = provider.invoices;
    final totalAmount = invoices.fold<double>(
      0,
      (sum, invoice) => sum + (invoice['total_cost'] ?? 0.0),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'فواتير الشراء',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${invoices.length} فاتورة - ${_formatCurrency(totalAmount)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadInvoices(provider),
                tooltip: 'تحديث',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // شريط البحث
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'ابحث برقم الفاتورة أو اسم المورد...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: _resetSearch,
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onSubmitted: (value) {
              _searchInvoices();
              _searchFocusNode.unfocus();
            },
          ),
          const SizedBox(height: 10),
          if (_searchQuery.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _resetSearch,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('عرض الكل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: BorderSide(color: Colors.orange.shade300),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: const Border(bottom: BorderSide(color: Colors.grey, width: 1)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: _buildHeaderCell('رقم الفاتورة')),
          Expanded(flex: 2, child: _buildHeaderCell('التاريخ')),
          Expanded(flex: 2, child: _buildHeaderCell('المورد')),
          Expanded(flex: 2, child: _buildHeaderCell('المبلغ')),
          Expanded(flex: 2, child: _buildHeaderCell('طريقة الدفع')),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    PurchaseInvoiceProvider provider,
    Map<String, dynamic> invoice,
    int index,
  ) {
    final dateInfo = _formatDateTime(invoice['date']?.toString() ?? '');
    final isCash = invoice['payment_type'] == 'cash';
    final totalAmount = invoice['total_cost'] ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        border: const Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => PurchaseInvoiceDetailsPage(invoice: invoice),
              ),
            );
          },
          hoverColor: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // رقم الفاتورة
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '#${invoice['id']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // التاريخ
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          dateInfo['short_date'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateInfo['time_12'] ?? '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // المورد
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      invoice['supplier_name']?.toString() ?? 'غير محدد',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // المبلغ
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _formatCurrency(totalAmount),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // طريقة الدفع
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isCash
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                isCash
                                    ? Colors.green.shade300
                                    : Colors.orange.shade300,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isCash ? 'نقدي' : 'آجل',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isCash
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),

                // الإجراءات
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMore(PurchaseInvoiceProvider provider) {
    if (!provider.hasMore && provider.invoices.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'تم عرض جميع الفواتير',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ),
      );
    }

    if (!provider.isLoading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    );
  }

  Widget _buildContent(PurchaseInvoiceProvider provider) {
    final invoices = provider.invoices;

    if (provider.isLoading && invoices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 16),
            Text(
              'جاري تحميل الفواتير...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (invoices.isEmpty && !provider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isEmpty ? 'لا توجد فواتير' : 'لا توجد نتائج',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isEmpty
                  ? 'إبدأ بإنشاء أول فاتورة شراء'
                  : 'جرب كلمات بحث أخرى',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            if (_searchQuery.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/purchaseInvoice');
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إنشاء فاتورة جديدة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            if (_searchQuery.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _resetSearch,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('عرض جميع الفواتير'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmallScreen = constraints.maxWidth < 768;

        if (isSmallScreen) {
          return ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: invoices.length + 1,
            itemBuilder: (context, index) {
              if (index == invoices.length) {
                return _buildLoadingMore(provider);
              }
              return _buildMobileInvoiceCard(provider, invoices[index], index);
            },
          );
        } else {
          return Column(
            children: [
              // رأس الجدول
              _buildTableHeader(),
              // محتوى الجدول
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: invoices.length + 1,
                  itemBuilder: (context, index) {
                    if (index == invoices.length) {
                      return _buildLoadingMore(provider);
                    }
                    return _buildTableRow(provider, invoices[index], index);
                  },
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildMobileInvoiceCard(
    PurchaseInvoiceProvider provider,
    Map<String, dynamic> invoice,
    int index,
  ) {
    final dateInfo = _formatDateTime(invoice['date']?.toString() ?? '');
    final isCash = invoice['payment_type'] == 'cash';
    final totalAmount = invoice['total_cost'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PurchaseInvoiceDetailsPage(invoice: invoice),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${invoice['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                  Text(
                    dateInfo['short_date'] ?? '',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'المورد: ${invoice['supplier_name'] ?? 'غير محدد'}',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: Colors.green.shade500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatCurrency(totalAmount),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isCash ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color:
                            isCash
                                ? Colors.green.shade300
                                : Colors.orange.shade300,
                      ),
                    ),
                    child: Text(
                      isCash ? 'نقدي' : 'آجل',
                      style: TextStyle(
                        color:
                            isCash
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'الفواتير',
        child: Scaffold(
          body: Consumer<PurchaseInvoiceProvider>(
            builder: (context, provider, child) {
              return Column(
                children: [
                  _buildHeader(provider),
                  Expanded(child: _buildContent(provider)),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/purchaseInvoice');
            },
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: 4,
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
    );
  }
}
