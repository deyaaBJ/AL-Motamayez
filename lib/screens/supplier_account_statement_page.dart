import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import '../providers/supplier_provider.dart';
import '../utils/formatters.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;

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
  bool _isLoading = true;
  double _currentBalance = 0.0;
  int _totalTransactions = 0;
  bool _isLoadingMore = false;
  late List<Map<String, dynamic>> _transactions = [];
  bool _hasMore = true;
  bool _isLoadingTransactions = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_scrollListener);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final provider = Provider.of<SupplierProvider>(context, listen: false);

      // تحميل البيانات بالتوازي
      final results = await Future.wait([
        provider.getSupplierBalance(widget.supplierId),
        provider.getSupplierTransactions(widget.supplierId),
        provider.getTotalTransactionsCount(widget.supplierId),
      ]);

      final transactions = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _currentBalance = results[0] as double;
          _transactions = transactions;
          _totalTransactions = results[2] as int;
          _isLoading = false;
          _hasMore = provider.hasMoreTransactions(widget.supplierId);
        });
      }
    } catch (e) {
      print('خطأ في تحميل البيانات: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final provider = Provider.of<SupplierProvider>(context, listen: false);
      final moreTransactions = await provider.getSupplierTransactions(
        widget.supplierId,
        loadMore: true,
      );

      if (mounted) {
        setState(() {
          _transactions.addAll(moreTransactions);
          _isLoadingMore = false;
          _hasMore = provider.hasMoreTransactions(widget.supplierId);
        });
      }
    } catch (e) {
      print('خطأ في تحميل المزيد من الحركات: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
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
    final provider = Provider.of<SupplierProvider>(context, listen: false);
    provider.resetTransactionsPagination(widget.supplierId);

    if (mounted) {
      setState(() {
        _isLoading = true;
        _transactions.clear();
      });
    }

    await _loadInitialData();
  }

  // دالة لترجمة نوع الدفع
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

  // دالة جديدة لتنسيق التاريخ والوقت بشكل أفضل
  String _formatDateTime(String dateString) {
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

      final month = arabicMonths[date.month - 1];
      final day = date.day;
      final year = date.year;
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour < 12 ? 'صباحاً' : 'مساءً';
      final hour12 = hour > 12 ? hour - 12 : hour;

      return '$day $month $year - ${hour12 == 0 ? 12 : hour12}:$minute $period';
    } catch (e) {
      return Formatters.formatDate(dateString);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: m.TextDirection.rtl,
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
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل البيانات...'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshData();
      },
      child: Column(
        children: [
          _buildHeader(),
          SizedBox(height: 16),
          _buildSummaryCards(),
          SizedBox(height: 16),
          _buildTransactionsSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person_outline, size: 32, color: Colors.blue),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.supplierName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'رقم المورد: ${widget.supplierId}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _refreshData,
              icon: Icon(Icons.refresh, color: Colors.blue),
              tooltip: 'تحديث',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final isDebt = _currentBalance > 0;

    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 3,
            color: isDebt ? Colors.red.shade50 : Colors.green.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    isDebt
                        ? 'المبلغ المستحق عليك  للمورد'
                        : 'رصيد لك عند المورد',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          isDebt ? Colors.red.shade700 : Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    Formatters.formatCurrency(_currentBalance.abs()),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDebt ? Colors.red : Colors.green,
                    ),
                  ),
                  SizedBox(height: 4),
                  Chip(
                    label: Text(
                      isDebt ? 'مدين' : 'دائن',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: isDebt ? Colors.red : Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(width: 12),

        Expanded(
          child: Card(
            elevation: 3,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'إجمالي الحركات',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _totalTransactions.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'حركة',
                    style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'حركات الحساب',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Badge(
                  label: Text(
                    _transactions.length.toString(),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: Colors.blue,
                  textColor: Colors.white,
                ),
              ],
            ),
          ),

          if (_transactions.isEmpty)
            _buildEmptyState()
          else
            _buildTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
            SizedBox(height: 16),
            Text(
              'لا توجد حركات',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            SizedBox(height: 8),
            Text(
              'لم يتم تسجيل أي فواتير أو دفعات لهذا المورد',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        itemCount: _transactions.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _transactions.length) {
            return _buildLoadMoreIndicator();
          }

          final transaction = _transactions[index];
          return _buildTransactionItem(transaction, index);
        },
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!_hasMore && _transactions.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'تم عرض جميع الحركات',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child:
            _isLoadingMore
                ? CircularProgressIndicator(strokeWidth: 2)
                : Icon(
                  Icons.arrow_drop_down,
                  size: 32,
                  color: Colors.grey.shade400,
                ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction, int index) {
    final type = transaction['type'] as String;
    final amount = (transaction['amount'] as num).toDouble();
    final date =
        transaction['date'] as String? ??
        transaction['created_at'] as String? ??
        '';
    final note = transaction['note'] as String? ?? '';
    final isPayment = type == 'payment';

    // معلومات إضافية للفاتورة
    final invoiceId = transaction['purchase_invoice_id'];
    final remainingAmount = transaction['remaining_amount'] as num?;
    final paymentType = transaction['payment_type'] as String?;
    final totalCost = transaction['total_cost'] as num?;

    Color typeColor = isPayment ? Colors.green : Colors.orange;
    IconData typeIcon = isPayment ? Icons.payment : Icons.receipt;

    return Card(
      margin: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        index == _transactions.length - 1 ? 16 : 4,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف الأول: النوع والرقم
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: typeColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(typeIcon, size: 24, color: typeColor),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPayment ? 'دفعة' : 'فاتورة شراء',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        if (invoiceId != null)
                          Text(
                            '#$invoiceId',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // المبلغ
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isPayment ? '-' : '+'} ${Formatters.formatCurrency(amount)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isPayment ? Colors.green : Colors.red,
                      ),
                    ),
                    if (totalCost != null && totalCost > 0)
                      Text(
                        'الإجمالي: ${Formatters.formatCurrency(totalCost.toDouble())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 12),

            // التاريخ والوقت - بتنسيق عربي أفضل
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDateTime(date),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // معلومات الدفع
            if (paymentType != null && paymentType.isNotEmpty) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade100, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment, size: 14, color: Colors.blue),
                    SizedBox(width: 6),
                    Text(
                      'نوع الدفع: ',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _translatePaymentType(paymentType),
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // المبلغ المتبقي إذا كان هناك فاتورة
            if (remainingAmount != null && remainingAmount > 0) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade100, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'متبقي للدفع: ',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(remainingAmount.toDouble()),
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // الملاحظات إذا وجدت
            if (note.isNotEmpty) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
