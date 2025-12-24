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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final provider = context.read<PurchaseInvoiceProvider>();

    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore &&
        provider.hasMore) {
      _loadMoreInvoices();
    }
  }

  Future<void> _loadInvoices() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await context.read<PurchaseInvoiceProvider>().refreshInvoices();
    } catch (e) {
      _showSnackBar('خطأ في تحميل الفواتير: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchInvoices() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await context.read<PurchaseInvoiceProvider>().searchInvoices(
        _searchQuery,
      );
    } catch (e) {
      _showSnackBar('خطأ في البحث: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreInvoices() async {
    final provider = context.read<PurchaseInvoiceProvider>();

    // تحقق إذا كان هناك المزيد للتحميل
    if (_isLoadingMore || !provider.hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      await provider.loadMoreInvoices();
    } catch (e) {
      _showSnackBar('خطأ في تحميل المزيد: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _refreshInvoices() async {
    await _loadInvoices();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editInvoice(Map<String, dynamic> invoice) async {
    final TextEditingController noteController = TextEditingController(
      text: invoice['note']?.toString() ?? '',
    );
    String paymentType = invoice['payment_type'] ?? 'cash';

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تعديل طريقة الدفع'),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // نقدي
                      ChoiceChip(
                        label: const Text('نقدي'),
                        selected: paymentType == 'cash',
                        onSelected: (selected) {
                          setState(() {
                            paymentType = 'cash';
                          });
                        },
                        selectedColor: Colors.green,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      const SizedBox(width: 20),
                      // آجل
                      ChoiceChip(
                        label: const Text('آجل (دين)'),
                        selected: paymentType == 'credit',
                        onSelected: (selected) {
                          setState(() {
                            paymentType = 'credit';
                          });
                        },
                        selectedColor: Colors.orange,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'ملاحظات',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await context
                        .read<PurchaseInvoiceProvider>()
                        .updatePurchaseInvoice(
                          invoiceId: invoice['id'],
                          paymentType: paymentType,
                          note: noteController.text,
                        );
                    _showSnackBar('تم تحديث الفاتورة', Colors.green);
                    Navigator.pop(context, true);
                  } catch (e) {
                    _showSnackBar('خطأ: $e', Colors.red);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('حفظ'),
              ),
            ],
          ),
    );

    if (result == true) {
      await _refreshInvoices();
    }
  }

  Future<void> _deleteInvoice(Map<String, dynamic> invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل تريد حذف الفاتورة #${invoice['id']}؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لا'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('نعم'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await context.read<PurchaseInvoiceProvider>().deletePurchaseInvoice(
        invoice['id'],
      );
      _showSnackBar('تم حذف الفاتورة', Colors.green);
      await _refreshInvoices();
    } catch (e) {
      _showSnackBar('خطأ في الحذف: $e', Colors.red);
    }
  }

  Widget _buildHeader() {
    final provider = context.watch<PurchaseInvoiceProvider>();
    final invoices = provider.invoices;
    final totalAmount = invoices.fold<double>(
      0,
      (sum, invoice) => sum + (invoice['total_cost'] ?? 0.0),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.blue, size: 32),
              const SizedBox(width: 10),
              Column(
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
                  Text(
                    '${invoices.length} فاتورة - ${Formatters.formatCurrency(totalAmount)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshInvoices,
                tooltip: 'تحديث',
              ),
            ],
          ),
          const SizedBox(height: 10),
          // شريط البحث
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'ابحث برقم الفاتورة أو اسم المورد...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _searchInvoices();
                        },
                      )
                      : null,
            ),
            onChanged: (value) {
              // تحديث قيمة البحث عند كل تغيير
              setState(() => _searchQuery = value);
            },
            onSubmitted: (value) {
              // عند الضغط على زر البحث
              _searchInvoices();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: const Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: _buildHeaderCell('رقم الفاتورة')),
          Expanded(flex: 2, child: _buildHeaderCell('التاريخ')),
          Expanded(flex: 2, child: _buildHeaderCell('المورد')),
          Expanded(flex: 2, child: _buildHeaderCell('المبلغ')),
          Expanded(flex: 2, child: _buildHeaderCell('طريقة الدفع')),
          Expanded(flex: 3, child: _buildHeaderCell('الإجراءات')),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> invoice, int index) {
    final dateInfo = DateFormatter.formatDateTime(invoice['date']);
    final isCash = invoice['payment_type'] == 'cash';
    final totalAmount = invoice['total_cost'] ?? 0.0;

    return Container(
      color: index.isEven ? Colors.white : Colors.grey.shade50,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // رقم الفاتورة
                Expanded(
                  flex: 1,
                  child: Text(
                    '#${invoice['id']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // التاريخ
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dateInfo['short_date'] ?? '',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dateInfo['time_12'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // المورد
                Expanded(
                  flex: 2,
                  child: Text(
                    invoice['supplier_name'] ?? '-',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // المبلغ
                Expanded(
                  flex: 2,
                  child: Text(
                    Formatters.formatCurrency(totalAmount),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // طريقة الدفع
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _editInvoice(invoice),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isCash
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isCash ? Colors.green : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isCash ? 'نقدي' : 'آجل',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCash ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                // الإجراءات
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 18),
                        color: Colors.blue,
                        onPressed: () {
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
                        tooltip: 'عرض التفاصيل',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: Colors.orange,
                        onPressed: () => _editInvoice(invoice),
                        tooltip: 'تعديل',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        color: Colors.red,
                        onPressed: () => _deleteInvoice(invoice),
                        tooltip: 'حذف',
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

  Widget _buildLoadingMore() {
    final provider = context.watch<PurchaseInvoiceProvider>();

    if (!_isLoadingMore && !provider.hasMore) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(child: Text('تم عرض جميع الفواتير')),
      );
    }

    if (!_isLoadingMore) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildContent() {
    final provider = context.watch<PurchaseInvoiceProvider>();
    final invoices = provider.invoices;

    if (_isLoading && invoices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل الفواتير...'),
          ],
        ),
      );
    }

    if (invoices.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isEmpty ? 'لا توجد فواتير' : 'لا توجد نتائج',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isEmpty
                  ? 'إبدأ بإنشاء أول فاتورة شراء'
                  : 'جرب كلمات بحث أخرى',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshInvoices,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isSmallScreen = constraints.maxWidth < 768;

          if (isSmallScreen) {
            // عرض مبسط للشاشات الصغيرة
            return ListView.builder(
              controller: _scrollController,
              itemCount: invoices.length + 1,
              itemBuilder: (context, index) {
                if (index == invoices.length) {
                  return _buildLoadingMore();
                }
                return _buildMobileInvoiceCard(invoices[index], index);
              },
            );
          } else {
            // عرض الجدول للشاشات الكبيرة
            return ListView.builder(
              controller: _scrollController,
              itemCount: invoices.length + 1,
              itemBuilder: (context, index) {
                if (index == invoices.length) {
                  return _buildLoadingMore();
                }
                return _buildTableRow(invoices[index], index);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildMobileInvoiceCard(Map<String, dynamic> invoice, int index) {
    final dateInfo = DateFormatter.formatDateTime(invoice['date']);
    final isCash = invoice['payment_type'] == 'cash';
    final totalAmount = invoice['total_cost'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.all(8),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: رقم الفاتورة والتاريخ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${invoice['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    dateInfo['short_date'] ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // الصف الثاني: المورد
              Text(
                'المورد: ${invoice['supplier_name'] ?? '-'}',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // الصف الثالث: المبلغ وطريقة الدفع
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.formatCurrency(totalAmount),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isCash ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCash ? Colors.green : Colors.orange,
                      ),
                    ),
                    child: Text(
                      isCash ? 'نقدي' : 'آجل',
                      style: TextStyle(
                        color: isCash ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // الصف الرابع: الإجراءات
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 20),
                    color: Colors.blue,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  PurchaseInvoiceDetailsPage(invoice: invoice),
                        ),
                      );
                    },
                    tooltip: 'عرض التفاصيل',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.orange,
                    onPressed: () => _editInvoice(invoice),
                    tooltip: 'تعديل',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                    onPressed: () => _deleteInvoice(invoice),
                    tooltip: 'حذف',
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
        currentPage: 'فواتير الشراء',
        showAppBar: false,
        child: Scaffold(
          body: Column(
            children: [
              _buildHeader(),
              // رأس الجدول يظهر فقط في الشاشات الكبيرة
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 768) {
                    return const SizedBox.shrink();
                  }
                  return _buildTableHeader();
                },
              ),
              Expanded(child: _buildContent()),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/purchase-invoice');
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
