// screens/customer_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/models/customer.dart';
import 'package:shopmate/providers/DebtProvider.dart';
import 'package:shopmate/providers/customer_provider.dart';
import 'package:shopmate/utils/date_formatter.dart';

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
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    setState(() => _isLoading = true);

    final customerProvider = Provider.of<CustomerProvider>(
      context,
      listen: false,
    );
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);

    // تحميل الفواتير
    _sales = await customerProvider.getCustomerSales(widget.customer.id!);

    // تحميل الدفعات
    await debtProvider.loadPayments(widget.customer.id!);
    _payments = debtProvider.payments.map((p) => p.toMap()).toList();

    setState(() => _isLoading = false);
  }

  Widget _buildHeader() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A3093).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      widget.customer.name.substring(0, 1),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A3093),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customer.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.customer.phone != null)
                        Text(
                          widget.customer.phone!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<DebtProvider>(
              builder: (context, debtProvider, child) {
                final balance = debtProvider.totalDebt;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: balance > 0 ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          balance > 0
                              ? Colors.red.withOpacity(0.3)
                              : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الرصيد الحالي',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${balance.toStringAsFixed(2)} دينار',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: balance > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (balance > 0)
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.payment),
                          label: const Text('تسديد دفعة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              253,
                              99,
                              52,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'لا توجد فواتير',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _sales.length,
      itemBuilder: (context, index) {
        final sale = _sales[index];

        // تنسيق التاريخ والوقت بشكل جميل
        final dateTime = DateFormatter.formatDateTime(sale['date'].toString());

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade100, Colors.blue.shade300],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Row(
              children: [
                Text(
                  'فاتورة #',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  sale['id'].toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // التاريخ
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.black),
                      const SizedBox(width: 6),
                      Text(
                        dateTime['date'] ?? 'غير محدد',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),

                  // الوقت
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.black),
                      const SizedBox(width: 6),
                      Text(
                        dateTime['time'] ?? 'غير محدد',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),

                  // طريقة الدفع
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${double.parse(sale['total_amount'].toString()).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  'دينار',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'لا توجد دفعات',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.payment, color: Colors.green),
            ),
            title: Text(
              'دفعة ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التاريخ: ${payment['date']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (payment['note'] != null)
                  Text(
                    'ملاحظة: ${payment['note']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            trailing: Text(
              '${double.parse(payment['amount'].toString()).toStringAsFixed(2)} دينار',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
          ),
        );
      },
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
            onPressed: _loadCustomerData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
          ),
        ],
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  labelColor: const Color(0xFF6A3093),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF6A3093),
                  tabs: const [
                    Tab(icon: Icon(Icons.receipt), text: 'الفواتير'),
                    Tab(icon: Icon(Icons.payments), text: 'الدفعات'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [_buildSalesTab(), _buildPaymentsTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
