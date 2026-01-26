// screens/customer_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/customer.dart';
import 'package:motamayez/models/transaction.dart';
import 'package:motamayez/providers/DebtProvider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/utils/date_formatter.dart';
import 'package:motamayez/widgets/quick_payment_dialog.dart';
import 'dart:developer';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;
  final double initialBalance;

  const CustomerDetailsScreen({
    super.key,
    required this.customer,
    required this.initialBalance,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  bool _isLoading = true;
  bool _isLoadingTransactions = false;
  List<Transaction> _transactions = [];
  int _transactionPage = 0;
  final int _transactionPageSize = 20;
  bool _hasMoreTransactions = true;
  final ScrollController _transactionScrollController = ScrollController();
  Map<String, List<Transaction>> _groupedTransactions = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _transactionScrollController.addListener(_onTransactionScroll);
  }

  @override
  void dispose() {
    _transactionScrollController.dispose();
    super.dispose();
  }

  void _onTransactionScroll() {
    if (_transactionScrollController.position.pixels ==
        _transactionScrollController.position.maxScrollExtent) {
      if (_hasMoreTransactions && !_isLoadingTransactions) {
        _loadMoreTransactions();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    Provider.of<DebtProvider>(context, listen: false);

    // تحميل المعاملات الأولى
    await _loadTransactionsPage(0);

    setState(() => _isLoading = false);
  }

  Future<void> _loadTransactionsPage(int page) async {
    if (!_hasMoreTransactions && page > 0) return;

    setState(() => _isLoadingTransactions = true);

    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final newTransactions = await debtProvider.loadTransactionsPage(
      widget.customer.id!,
      page: page,
      limit: _transactionPageSize,
    );

    setState(() {
      if (page == 0) {
        _transactions = newTransactions;
      } else {
        _transactions.addAll(newTransactions);
      }

      // تجميع المعاملات حسب الشهر
      _groupTransactionsByMonth();

      _transactionPage = page;
      _hasMoreTransactions = newTransactions.length == _transactionPageSize;
      _isLoadingTransactions = false;
    });
  }

  void _groupTransactionsByMonth() {
    final Map<String, List<Transaction>> grouped = {};

    for (var transaction in _transactions) {
      try {
        final dateTime = transaction.date;

        // استخدام الشهر والسنة كمفتاح (مثال: "2024-01")
        final monthName = _getArabicMonthName(dateTime.month);
        final displayKey = '$monthName ${dateTime.year}';

        if (!grouped.containsKey(displayKey)) {
          grouped[displayKey] = [];
        }
        grouped[displayKey]!.add(transaction);
      } catch (e) {
        continue;
      }
    }

    // ترتيب الشهور تنازلياً (من الأحدث إلى الأقدم)
    final sortedKeys =
        grouped.keys.toList()
          ..sort((a, b) => _parseMonthYear(b).compareTo(_parseMonthYear(a)));

    final sortedGrouped = <String, List<Transaction>>{};
    for (var key in sortedKeys) {
      // ترتيب المعاملات داخل كل شهر تنازلياً حسب التاريخ
      grouped[key]!.sort((a, b) => b.date.compareTo(a.date));
      sortedGrouped[key] = grouped[key]!;
    }

    _groupedTransactions = sortedGrouped;
  }

  String _getArabicMonthName(int month) {
    final months = [
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
    return months[month - 1];
  }

  DateTime _parseMonthYear(String monthYear) {
    final parts = monthYear.split(' ');
    if (parts.length != 2) return DateTime.now();

    final monthName = parts[0];
    final year = int.tryParse(parts[1]) ?? DateTime.now().year;

    final months = [
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
    final month = months.indexOf(monthName) + 1;

    return DateTime(year, month);
  }

  Future<void> _loadMoreTransactions() async {
    await _loadTransactionsPage(_transactionPage + 1);
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final debtProvider = Provider.of<DebtProvider>(context, listen: false);

      // إعادة تعيين المتغيرات
      _transactionPage = 0;
      _hasMoreTransactions = true;
      _groupedTransactions.clear();

      // تحميل المعاملات الجديدة
      await _loadTransactionsPage(0);

      // إعادة تحميل رصيد العميل
      await debtProvider.recalculateAndUpdateBalance(widget.customer.id!);
    } catch (e) {
      log('Error refreshing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPaymentDialog(Customer customer, double currentDebt) {
    QuickPaymentDialog.showPayment(
      context: context,
      customer: customer,
      currentDebt: currentDebt,
      onPayment: (customer, amount, note) async {
        final debtProvider = Provider.of<DebtProvider>(context, listen: false);
        await debtProvider.addPayment(
          customerId: customer.id!,
          amount: amount,
          note: note,
        );

        // تحديث البيانات بعد الإضافة
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshData();

          // إعادة تحميل رصيد العميل
          setState(() {});
        });
      },
    );
  }

  void _showWithdrawalDialog(Customer customer, double currentBalance) {
    QuickPaymentDialog.showWithdrawal(
      context: context,
      customer: customer,
      currentBalance: currentBalance,
      onWithdrawal: (customer, amount, note) async {
        final debtProvider = Provider.of<DebtProvider>(context, listen: false);
        await debtProvider.addWithdrawal(
          customerId: customer.id!,
          amount: amount,
          note: note,
        );

        // تحديث البيانات بعد الإضافة
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshData();

          // إعادة تحميل رصيد العميل
          setState(() {});
        });
      },
    );
  }

  Widget _buildCompactHeader(Customer customer) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
    return Consumer<DebtProvider>(
      builder: (context, debtProvider, child) {
        return FutureBuilder<double>(
          future: debtProvider.getTotalDebtByCustomerId(customer.id!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: const Color(0xFF6A3093),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              log('Error loading balance: ${snapshot.error}');

              // حاول إعادة الحساب
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await debtProvider.recalculateAndUpdateBalance(customer.id!);
              });

              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'خطأ في تحميل الرصيد',
                      style: TextStyle(color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await debtProvider.recalculateAndUpdateBalance(
                          customer.id!,
                        );
                      },
                      child: Text('إعادة حساب الرصيد'),
                    ),
                  ],
                ),
              );
            }

            final balance = snapshot.data ?? 0.0;
            log('Customer ID: ${customer.id}');
            log('Current balance: $balance');

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(
                          0xFF6A3093,
                        ).withOpacity(0.1),
                        child: Text(
                          widget.customer.name.substring(0, 1),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6A3093),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customer.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.customer.phone != null)
                              Text(
                                widget.customer.phone!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // أزرار التسديد وصرف الرصيد
                      Row(
                        children: [
                          if (balance > 0)
                            ElevatedButton.icon(
                              onPressed:
                                  () => _showPaymentDialog(
                                    widget.customer,
                                    balance,
                                  ),
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('تسديد'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (balance < 0)
                            ElevatedButton.icon(
                              onPressed:
                                  () => _showWithdrawalDialog(
                                    widget.customer,
                                    balance,
                                  ),
                              icon: const Icon(Icons.money, size: 18),
                              label: const Text('صرف رصيد'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: balance > 0 ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            balance > 0
                                ? Colors.red.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الرصيد الحالي',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              balance.abs().toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: balance > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currencyName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              balance > 0
                                  ? Icons.arrow_upward
                                  : Icons.check_circle,
                              size: 18,
                              color: balance > 0 ? Colors.red : Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthHeader(String monthYear) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6A3093).withOpacity(0.1),
        border: Border(
          left: BorderSide(color: const Color(0xFF6A3093), width: 4),
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Color(0xFF6A3093), size: 20),
          const SizedBox(width: 12),
          Text(
            'معاملات شهر $monthYear',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A3093),
            ),
          ),
          const Spacer(),
          Text(
            '${_groupedTransactions[monthYear]?.length ?? 0} معاملة',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction, int sequentialNumber) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
    final dateTime = DateFormatter.formatDateTime(transaction.date.toString());
    final isPayment = transaction.type == TransactionType.payment;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    isPayment
                        ? Colors.green.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      isPayment
                          ? Colors.green.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Center(
                child: Icon(
                  isPayment ? Icons.payment : Icons.money,
                  color: isPayment ? Colors.green : Colors.blue,
                  size: 24,
                ),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transaction.typeText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isPayment ? Colors.green : Colors.blue,
                  ),
                ),
                Text(
                  '${transaction.amount.toStringAsFixed(2)} $currencyName',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isPayment ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // التاريخ والوقت في سطر واحد
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateTime['date'] ?? 'غير محدد',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateTime['time'] ?? 'غير محدد',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // الملاحظة
                  if (transaction.note != null && transaction.note!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.note,
                            size: 16,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              transaction.note!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedTransactionsList() {
    final List<Widget> widgets = [];

    int overallCounter = 1;

    for (var monthKey in _groupedTransactions.keys) {
      // إضافة عنوان الشهر
      widgets.add(_buildMonthHeader(monthKey));

      // إضافة معاملات هذا الشهر
      final monthTransactions = _groupedTransactions[monthKey]!;
      for (var transaction in monthTransactions) {
        widgets.add(_buildTransactionItem(transaction, overallCounter));
        overallCounter++;
      }
    }

    if (_hasMoreTransactions) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child:
                _isLoadingTransactions
                    ? const CircularProgressIndicator()
                    : const SizedBox(),
          ),
        ),
      );
    }

    return ListView(
      controller: _transactionScrollController,
      padding: const EdgeInsets.only(bottom: 80),
      children: widgets,
    );
  }

  Widget _buildTransactionsTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: const Color(0xFF6A3093)),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل المعاملات...',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'لا توجد معاملات',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم تسجيل أي معاملات لهذا العميل',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF6A3093),
      child: _buildGroupedTransactionsList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'تفاصيل العميل',
        title: widget.customer.name,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
        child: Column(
          children: [
            _buildCompactHeader(widget.customer),
            const SizedBox(height: 8),
            Expanded(child: _buildTransactionsTab()),
          ],
        ),
      ),
    );
  }
}
