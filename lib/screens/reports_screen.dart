// screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import '../providers/reports_provider.dart';
import '../utils/pdf_exporter.dart';
import '../models/report_data.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'اليوم';
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final provider = context.read<ReportsProvider>();
      await provider.loadReportsData();
    });
  }

  // دالة لتوليد بيانات التقرير
  Future<ReportData> _generateReportData(
    ReportsProvider reportsProvider,
    SettingsProvider settingsProvider,
  ) async {
    final now = DateTime.now();
    DateTime fromDate;
    DateTime toDate = now;

    // تحديد تواريخ الفترة
    switch (_selectedPeriod) {
      case 'اليوم':
        fromDate = DateTime(now.year, now.month, now.day);
        break;
      case 'الأسبوع':
        fromDate = now.subtract(const Duration(days: 7));
        break;
      case 'الشهر':
        fromDate = DateTime(now.year, now.month, 1);
        break;
      case 'السنة':
        fromDate = DateTime(now.year, 1, 1);
        break;
      case 'شهر محدد':
        fromDate = DateTime(_selectedYear!, _selectedMonth!, 1);
        toDate = DateTime(_selectedYear!, _selectedMonth! + 1, 0);
        break;
      case 'سنة محددة':
        fromDate = DateTime(_selectedYear!, 1, 1);
        toDate = DateTime(_selectedYear!, 12, 31);
        break;
      default:
        fromDate = now.subtract(const Duration(days: 30));
    }

    // إحصائيات التقرير
    // الإحصائيات ستكون صحيحة الآن:
    final stats = {
      'totalSales': reportsProvider.totalSalesAmount,
      'totalProfit': reportsProvider.totalProfit,
      'cashSales': reportsProvider.cashSalesAmount,
      'creditSales': reportsProvider.creditSalesAmount,
      'totalExpensesAll': reportsProvider.totalExpensesAll,
      'totalCashExpenses': reportsProvider.totalCashExpenses,
      'netProfit': reportsProvider.netProfit, // ✅ الآن صحيح
      'netCashProfit': reportsProvider.netCashProfit,
      'adjustedNetProfit': reportsProvider.adjustedNetProfit,
      'salesCount': reportsProvider.salesCount,
      'profitPercentage': reportsProvider.profitPercentage,
      'bestSalesDay': reportsProvider.bestSalesDay ?? 'لا يوجد',
      'averageSale':
          reportsProvider.salesCount > 0
              ? reportsProvider.totalSalesAmount / reportsProvider.salesCount
              : 0,
    };

    return ReportData(
      period: _selectedPeriod,
      fromDate: fromDate,
      toDate: toDate,
      statistics: stats,
      topProducts: reportsProvider.topProducts.take(5).toList(),
      topCustomers: reportsProvider.topCustomers.take(5).toList(),
      weeklySales: reportsProvider.weeklySalesData,
      currency: settingsProvider.currencyName,
    );
  }

  // دالة تصدير PDF - هذه هي الدالة المفقودة
  Future<void> _exportToPDF() async {
    try {
      final reportsProvider = context.read<ReportsProvider>();
      final settingsProvider = context.read<SettingsProvider>();

      // عرض مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // توليد بيانات التقرير
      final reportData = await _generateReportData(
        reportsProvider,
        settingsProvider,
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // جلب قائمة المسؤولين
      final admins = await authProvider.getUsersByRole('admin');
      final adminName = admins.isNotEmpty ? admins[0]['name'] : 'غير محدد';

      // جلب إعدادات المتجر
      await settingsProvider.loadSettings();
      final marketName = settingsProvider.marketName ?? 'غير محدد';

      // إنشاء وتصدير التقرير
      final pdfExporter = PDFExporter();
      final result = await pdfExporter.exportReport(
        reportData: reportData,
        adminName: adminName,
        marketName: marketName,
      );

      // إغلاق مؤشر التحميل
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result.success && result.filePath != null) {
        // فتح ملف PDF باستخدام open_filex
        final openResult = await OpenFilex.open(result.filePath!);

        if (openResult.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم فتح التقرير بنجاح'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لم يتم العثور على تطبيق لفتح PDF'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تصدير التقرير: ${result.error}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // إغلاق مؤشر التحميل في حالة الخطأ
      if (mounted) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // دالة فلترة تاريخ مخصص (اختياري)

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'التقارير',
        title: 'التقارير والإحصائيات',
        actions: [
          // زر تصدير PDF
          IconButton(
            onPressed: _exportToPDF, // ✅ تم إصلاح الخطأ هنا
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير التقرير PDF',
          ),

          // زر تحديث البيانات
        ],
        floatingActionButton: null,
        child: Consumer<ReportsProvider>(
          builder: (context, provider, _) {
            if (provider.isLoadingReports) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPeriodFilter(provider),
                  const SizedBox(height: 20),
                  _buildAllStatsCards(provider),
                  const SizedBox(height: 24),
                  _buildWeeklySalesTable(provider),
                  const SizedBox(height: 24),
                  _buildDetailedStats(provider),
                  const SizedBox(height: 24),
                  _buildTopProducts(provider),
                  const SizedBox(height: 24),
                  _buildTopCustomers(provider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodFilter(ReportsProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الفترة:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              DropdownButton<String>(
                value: _selectedPeriod,
                items:
                    [
                      'اليوم',
                      'الأسبوع',
                      'الشهر',
                      'السنة',
                      'شهر محدد',
                      'سنة محددة',
                    ].map((String period) {
                      return DropdownMenuItem(
                        value: period,
                        child: Text(period),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value!;
                    // إعادة تعيين القيم عند تغيير نوع الفلتر
                    if (_selectedPeriod != 'شهر محدد') {
                      _selectedMonth = null;
                    }
                    if (_selectedPeriod != 'سنة محددة') {
                      _selectedYear = null;
                    }
                  });
                  // تطبيق الفلتر فقط للفترات التي لا تحتاج إدخالات إضافية
                  if (_selectedPeriod != 'شهر محدد' &&
                      _selectedPeriod != 'سنة محددة') {
                    _applyFilter(provider);
                  }
                },
              ),
            ],
          ),

          // فلتر الشهر المحدد
          if (_selectedPeriod == 'شهر محدد') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'الشهر',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        List.generate(12, (index) => index + 1).map((
                          int month,
                        ) {
                          return DropdownMenuItem(
                            value: month,
                            child: Text(_getMonthName(month)),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMonth = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'السنة',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _getAvailableYears().map((int year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // زر تطبيق الفلتر
            ElevatedButton(
              onPressed: () {
                if (_selectedMonth != null && _selectedYear != null) {
                  _applyFilter(provider);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'يرجى اختيار الشهر والسنة',
                        textAlign: TextAlign.center,
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('تطبيق الفلتر'),
            ),
          ],

          // فلتر السنة المحددة
          if (_selectedPeriod == 'سنة محددة') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(
                labelText: 'السنة',
                border: OutlineInputBorder(),
              ),
              items:
                  _getAvailableYears().map((int year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedYear = value;
                });
              },
            ),
            const SizedBox(height: 10),
            // زر تطبيق الفلتر
            ElevatedButton(
              onPressed: () {
                if (_selectedYear != null) {
                  _applyFilter(provider);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'يرجى اختيار السنة',
                        textAlign: TextAlign.center,
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('تطبيق الفلتر'),
            ),
          ],
        ],
      ),
    );
  }
  // في reports_screen.dart - استبدل _buildStatsCards و _buildFinancialCards بـ:

  Widget _buildAllStatsCards(ReportsProvider provider) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 10;
        final double maxWidth = constraints.maxWidth;

        // تحديد عدد الأعمدة بناءً على عرض الشاشة
        int columns;
        if (maxWidth >= 1200) {
          columns = 4; // شاشات كبيرة جداً: 4 أعمدة
        } else if (maxWidth >= 900) {
          columns = 4; // شاشات كبيرة: 3 أعمدة
        } else if (maxWidth >= 600) {
          columns = 3; // شاشات متوسطة: 2 عمود
        } else {
          columns = 1; // شاشات صغيرة: عمود واحد
        }

        final double totalSpacing = spacing * (columns - 1);
        final double cardWidth = (maxWidth - totalSpacing) / columns;

        // جميع الكروت في قائمة واحدة بترتيب منطقي
        final cards = [
          // المجموعة 1: المبيعات الأساسية
          _buildStatCard(
            'إجمالي المبيعات',
            '${provider.totalSalesAmount.toStringAsFixed(2)} $currencyName',
            Icons.shopping_cart,
            Colors.blue,
            '${provider.salesCount} فاتورة',
          ),

          _buildStatCard(
            'المبيعات النقدية',
            '${provider.cashSalesAmount.toStringAsFixed(2)} $currencyName',
            Icons.money,
            Colors.green,
            'المدفوعات نقداً',
          ),
          _buildStatCard(
            'المبيعات الآجلة',
            '${provider.creditSalesAmount.toStringAsFixed(2)} $currencyName',
            Icons.credit_card,
            Colors.orange,
            'المبيعات الآجلة',
          ),

          // المجموعة 2: الأرباح
          _buildStatCard(
            'إجمالي الأرباح',
            '${provider.totalProfit.toStringAsFixed(2)} $currencyName',
            Icons.attach_money,
            Colors.green,
            '${provider.profitPercentage.toStringAsFixed(2)}% من المبيعات',
          ),
          _buildStatCard(
            'الأرباح النقدية',
            '${provider.totalCashProfit.toStringAsFixed(2)} $currencyName',
            Icons.monetization_on,
            Colors.green.shade700,
            'أرباح المبيعات النقدية فقط',
          ),

          // المجموعة 3: المصاريف
          _buildStatCard(
            'إجمالي المصاريف',
            '${provider.totalExpensesAll.toStringAsFixed(2)} $currencyName',
            Icons.money_off,
            Colors.red.shade700,
            'كل المصاريف (نقدية وغير نقدية)',
          ),

          // المجموعة 4: صافي الربح
          _buildStatCard(
            'صافي الربح',
            '${provider.netProfit.toStringAsFixed(2)} $currencyName',
            Icons.trending_up,
            provider.netProfit >= 0 ? Colors.green : Colors.red,
            'إجمالي الأرباح - المصاريف النقدية',
          ),
          _buildStatCard(
            'صافي الربح الكاش',
            '${provider.netCashProfit.toStringAsFixed(2)} $currencyName',
            Icons.account_balance_wallet,
            provider.netCashProfit >= 0 ? Colors.green : Colors.red,
            'الأرباح النقدية - المصاريف النقدية',
          ),

          // المجموعة 5: إحصائيات إضافية
        ];

        // إزالة أي كروت فارغة (في حالة عدم وجود بيانات)
        // ignore: unnecessary_null_comparison
        final filteredCards = cards.where((card) => card != null).toList();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              filteredCards.map((card) {
                return SizedBox(width: cardWidth, child: card);
              }).toList(),
        );
      },
    );
  }

  // دالة جديدة لعرض كروت المصاريف وصافي الربح

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
      child: Container(
        width: double.infinity, // لملء المساحة المتاحة
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                // يمكن إضافة زر أو أيقونة إضافية هنا إذا لزم
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 22, // زيادة حجم الخط
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16, // زيادة حجم الخط
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13, // زيادة حجم الخط قليلاً
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // التغيير الرئيسي هنا: جعل الجدول يوضح أنه ثابت لآخر 7 أيام
  Widget _buildWeeklySalesTable(ReportsProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // العنوان - موضح أنه لآخر 7 أيام
            const Row(
              children: [
                Icon(Icons.table_chart, color: Colors.blue, size: 22),
                SizedBox(width: 8),
                Text(
                  'مبيعات آخر 7 أيام',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // إضافة وصف صغير يوضح أن الجدول ثابت
            Text(
              'عرض بيانات آخر 7 أيام بغض النظر عن الفلتر المختار',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            // الجدول البسيط
            _buildSimpleTable(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTable(ReportsProvider provider) {
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
        }),

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
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
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
              hasData ? '${sales.toStringAsFixed(2)} $currencyName' : '-',
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
              hasData ? '+${profit.toStringAsFixed(2)} $currencyName' : '-',
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
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
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
              '${totalSales.toStringAsFixed(2)} $currencyName',
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
            'لا توجد بيانات لآخر 7 أيام',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'سيظهر جدول المبيعات هنا عند وجود مبيعات',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(ReportsProvider provider) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
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
              '${provider.cashSalesAmount.toStringAsFixed(2)} $currencyName',
              Colors.green,
            ),
            _buildStatRow(
              'المبيعات الآجلة',
              '${provider.creditSalesAmount.toStringAsFixed(2)} $currencyName',
              Colors.orange,
            ),
            _buildStatRow(
              'المصاريف النقدية',
              '${provider.totalCashExpenses.toStringAsFixed(2)} $currencyName',
              Colors.red,
            ),
            _buildStatRow(
              'صافي الربح',
              '${provider.netProfit.toStringAsFixed(2)} $currencyName',
              provider.netProfit >= 0 ? Colors.green : Colors.red,
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

  Widget _buildTopProducts(ReportsProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 22),
                SizedBox(width: 8),
                Text(
                  'المنتجات الأكثر مبيعاً',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'مرتبة حسب عدد المبيعات مع مراعاة أنواع الوحدات المختلفة',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            if (provider.topProducts.isEmpty)
              _buildEmptyProductsState()
            else
              Column(
                children:
                    provider.topProducts.take(5).map((product) {
                      return _buildProductItem(
                        product['name'],
                        product['quantity'],
                        product['unit'],
                        product['sale_count'],
                        product['revenue'],
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(
    String name,
    double quantity,
    String unit,
    int saleCount,
    double revenue,
  ) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
    // تنسيق الكمية بناءً على نوع الوحدة
    String formattedQuantity;
    if (quantity % 1 == 0) {
      formattedQuantity = quantity.toInt().toString(); // رقم صحيح
    } else {
      formattedQuantity = quantity.toStringAsFixed(2); // رقم عشري
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // شريط لوني
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // معلومات المنتج
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),

                // معلومات إضافية
                Row(
                  children: [
                    // الكمية والوحدة
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$formattedQuantity $unit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // عدد مرات البيع
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$saleCount مرة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // الإيرادات
                    Text(
                      '${revenue.toStringAsFixed(2)} $currencyName',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProductsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inventory_2, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد منتجات مباعة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'سيظهر هنا المنتجات الأكثر مبيعاً',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCustomers(ReportsProvider provider) {
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
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0] : '?',
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
                  '${amount.toStringAsFixed(2)} $currencyName',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // دوال مساعدة

  String _getMonthName(int month) {
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

  List<int> _getAvailableYears() {
    final currentYear = DateTime.now().year;
    return List.generate(10, (index) => currentYear - index);
  }

  void _applyFilter(ReportsProvider provider) {
    if (_selectedPeriod == 'شهر محدد' &&
        _selectedMonth != null &&
        _selectedYear != null) {
      provider.filterBySpecificMonth(_selectedMonth!, _selectedYear!);
    } else if (_selectedPeriod == 'سنة محددة' && _selectedYear != null) {
      provider.filterBySpecificYear(_selectedYear!);
    } else {
      provider.filterByPeriod(_selectedPeriod);
    }

    // بعد تطبيق الفلتر، حساب صافي الربح
    _calculateNetProfitForCurrentFilter(provider);
  }

  void _calculateNetProfitForCurrentFilter(ReportsProvider provider) {}
}
