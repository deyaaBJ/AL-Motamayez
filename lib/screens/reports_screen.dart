// screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sales_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'اليوم'; // اليوم، الأسبوع، الشهر، السنة

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SalesProvider>().loadReportsData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'التقارير والإحصائيات',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<SalesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingReports) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // فلتر الفترة الزمنية
                _buildPeriodFilter(provider),
                const SizedBox(height: 20),

                // بطاقات الإحصائيات الرئيسية
                _buildStatsCards(provider),
                const SizedBox(height: 24),

                // منحنى تطور الأرباح والمبيعات
                _buildProfitSalesChart(provider),
                const SizedBox(height: 24),

                // الإحصائيات التفصيلية
                _buildDetailedStats(provider),
                const SizedBox(height: 24),

                // المنتجات الأكثر مبيعاً
                _buildTopProducts(provider),
                const SizedBox(height: 24),

                // العملاء الأكثر شراءً
                _buildTopCustomers(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodFilter(SalesProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'الفترة:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          DropdownButton<String>(
            value: _selectedPeriod,
            items:
                ['اليوم', 'الأسبوع', 'الشهر', 'السنة'].map((String period) {
                  return DropdownMenuItem(value: period, child: Text(period));
                }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              provider.filterByPeriod(_selectedPeriod);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(SalesProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // حساب عدد الأعمدة حسب عرض الشاشة
        int crossAxisCount = 3;
        double screenWidth = constraints.maxWidth;

        if (screenWidth < 600) {
          crossAxisCount = 1;
        } else if (screenWidth < 1100) {
          crossAxisCount = 2;
        }

        // تحديد نسبة العرض للارتفاع
        double childAspectRatio = 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildStatCard(
              'إجمالي المبيعات',
              '${provider.totalSalesAmount.toStringAsFixed(0)} ل.س',
              Icons.shopping_cart,
              Colors.blue,
              '${provider.salesCount} فاتورة',
            ),
            _buildStatCard(
              'إجمالي الأرباح',
              '${provider.totalProfit.toStringAsFixed(0)} ل.س',
              Icons.attach_money,
              Colors.green,
              '${provider.profitPercentage.toStringAsFixed(1)}% من المبيعات',
            ),

            _buildStatCard(
              'عدد الفواتير',
              provider.salesCount.toString(),
              Icons.receipt,
              Colors.purple,
              'إجمالي المعاملات',
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitSalesChart(SalesProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // العنوان
            const Row(
              children: [
                Icon(Icons.table_chart, color: Colors.blue, size: 22),
                SizedBox(width: 8),
                Text(
                  'مبيعات الأسبوع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // الجدول البسيط
            _buildSimpleTable(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTable(SalesProvider provider) {
    if (provider.weeklySalesData.isEmpty) {
      return _buildEmptyTable();
    }

    // حساب الإجمالي
    double totalSales = provider.weeklySalesData
        .map((e) => e['sales'] as double)
        .fold(0, (a, b) => a + b);

    return Column(
      children: [
        // رأس الجدول
        _buildTableHeader(),
        const SizedBox(height: 8),

        // بيانات الأيام
        ...provider.weeklySalesData.map((dayData) {
          return _buildTableRow(
            dayName: dayData['dayName'] as String,
            sales: dayData['sales'] as double,
            profit: dayData['profit'] as double,
          );
        }).toList(),

        // المجموع
        _buildTableTotal(totalSales),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('اليوم', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'المبيعات',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الأرباح',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required String dayName,
    required double sales,
    required double profit,
  }) {
    bool hasData = sales > 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // اسم اليوم
          Expanded(
            flex: 2,
            child: Text(
              dayName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: hasData ? Colors.black87 : Colors.grey,
              ),
            ),
          ),

          // المبيعات
          Expanded(
            flex: 2,
            child: Text(
              hasData ? '${sales.toStringAsFixed(0)} ل.س' : '-',
              style: TextStyle(
                color: hasData ? Colors.blue[700] : Colors.grey,
                fontWeight: hasData ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // الأرباح
          Expanded(
            flex: 2,
            child: Text(
              hasData ? '+${profit.toStringAsFixed(0)} ل.س' : '-',
              style: TextStyle(
                color: hasData ? Colors.green[700] : Colors.grey,
                fontWeight: hasData ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableTotal(double totalSales) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 2,
            child: Text(
              'الإجمالي',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${totalSales.toStringAsFixed(0)} ل.س',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text('-', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTable() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.table_rows, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد بيانات',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'سيظهر جدول المبيعات هنا',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(SalesProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إحصائيات تفصيلية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'المبيعات النقدية',
              '${provider.cashSalesAmount.toStringAsFixed(0)} ل.س',
              Colors.green,
            ),
            _buildStatRow(
              'المبيعات الآجلة',
              '${provider.creditSalesAmount.toStringAsFixed(0)} ل.س',
              Colors.orange,
            ),
            _buildStatRow(
              'عدد العملاء',
              provider.totalCustomers.toString(),
              Colors.blue,
            ),
            _buildStatRow(
              'أفضل يوم مبيعات',
              provider.bestSalesDay ?? 'لا يوجد بيانات',
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(SalesProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المنتجات الأكثر مبيعاً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (provider.topProducts.isEmpty)
              const Center(
                child: Text(
                  'لا توجد بيانات',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Column(
                children:
                    provider.topProducts.take(5).map((product) {
                      return _buildProductItem(
                        product['name'],
                        product['quantity'],
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(String name, int quantity) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$quantity قطعة',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCustomers(SalesProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'العملاء الأكثر شراءً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (provider.topCustomers.isEmpty)
              const Center(
                child: Text(
                  'لا توجد بيانات',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Column(
                children:
                    provider.topCustomers.take(5).map((customer) {
                      return _buildCustomerItem(
                        customer['name'],
                        customer['total_amount'],
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerItem(String name, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Text(
              name[0],
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${amount.toStringAsFixed(0)} ل.س',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
