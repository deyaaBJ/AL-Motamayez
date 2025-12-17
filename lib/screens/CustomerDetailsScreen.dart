// screens/customer_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/models/customer.dart';
import 'package:shopmate/providers/DebtProvider.dart';
import 'package:shopmate/providers/customer_provider.dart';
import 'package:shopmate/utils/date_formatter.dart';
import 'package:shopmate/widgets/quick_payment_dialog.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;
  final double initialBalance;

  const CustomerDetailsScreen({
    Key? key,
    required this.customer,
    required this.initialBalance,
  }) : super(key: key);

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  bool _isLoading = true;
  bool _isLoadingPayments = false;
  List<Map<String, dynamic>> _payments = [];
  int _paymentPage = 0;
  final int _paymentPageSize = 20;
  bool _hasMorePayments = true;
  final ScrollController _paymentScrollController = ScrollController();
  Map<String, List<Map<String, dynamic>>> _groupedPayments = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _paymentScrollController.addListener(_onPaymentScroll);
  }

  @override
  void dispose() {
    _paymentScrollController.dispose();
    super.dispose();
  }

  void _onPaymentScroll() {
    if (_paymentScrollController.position.pixels ==
        _paymentScrollController.position.maxScrollExtent) {
      if (_hasMorePayments && !_isLoadingPayments) {
        _loadMorePayments();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);

    // تحميل الدفعات الأولى
    await _loadPaymentsPage(0);

    setState(() => _isLoading = false);
  }

  Future<void> _loadPaymentsPage(int page) async {
    if (!_hasMorePayments && page > 0) return;

    setState(() => _isLoadingPayments = true);

    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final newPayments = await debtProvider.loadPaymentsPage(
      widget.customer.id!,
      page: page,
      limit: _paymentPageSize,
    );

    setState(() {
      if (page == 0) {
        _payments = newPayments.map((p) => p.toMap()).toList();
      } else {
        _payments.addAll(newPayments.map((p) => p.toMap()).toList());
      }

      // تجميع الدفعات حسب الشهر
      _groupPaymentsByMonth();

      _paymentPage = page;
      _hasMorePayments = newPayments.length == _paymentPageSize;
      _isLoadingPayments = false;
    });
  }

  void _groupPaymentsByMonth() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var payment in _payments) {
      try {
        final dateString = payment['date'].toString();
        final dateTime = DateTime.parse(
          dateString.contains('T') ? dateString : '${dateString}T00:00:00',
        );

        // استخدام الشهر والسنة كمفتاح (مثال: "2024-01")
        final key =
            '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}';
        final monthName = _getArabicMonthName(dateTime.month);
        final displayKey = '$monthName ${dateTime.year}';

        if (!grouped.containsKey(displayKey)) {
          grouped[displayKey] = [];
        }
        grouped[displayKey]!.add(payment);
      } catch (e) {
        // تجاهل الدفعات ذات التواريخ غير الصالحة
        continue;
      }
    }

    // ترتيب الشهور تنازلياً (من الأحدث إلى الأقدم)
    final sortedKeys =
        grouped.keys.toList()
          ..sort((a, b) => _parseMonthYear(b).compareTo(_parseMonthYear(a)));

    final sortedGrouped = <String, List<Map<String, dynamic>>>{};
    for (var key in sortedKeys) {
      // ترتيب الدفعات داخل كل شهر تنازلياً حسب التاريخ
      grouped[key]!.sort(
        (a, b) => DateTime.parse(
          b['date'].toString().contains('T')
              ? b['date'].toString()
              : '${b['date']}T00:00:00',
        ).compareTo(
          DateTime.parse(
            a['date'].toString().contains('T')
                ? a['date'].toString()
                : '${a['date']}T00:00:00',
          ),
        ),
      );
      sortedGrouped[key] = grouped[key]!;
    }

    _groupedPayments = sortedGrouped;
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

  Future<void> _loadMorePayments() async {
    await _loadPaymentsPage(_paymentPage + 1);
  }

  Future<void> _refreshData() async {
    setState(() {
      _paymentPage = 0;
      _hasMorePayments = true;
      _groupedPayments.clear();
    });
    await _loadPaymentsPage(0);
  }

  Widget _buildCompactHeader() {
    return Consumer<DebtProvider>(
      builder: (context, debtProvider, child) {
        final futureBalance = debtProvider.getTotalDebtByCustomerId(
          widget.customer.id!,
        );

        return FutureBuilder<double>(
          future: futureBalance,
          builder: (context, snapshot) {
            final balance = snapshot.data ?? 0.0;
            // يمكنك تخصيص العرض أثناء التحميل أو الخطأ إذا أردت
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
                      // زر التسديد (معطّل أثناء التحميل)
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const SizedBox(
                          width: 120,
                          child: Center(child: SizedBox(height: 24)),
                        )
                      else if (balance > 0)
                        ElevatedButton.icon(
                          onPressed:
                              () =>
                                  _showPaymentDialog(widget.customer, balance),

                          icon: const Icon(Icons.payment, size: 18),
                          label: const Text('تسديد'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A3093),
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
                              '${balance.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: balance > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'دينار',
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

  void _showPaymentDialog(Customer customer, double currentDebt) {
    QuickPaymentDialog.show(
      context: context,
      customer: customer,
      currentDebt: currentDebt,
      onPayment: (customer, amount, note) async {
        // هنا عملية الدفع الفعلية
        final debtProvider = Provider.of<DebtProvider>(context, listen: false);
        await debtProvider.addPayment(
          customerId: customer.id!,
          amount: amount,
          note: note,
        );
        await _refreshData();
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
            'دفعات شهر $monthYear',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A3093),
            ),
          ),
          const Spacer(),
          Text(
            '${_groupedPayments[monthYear]?.length ?? 0} دفعة',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment, int sequentialNumber) {
    final dateTime = DateFormatter.formatDateTime(payment['date'].toString());

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
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  sequentialNumber.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'دفعة',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${double.parse(payment['amount'].toString()).toStringAsFixed(2)} دينار',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
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
                  if (payment['note'] != null &&
                      payment['note'].toString().isNotEmpty)
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
                              payment['note'].toString(),
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

  Widget _buildGroupedPaymentsList() {
    final List<Widget> widgets = [];

    int overallCounter = 1;

    for (var monthKey in _groupedPayments.keys) {
      // إضافة عنوان الشهر
      widgets.add(_buildMonthHeader(monthKey));

      // إضافة دفعات هذا الشهر
      final monthPayments = _groupedPayments[monthKey]!;
      for (var payment in monthPayments) {
        widgets.add(_buildPaymentItem(payment, overallCounter));
        overallCounter++;
      }
    }

    if (_hasMorePayments) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child:
                _isLoadingPayments
                    ? const CircularProgressIndicator()
                    : const SizedBox(),
          ),
        ),
      );
    }

    return ListView(
      controller: _paymentScrollController,
      padding: const EdgeInsets.only(bottom: 80),
      children: widgets,
    );
  }

  Widget _buildPaymentsTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: const Color(0xFF6A3093)),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل الدفعات...',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'لا توجد دفعات',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم تسجيل أي دفعات لهذا العميل',
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
      child: _buildGroupedPaymentsList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'تفاصيل العميل',
        showAppBar: true,
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
            _buildCompactHeader(),
            const SizedBox(height: 8),
            Expanded(child: _buildPaymentsTab()),
          ],
        ),
      ),
    );
  }
}
