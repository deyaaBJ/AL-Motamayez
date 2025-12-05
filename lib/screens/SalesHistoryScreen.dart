// screens/sales_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/helpers/helpers.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/providers/settings_provider.dart';
import 'package:shopmate/screens/pos_screen.dart';
import '../providers/sales_provider.dart';
import '../widgets/SaleDetailsDialog.dart';
import '../models/sale.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // أول تحميل
    Future.microtask(() => context.read<SalesProvider>().fetchSales());

    // مراقبة التمرير لعمل lazy load
    _scrollController.addListener(() {
      final provider = context.read<SalesProvider>();
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !provider.isLoading &&
          provider.hasMore) {
        provider.fetchSales(loadMore: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // واجهة عربية كاملة
      child: BaseLayout(
        currentPage: 'المبيعات', // اسم الصفحة للسايدبار
        showAppBar: true, // تفعيل AppBar
        title: 'سجل الفواتير', // عنوان AppBar
        actions: [
          IconButton(
            onPressed: () {
              // أي عملية تحديث أو action
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // إضافة فاتورة جديدة
          },
          backgroundColor: const Color(0xFF8B5FBF),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
        child: Column(
          children: [
            // قسم الفلاتر المدمجة
            _buildElegantFiltersSection(),
            const SizedBox(height: 10),

            // جدول الفواتير
            Expanded(child: _buildSalesTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildElegantFiltersSection() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.role;

    return Consumer<SalesProvider>(
      builder: (context, provider, _) {
        return Container(
          margin: const EdgeInsets.all(5),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.blue.shade50],
            ),
          ),
          child: Column(
            children: [
              // العنوان
              Row(
                children: [
                  Icon(
                    Icons.filter_alt_rounded,
                    color: Colors.blue.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'تصفية الفواتير',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              // الفلاتر في صفين متجاوبين
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;

                  if (isWide) {
                    // شاشة واسعة - صف واحد
                    return _buildWideLayout(provider, role);
                  } else {
                    // شاشة ضيقة - عمودين
                    return _buildNarrowLayout(provider, role);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(SalesProvider provider, String? role) {
    return Row(
      children: [
        Expanded(child: _buildElegantPaymentFilter(provider)),
        const SizedBox(width: 12),
        Expanded(child: _buildElegantCustomerFilter(provider)),
        const SizedBox(width: 12),
        Expanded(child: _buildElegantDateFilter(provider)),
        if (role != 'tax') ...[
          const SizedBox(width: 12),
          Expanded(child: _buildElegantTaxFilter(provider)),
        ],
        const SizedBox(width: 12),
        _buildElegantClearButton(provider),
      ],
    );
  }

  Widget _buildNarrowLayout(SalesProvider provider, String? role) {
    return Column(
      children: [
        // الصف الأول
        Row(
          children: [
            Expanded(child: _buildElegantPaymentFilter(provider)),
            const SizedBox(width: 12),
            Expanded(child: _buildElegantCustomerFilter(provider)),
          ],
        ),
        const SizedBox(height: 12),

        // الصف الثاني
        Row(
          children: [
            Expanded(child: _buildElegantDateFilter(provider)),
            if (role != 'tax') ...[
              const SizedBox(width: 12),
              Expanded(child: _buildElegantTaxFilter(provider)),
            ] else ...[
              const Spacer(),
            ],
            const SizedBox(width: 12),
            _buildElegantClearButton(provider),
          ],
        ),
      ],
    );
  }

  Widget _buildElegantPaymentFilter(SalesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.payment_rounded,
                  size: 16,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'نوع الدفع',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.selectedPaymentType,
                items:
                    provider.paymentTypes.map((String type) {
                      String displayText = type;
                      IconData icon = Icons.help_outline;
                      Color color = Colors.grey;

                      if (type == 'cash') {
                        displayText = 'نقدي 💵';
                        icon = Icons.attach_money_rounded;
                        color = Colors.green;
                      } else if (type == 'credit') {
                        displayText = 'آجل 📅';
                        icon = Icons.schedule_rounded;
                        color = Colors.orange;
                      } else {
                        displayText = 'الكل 🔄';
                        icon = Icons.all_inclusive_rounded;
                        color = Colors.blue;
                      }

                      return DropdownMenuItem(
                        value: type,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(icon, size: 18, color: color),
                              const SizedBox(width: 8),
                              Text(
                                displayText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                onChanged: provider.setPaymentTypeFilter,
                icon: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 24,
                    color: Colors.blue.shade600,
                  ),
                ),
                isExpanded: true,
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElegantCustomerFilter(SalesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: Colors.purple.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'العميل',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.selectedCustomer,
                items:
                    provider.customerNames.map((String name) {
                      IconData icon = Icons.person_outline_rounded;
                      Color color = Colors.purple;

                      if (name == 'الكل') {
                        icon = Icons.people_alt_rounded;
                        color = Colors.purple.shade600;
                      } else if (name == 'بدون عميل') {
                        icon = Icons.person_off_rounded;
                        color = Colors.grey;
                      }

                      return DropdownMenuItem(
                        value: name,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(icon, size: 18, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                onChanged: provider.setCustomerFilter,
                icon: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 24,
                    color: Colors.purple.shade600,
                  ),
                ),
                isExpanded: true,
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElegantDateFilter(SalesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'التاريخ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // نوع الفلتر (يوم/شهر/سنة)
          Container(
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.dateFilterType,
                items: [
                  DropdownMenuItem(
                    value: 'day',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.today_rounded,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text('يوم', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'month',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_view_month_rounded,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text('شهر', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'year',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_note_rounded,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text('سنة', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    provider.setDateFilterType(value);
                  }
                },
                icon: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 24,
                    color: Colors.orange.shade600,
                  ),
                ),
                isExpanded: true,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // بناءً على نوع الفلتر نعرض العناصر المناسبة
          _buildDateFilterContent(provider),
        ],
      ),
    );
  }

  Widget _buildDateFilterContent(SalesProvider provider) {
    switch (provider.dateFilterType) {
      case 'day':
        return _buildDayFilter(provider);
      case 'month':
        return _buildMonthFilter(provider);
      case 'year':
        return _buildYearFilter(provider);
      default:
        return _buildDayFilter(provider);
    }
  }

  Widget _buildDayFilter(SalesProvider provider) {
    return GestureDetector(
      onTap: () => _selectDate(context, provider),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.orange.shade50, Colors.white],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getDayFilterText(provider),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    provider.selectedDate == null
                        ? Colors.grey.shade500
                        : Colors.orange.shade800,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthFilter(SalesProvider provider) {
    return Row(
      children: [
        // اختيار الشهر
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: provider.selectedMonth,
                items: List.generate(12, (index) {
                  final month = index + 1;
                  return DropdownMenuItem(
                    value: month,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_view_month_rounded,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getMonthName(month),
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                onChanged: (month) {
                  if (month != null) {
                    provider.setMonthFilter(month);
                  }
                },
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_view_month_rounded,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text('اختر الشهر', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                icon: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 24,
                    color: Colors.orange.shade600,
                  ),
                ),
                isExpanded: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // اختيار السنة
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: provider.selectedYear,
                items: _generateYearItems(),
                onChanged: (year) {
                  if (year != null && provider.selectedMonth != null) {
                    provider.setYearFilter(year);
                  }
                },
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_note_rounded,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text('السنة', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                icon: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 24,
                    color: Colors.orange.shade600,
                  ),
                ),
                isExpanded: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearFilter(SalesProvider provider) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: provider.selectedYear,
          items: _generateYearItems(),
          onChanged: (year) {
            if (year != null) {
              provider.setYearFilter(year);
            }
          },
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.event_note_rounded, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('اختر السنة', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 24,
              color: Colors.orange.shade600,
            ),
          ),
          isExpanded: true,
        ),
      ),
    );
  }

  List<DropdownMenuItem<int>> _generateYearItems() {
    final currentYear = DateTime.now().year;
    return List.generate(5, (index) {
      final year = currentYear - index;
      return DropdownMenuItem(
        value: year,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.event_note_rounded, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(year.toString(), style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildElegantTaxFilter(SalesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: Colors.teal.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'الضريبة',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.selectedTaxFilter,
                items: [
                  _buildTaxDropdownItem(
                    'الكل',
                    Icons.all_inclusive_rounded,
                    Colors.teal,
                  ),
                  _buildTaxDropdownItem(
                    'مضمنه بالضرائب',
                    Icons.verified_rounded,
                    Colors.green,
                  ),
                  _buildTaxDropdownItem(
                    'غير مضمنه بالضرائب',
                    Icons.do_not_disturb_rounded,
                    Colors.red,
                  ),
                ],
                onChanged: provider.setTaxFilter,
                icon: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 24,
                    color: Colors.teal.shade600,
                  ),
                ),
                isExpanded: true,
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _buildTaxDropdownItem(
    String text,
    IconData icon,
    Color color,
  ) {
    return DropdownMenuItem(
      value: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElegantClearButton(SalesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            height: 48,
            width: 48,
            child: ElevatedButton(
              onPressed: provider.clearAllFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.blueGrey.shade700,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: Colors.blueGrey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayFilterText(SalesProvider provider) {
    if (provider.selectedDate == null) {
      return 'اختر التاريخ';
    }
    final date = provider.selectedDate!;
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
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

  Future<void> _selectDate(BuildContext context, SalesProvider provider) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue.shade700,
            colorScheme: ColorScheme.light(primary: Colors.blue.shade700),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      provider.setDateFilter(picked);
    }
  }

  Widget _buildSalesTable() {
    return Consumer2<SalesProvider, SettingsProvider>(
      builder: (context, salesProvider, settingsProvider, _) {
        final currencyName = settingsProvider.currencyName;

        if (salesProvider.sales.isEmpty && !salesProvider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 70, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'لا توجد فواتير',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    DataTable(
                      headingRowColor:
                          MaterialStateProperty.resolveWith<Color?>(
                            (Set<MaterialState> states) => Colors.blue[50],
                          ),
                      dataRowMaxHeight: 56,
                      dataRowMinHeight: 48,
                      headingTextStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                        fontSize: 15,
                      ),
                      dataTextStyle: const TextStyle(fontSize: 14),
                      columnSpacing: 70,
                      horizontalMargin: 20,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'رقم الفاتورة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'العميل',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'المبلغ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'الربح',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'النوع',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'التاريخ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'الوقت',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'الإجراءات',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows:
                          salesProvider.sales.asMap().entries.map((entry) {
                            final index = entry.key;
                            final sale = entry.value;

                            return DataRow(
                              onSelectChanged:
                                  (_) => _showSaleDetails(sale.id, context),
                              cells: [
                                DataCell(
                                  Text(
                                    (index + 1).toString(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    sale.customerName ?? "بدون عميل",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${sale.totalAmount.toStringAsFixed(0)} $currencyName',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${sale.totalProfit.toStringAsFixed(0)} $currencyName',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPaymentTypeColor(
                                        sale.paymentType,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      sale.paymentType == 'cash'
                                          ? 'نقدي'
                                          : 'آجل',
                                      style: TextStyle(
                                        color: _getPaymentTypeColor(
                                          sale.paymentType,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    sale.formattedDate,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    sale.formattedTime,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // زر التعديل
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.orange[700],
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) => PosScreen(
                                                      existingSale: sale,
                                                      isEditMode: true,
                                                    ),
                                              ),
                                            );
                                          },
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                          tooltip: 'تعديل الفاتورة',
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // زر الحذف/الإرجاع
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.red[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red[700],
                                          ),
                                          onPressed:
                                              () =>
                                                  _showDeleteConfirmationDialog(
                                                    context,
                                                    sale,
                                                  ),
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                          tooltip: 'حذف الفاتورة',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),

                    // مؤشر التحميل في نهاية الجدول
                    if (salesProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    // رسالة عند انتهاء جميع الفواتير
                    if (!salesProvider.hasMore && !salesProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'تم تحميل جميع الفواتير ✅',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // دالة لعرض تأكيد الحذف
  void _showDeleteConfirmationDialog(BuildContext context, Sale sale) {
    final settings = Provider.of<SettingsProvider>(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('تأكيد الحذف'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من رغبتك في حذف الفاتورة رقم ${sale.id}؟',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'المبلغ: ${sale.totalAmount.toStringAsFixed(0)} ${settings.currencyName}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'التاريخ: ${sale.formattedDate}',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إرجاع جميع الكميات إلى المخزون',
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSale(sale);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف الفاتورة'),
            ),
          ],
        );
      },
    );
  }

  // دالة حذف الفاتورة
  void _deleteSale(Sale sale) async {
    try {
      final provider = Provider.of<SalesProvider>(context, listen: false);
      await provider.deleteSale(sale.id!);

      // عرض رسالة نجاح
      showAppToast(
        context,
        'تم حذف الفاتورة رقم ${sale.id} بنجاح',
        ToastType.success,
      );
    } catch (e) {
      // عرض رسالة خطأ
      showAppToast(context, 'خطأ في حذف الفاتورة: $e', ToastType.error);
    }
  }

  Color _getPaymentTypeColor(String paymentType) {
    switch (paymentType) {
      case 'cash':
        return Colors.green;
      case 'credit':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _showSaleDetails(int saleId, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SaleDetailsDialog(saleId: saleId),
    );
  }
}
