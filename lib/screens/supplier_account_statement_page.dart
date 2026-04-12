import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import '../providers/supplier_provider.dart';
import '../utils/formatters.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

class SupplierAccountStatementPage extends StatefulWidget {
  final int supplierId;
  final String supplierName;

  const SupplierAccountStatementPage({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierAccountStatementPage> createState() =>
      _SupplierAccountStatementPageState();
}

class _SupplierAccountStatementPageState
    extends State<SupplierAccountStatementPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _collectAmountController =
      TextEditingController();
  final TextEditingController _collectNoteController = TextEditingController();
  bool _isLoading = true;
  double _currentBalance = 0.0;
  bool _isLoadingMore = false;
  late List<Map<String, dynamic>> _transactions = [];
  bool _hasMore = true;
  int _totalTransactionsCount = 0;
  int? _hoveredRowIndex;
  Map<String, dynamic> _summary = const {
    'total_invoices': 0.0,
    'total_payments': 0.0,
    'total_collections': 0.0,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _collectAmountController.dispose();
    _collectNoteController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final provider = Provider.of<SupplierProvider>(context, listen: false);
      final totalCount = await provider.getTotalTransactionsCount(
        widget.supplierId,
      );

      final results = await Future.wait([
        provider.getSupplierBalance(widget.supplierId),
        provider.getSupplierTransactionsPage(
          widget.supplierId,
          limit: 20,
          offset: 0,
        ),
        provider.getSupplierSummary(widget.supplierId),
      ]);

      if (mounted) {
        setState(() {
          _currentBalance = results[0] as double;
          _transactions = results[1] as List<Map<String, dynamic>>;
          _summary = results[2] as Map<String, dynamic>;
          _totalTransactionsCount = totalCount;
          _isLoading = false;
          _hasMore = _transactions.length < _totalTransactionsCount;
        });
      }
    } catch (e) {
      log('خطأ في تحميل البيانات: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore ||
        !_hasMore ||
        _transactions.length >= _totalTransactionsCount) {
      return;
    }
    setState(() => _isLoadingMore = true);

    try {
      final provider = Provider.of<SupplierProvider>(context, listen: false);
      final moreTransactions = await provider.getSupplierTransactionsPage(
        widget.supplierId,
        limit: 20,
        offset: _transactions.length,
      );

      if (mounted) {
        setState(() {
          if (moreTransactions.isNotEmpty) {
            _transactions.addAll(moreTransactions);
          }
          _isLoadingMore = false;
          _hasMore = _transactions.length < _totalTransactionsCount;
        });
      }
    } catch (e) {
      log('خطأ في تحميل المزيد: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreTransactions();
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _transactions.clear();
      });
    }
    await _loadInitialData();
  }

  Future<void> _refreshStatementAfterMutation() async {
    final provider = Provider.of<SupplierProvider>(context, listen: false);

    try {
      final totalCount = await provider.getTotalTransactionsCount(
        widget.supplierId,
      );

      final results = await Future.wait([
        provider.getSupplierBalance(widget.supplierId),
        provider.getSupplierTransactionsPage(
          widget.supplierId,
          limit: 20,
          offset: 0,
        ),
        provider.getSupplierSummary(widget.supplierId),
      ]);

      if (!mounted) return;

      setState(() {
        _currentBalance = results[0] as double;
        _transactions = results[1] as List<Map<String, dynamic>>;
        _totalTransactionsCount = totalCount;
        _summary = results[2] as Map<String, dynamic>;
        _hasMore = _transactions.length < _totalTransactionsCount;
      });
    } catch (e) {
      log('خطأ في تحديث كشف المورد بعد العملية: $e');
    }
  }

  String _translatePaymentType(String? type) {
    if (type == null) return '';
    switch (type.toLowerCase()) {
      case 'cash':
        return 'نقدي';
      case 'credit':
        return 'آجال';
      case 'check':
        return 'شيك';
      case 'transfer':
        return 'تحويل';
      default:
        return type;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final arabicMonths = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      return '${date.day} ${arabicMonths[date.month - 1]} ${date.year}';
    } catch (e) {
      return Formatters.formatDate(dateString);
    }
  }

  String _formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour < 12 ? 'ص' : 'م';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${hour12.toString().padLeft(2, '0')}:$minute $period';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'كشف حساب ${widget.supplierName}',
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue.shade700),
            const SizedBox(height: 16),
            const Text('جاري تحميل البيانات...'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          _buildCompactHeader(),
          if (_currentBalance < 0) ...[
            const SizedBox(height: 12),
            _buildCollectCreditAction(),
          ],
          const SizedBox(height: 16),
          _buildSummaryBar(),
          const SizedBox(height: 16),
          _buildTransactionsTable(),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    final isDebt = _currentBalance > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDebt ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDebt ? Icons.arrow_upward : Icons.arrow_downward,
              color: isDebt ? Colors.red : Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.supplierName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDebt ? 'مستحق للمورد' : 'مستحق من المورد',
                  style: TextStyle(
                    color: isDebt ? Colors.red.shade700 : Colors.green.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.formatCurrency(_currentBalance.abs()),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDebt ? Colors.red : Colors.green,
                ),
              ),
              Text(
                'رصيد ${_transactions.length} حركة',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final totalInvoices =
        (_summary['total_invoices'] as num?)?.toDouble() ?? 0.0;
    final totalPayments =
        (_summary['total_payments'] as num?)?.toDouble() ?? 0.0;
    final totalCollections =
        (_summary['total_collections'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              'إجمالي المشتريات',
              totalInvoices,
              Colors.red.shade700,
              Icons.shopping_cart_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryItem(
              'إجمالي المدفوعات',
              totalPayments,
              Colors.green.shade700,
              Icons.payments_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryItem(
              'Ø§Ù„Ù…Ø³ØªØ±Ø¬Ø¹',
              totalCollections,
              Colors.teal.shade700,
              Icons.download_done_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    final resolvedTitle =
        icon == Icons.download_done_outlined ? 'المسترجع' : title;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        // ignore: deprecated_member_use
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolvedTitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.formatCurrency(amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectCreditAction() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.teal.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'يوجد لنا رصيد عند المورد. يمكنك تسجيل استرجاعه كحركة مستقلة.',
              style: TextStyle(
                color: Colors.teal.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _showCollectCreditDialog,
            icon: const Icon(Icons.download_done_outlined),
            label: const Text('استرجاع الرصيد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCollectCreditDialog() async {
    _collectAmountController.clear();
    _collectNoteController.text = 'استرجاع رصيد من المورد';
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('استرجاع رصيد من المورد'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرصيد المتاح للاسترجاع: ${Formatters.formatCurrency(_currentBalance.abs())}',
                        style: TextStyle(
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _collectAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'المبلغ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _collectNoteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isSubmitting
                            ? null
                            : () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isSubmitting
                            ? null
                            : () async {
                              final amount = double.tryParse(
                                _collectAmountController.text.trim(),
                              );

                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('يرجى إدخال مبلغ صحيح'),
                                  ),
                                );
                                return;
                              }

                              if (amount > _currentBalance.abs()) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'المبلغ أكبر من الرصيد المتاح',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isSubmitting = true);

                              try {
                                final provider = Provider.of<SupplierProvider>(
                                  this.context,
                                  listen: false,
                                );
                                await provider.collectSupplierCredit(
                                  supplierId: widget.supplierId,
                                  amount: amount,
                                  note:
                                      _collectNoteController.text.trim().isEmpty
                                          ? null
                                          : _collectNoteController.text.trim(),
                                );

                                if (!mounted) return;
                                // ignore: use_build_context_synchronously
                                Navigator.of(dialogContext).pop();
                                await _refreshStatementAfterMutation();
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تم تسجيل استرجاع الرصيد بنجاح',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                setDialogState(() => isSubmitting = false);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تعذر استرجاع الرصيد: ${e.toString()}',
                                    ),
                                  ),
                                );
                              }
                            },
                    child:
                        isSubmitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('تسجيل الحركة'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionsTable() {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            'النوع',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'البيان',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        if (constraints.maxWidth > 500)
                          Expanded(
                            child: Text(
                              'التاريخ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'المبلغ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        if (constraints.maxWidth > 600)
                          SizedBox(
                            width: 80,
                            child: Text(
                              'التفاصيل',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Table Body
                  Expanded(
                    child:
                        _transactions.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount:
                                  _transactions.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (_hasMore &&
                                    !_isLoadingMore &&
                                    index >= _transactions.length - 3 &&
                                    index < _transactions.length) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      _loadMoreTransactions();
                                    }
                                  });
                                }

                                if (index == _transactions.length) {
                                  return _buildLoadMoreIndicator();
                                }
                                return _buildTableRow(
                                  _transactions[index],
                                  index,
                                  constraints.maxWidth,
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableRow(
    Map<String, dynamic> transaction,
    int index,
    double maxWidth,
  ) {
    final type =
        transaction['type']
            as String; // 'purchase', 'payment', 'return', 'collection'
    final amount = (transaction['amount'] as num).toDouble();
    final date =
        transaction['date'] as String? ??
        transaction['created_at'] as String? ??
        '';
    final note = transaction['note'] as String? ?? '';
    final invoiceId = transaction['purchase_invoice_id'];
    final remainingAmount = transaction['remaining_amount'] as num?;
    final paymentType = transaction['payment_type'] as String?;

    // ✅ استخدم الألوان حسب النوع
    final typeColor = _getTransactionTypeColor(type);
    final typeBgColor = _getTransactionTypeBackgroundColor(type);
    final typeText = _getTransactionTypeText(type);
    final typeIcon = _getTransactionTypeIcon(type);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRowIndex = index),
      onExit: (_) => setState(() => _hoveredRowIndex = null),
      child: GestureDetector(
        onTap: () => _showTransactionDetails(transaction),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                _hoveredRowIndex == index
                    ? Colors.blue.shade50
                    : (index % 2 == 0 ? Colors.white : Colors.grey.shade50),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              // نوع الحركة (أيقونة)
              SizedBox(
                width: 40,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: typeBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              // البيان
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type == 'return' || type == 'collection'
                          ? '$typeText ${invoiceId != null ? '#$invoiceId' : ''}'
                          : type == 'purchase'
                          ? '$typeText ${invoiceId != null ? '#$invoiceId' : ''}'
                          : typeText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note.isNotEmpty)
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (maxWidth <= 500)
                      Text(
                        _formatDate(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              // التاريخ
              if (maxWidth > 500)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(date),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        _formatTime(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              // المبلغ
              SizedBox(
                width: 100,
                child: Text(
                  (type == 'payment'
                          ? '+ '
                          : type == 'collection'
                          ? '+ '
                          : type == 'return'
                          ? '- '
                          : '') +
                      Formatters.formatCurrency(amount),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color:
                        type == 'payment'
                            ? Colors.green.shade700
                            : type == 'collection'
                            ? Colors.teal.shade700
                            : type == 'return'
                            ? Colors.blue.shade700
                            : Colors.red.shade700,
                  ),
                ),
              ),
              // التفاصيل (للشاشات الكبيرة)
              if (maxWidth > 600)
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // للإرجاع
                      if (type == 'return')
                        Tooltip(
                          message: 'إرجاع للمورد',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'إرجاع',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // للفواتير المتبقي
                      if (type == 'purchase' &&
                          remainingAmount != null &&
                          remainingAmount > 0)
                        Tooltip(
                          message:
                              'متبقي: ${Formatters.formatCurrency(remainingAmount.toDouble())}',
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'متبقي',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // للفواتير طريقة الدفع
                      if (paymentType != null && type == 'purchase')
                        Tooltip(
                          message: _translatePaymentType(paymentType),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _translatePaymentType(paymentType),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple.shade800,
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

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    final type =
        transaction['type']
            as String; // 'purchase', 'payment', 'return', 'collection'
    final typeColor = _getTransactionTypeColor(type);
    final typeBgColor = _getTransactionTypeBackgroundColor(type);
    final typeText = _getTransactionTypeText(type);
    final typeIcon = _getTransactionTypeIcon(type);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: typeBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (transaction['purchase_invoice_id'] != null)
                            Text(
                              'رقم: ${transaction['purchase_invoice_id']}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      (type == 'payment'
                              ? '+ '
                              : type == 'collection'
                              ? '+ '
                              : type == 'return'
                              ? '- '
                              : '') +
                          Formatters.formatCurrency(
                            (transaction['amount'] as num).toDouble(),
                          ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                _buildDetailRow(
                  'التاريخ',
                  _formatDate(
                    transaction['date'] ?? transaction['created_at'] ?? '',
                  ),
                ),
                _buildDetailRow(
                  'الوقت',
                  _formatTime(
                    transaction['date'] ?? transaction['created_at'] ?? '',
                  ),
                ),
                if (type == 'purchase' && transaction['payment_type'] != null)
                  _buildDetailRow(
                    'طريقة الدفع',
                    _translatePaymentType(transaction['payment_type']),
                  ),
                if (type == 'purchase' &&
                    transaction['remaining_amount'] != null &&
                    (transaction['remaining_amount'] as num) > 0)
                  _buildDetailRow(
                    'المبلغ المتبقي',
                    Formatters.formatCurrency(
                      (transaction['remaining_amount'] as num).toDouble(),
                    ),
                  ),
                if (type == 'return' && transaction['note'] != null)
                  _buildDetailRow('سبب الإرجاع', transaction['note']),
                if (transaction['note'] != null &&
                    (transaction['note'] as String).isNotEmpty)
                  _buildDetailRow('ملاحظات', transaction['note']),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Color _getTransactionTypeColor(String type) {
    if (type == 'collection') {
      return Colors.teal.shade700;
    }
    switch (type) {
      case 'purchase':
        return Colors.red.shade700; // مشتريات - أحمر
      case 'payment':
        return Colors.green.shade700; // مدفوعات - أخضر
      case 'return':
        return Colors.blue.shade700; // إرجاع - أزرق (لون واضح)
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getTransactionTypeBackgroundColor(String type) {
    if (type == 'collection') {
      return Colors.teal.shade50;
    }
    switch (type) {
      case 'purchase':
        return Colors.red.shade50;
      case 'payment':
        return Colors.green.shade50;
      case 'return':
        return Colors.blue.shade50; // إرجاع - أزرق فاتح
      default:
        return Colors.grey.shade50;
    }
  }

  String _getTransactionTypeText(String type) {
    if (type == 'collection') {
      return 'استرجاع رصيد';
    }
    switch (type) {
      case 'purchase':
        return 'فاتورة شراء';
      case 'payment':
        return 'دفعة مالية';
      case 'return':
        return 'إرجاع للمورد'; // إرجاع
      default:
        return 'حركة';
    }
  }

  IconData _getTransactionTypeIcon(String type) {
    if (type == 'collection') {
      return Icons.download_done_outlined;
    }
    switch (type) {
      case 'purchase':
        return Icons.shopping_cart_outlined;
      case 'payment':
        return Icons.payments_outlined;
      case 'return':
        return Icons.assignment_return; // أيقونة الإرجاع
      default:
        return Icons.receipt_outlined;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!_hasMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          'نهاية الكشف',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child:
          _isLoadingMore
              ? CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue.shade700,
              )
              : InkWell(
                onTap: _loadMoreTransactions,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.expand_more, color: Colors.grey.shade400),
                ),
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'لا توجد حركات',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
