import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import '../providers/supplier_provider.dart';
import '../utils/formatters.dart';

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
  bool _isLoading = true;
  double _currentBalance = 0.0;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final provider = Provider.of<SupplierProvider>(context, listen: false);

      final balanceResult = await provider.getSupplierBalance(
        widget.supplierId,
      );
      final transactionsResult = await provider.getSupplierTransactions(
        widget.supplierId,
      );

      setState(() {
        _currentBalance = (balanceResult as num).toDouble();
        _transactions = List<Map<String, dynamic>>.from(transactionsResult);
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل البيانات: $e');
      setState(() => _isLoading = false);
    }
  }

  // دالة لتنسيق التاريخ بدون استخدام Formatters
  String _formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final year = date.year;
      final month = _getArabicMonth(date.month);
      final day = date.day;
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');

      // تنسيق عربي
      return '$day $month $year $hour:$minute';
    } catch (e) {
      return dateString;
    }
  }

  // تحويل رقم الشهر إلى اسم عربي
  String _getArabicMonth(int month) {
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

  // دالة لتنسيق العملة بدون مشاكل
  String _formatCurrency(double amount) {
    try {
      return Formatters.formatCurrency(amount);
    } catch (e) {
      // بديل إذا فشلت Formatters
      return '${amount.toStringAsFixed(2)} د.إ';
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
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildBalanceCard(),
        const SizedBox(height: 16),
        _buildTransactionsHeader(),
        const SizedBox(height: 8),
        _transactions.isEmpty
            ? _buildEmptyTransactions()
            : _buildTransactionsList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.person, size: 32, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.supplierName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'رقم المورد: ${widget.supplierId}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final isDebt = _currentBalance > 0;

    return Card(
      color: isDebt ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              isDebt ? 'المبلغ المستحق' : 'رصيد المورد',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(_currentBalance.abs()), // استخدم الدالة المحلية
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDebt ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDebt ? 'المورد مدين' : 'المورد دائن',
              style: TextStyle(color: isDebt ? Colors.red : Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'حركات الحساب',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Chip(
            label: Text('${_transactions.length} حركة'),
            backgroundColor: Colors.blue.shade50,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'لا توجد حركات',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'لم يتم تسجيل أي فواتير أو دفعات لهذا المورد',
              style: TextStyle(color: Colors.grey),
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
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final amount = (transaction['amount'] as num).toDouble();
    final date = transaction['date'] as String;
    final note = transaction['note'] as String? ?? '';
    final isPayment = type == 'payment';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف الأول: النوع والمبلغ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(isPayment ? 'دفعة' : 'فاتورة'),
                  backgroundColor:
                      isPayment ? Colors.green.shade50 : Colors.blue.shade50,
                  labelStyle: TextStyle(
                    color: isPayment ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${isPayment ? '-' : '+'} ${_formatCurrency(amount)}', // استخدم الدالة المحلية
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPayment ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // التاريخ - استخدم الدالة المحلية
            Text(
              _formatDateString(date),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            // الملاحظات
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(note, style: const TextStyle(fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }
}
