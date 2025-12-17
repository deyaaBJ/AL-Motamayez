// screens/sales_history_screen.dart
import 'dart:async';

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
  final ScrollController _verticalScrollController = ScrollController();
  Timer? _filterDebounceTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SalesProvider>();

      // ✅ تحميل السنة الحالية مسبقاً
      provider.prefetchCurrentYear();

      if (provider.selectedYear == null) {
        provider.setYearFilter(DateTime.now().year);
      } else {
        // ✅ للسنة الحالية، استخدم forceRefresh دائمًا
        final isCurrentYear = provider.selectedYear == DateTime.now().year;
        provider.fetchSales(forceRefresh: isCurrentYear);
      }
    });
  }

  @override
  void dispose() {
    _filterDebounceTimer?.cancel();
    _verticalScrollController.dispose();
    super.dispose();
  }

  // ✅ دالة لمسح جميع الفلاتر عدا التاريخ
  void _clearFiltersExceptDate(SalesProvider provider) {
    provider.setCustomerFilter('الكل');
    provider.setPaymentTypeFilter('الكل');
    provider.setTaxFilter('الكل');
  }

  // ✅ دالة لتحديد ما إذا كانت قيمة Dropdown موجودة في القائمة
  bool _isValueInList(List<String> list, String? value) {
    if (value == null) return false;
    return list.contains(value);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'المبيعات',
        showAppBar: true,
        title: 'سجل الفواتير',
        actions: [
          IconButton(
            onPressed: () {
              context.read<SalesProvider>().fetchSales();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PosScreen()),
            );
          },
          backgroundColor: const Color(0xFF8B5FBF),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
        child: Consumer<SalesProvider>(
          builder: (context, provider, _) {
            // ✅ التحقق من صحة قيمة Dropdown قبل بناء الواجهة
            final validCustomerValue =
                _isValueInList(
                      provider.customerNames,
                      provider.selectedCustomer,
                    )
                    ? provider.selectedCustomer
                    : 'الكل';

            return LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 600;
                final bool isTablet =
                    constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
                final bool isDesktop = constraints.maxWidth >= 1024;

                return Column(
                  children: [
                    // ✅ قسم الفلاتر المتجاوب
                    _buildResponsiveFiltersSection(
                      isMobile,
                      isTablet,
                      isDesktop,
                      provider,
                      validCustomerValue,
                    ),
                    const SizedBox(height: 10),

                    // ✅ جدول/قائمة الفواتير المتجاوبة
                    Expanded(
                      child:
                          isMobile
                              ? _buildMobileSalesList()
                              : _buildDesktopDataTable(isTablet, isDesktop),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ✅ بناء قسم الفلاتر المتجاوب
  Widget _buildResponsiveFiltersSection(
    bool isMobile,
    bool isTablet,
    bool isDesktop,
    SalesProvider provider,
    String validCustomerValue,
  ) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.role;

    return Container(
      margin: EdgeInsets.all(isMobile ? 4 : 8),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: isMobile ? 10 : 20,
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
          Row(
            children: [
              Icon(
                Icons.filter_alt_rounded,
                color: Colors.blue.shade700,
                size: isMobile ? 18 : 22,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                'تصفية الفواتير',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isMobile)
            _buildMobileFiltersLayout(provider, role, validCustomerValue),
          if (isTablet)
            _buildTabletFiltersLayout(provider, role, validCustomerValue),
          if (isDesktop)
            _buildDesktopFiltersLayout(provider, role, validCustomerValue),
        ],
      ),
    );
  }

  // ✅ تصميم الفلاتر للموبايل مع validCustomerValue
  Widget _buildMobileFiltersLayout(
    SalesProvider provider,
    String? role,
    String validCustomerValue,
  ) {
    return Column(
      children: [
        _buildResponsivePaymentFilter(provider, true),
        const SizedBox(height: 10),
        _buildResponsiveCustomerFilter(provider, true, validCustomerValue),
        const SizedBox(height: 10),
        _buildResponsiveDateFilter(provider, true),
        if (role != 'tax') ...[
          const SizedBox(height: 10),
          _buildResponsiveTaxFilter(provider, true),
        ],
        const SizedBox(height: 10),
        _buildResponsiveClearButton(provider, true),
      ],
    );
  }

  // ✅ تصميم الفلاتر للتابلت
  Widget _buildTabletFiltersLayout(
    SalesProvider provider,
    String? role,
    String validCustomerValue,
  ) {
    return Column(
      children: [
        // الصف الأول
        Row(
          children: [
            Expanded(child: _buildResponsivePaymentFilter(provider, false)),
            const SizedBox(width: 8),
            Expanded(
              child: _buildResponsiveCustomerFilter(
                provider,
                false,
                validCustomerValue,
              ),
            ),
            const SizedBox(width: 8),
            _buildResponsiveClearButton(provider, false),
          ],
        ),
        const SizedBox(height: 10),
        // الصف الثاني
        Row(
          children: [
            Expanded(child: _buildResponsiveDateFilter(provider, false)),
            if (role != 'tax') ...[
              const SizedBox(width: 8),
              Expanded(child: _buildResponsiveTaxFilter(provider, false)),
            ],
          ],
        ),
      ],
    );
  }

  // ✅ تصميم الفلاتر للكمبيوتر
  Widget _buildDesktopFiltersLayout(
    SalesProvider provider,
    String? role,
    String validCustomerValue,
  ) {
    return Row(
      children: [
        Expanded(child: _buildResponsivePaymentFilter(provider, false)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildResponsiveCustomerFilter(
            provider,
            false,
            validCustomerValue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildResponsiveDateFilter(provider, false)),
        if (role != 'tax') ...[
          const SizedBox(width: 12),
          Expanded(child: _buildResponsiveTaxFilter(provider, false)),
        ],
        const SizedBox(width: 12),
        _buildResponsiveClearButton(provider, false),
      ],
    );
  }

  // ✅ فلتر نوع الدفع المتجاوب
  Widget _buildResponsivePaymentFilter(SalesProvider provider, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isMobile ? 6 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              right: isMobile ? 8 : 12,
              top: isMobile ? 6 : 8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payment_rounded,
                  size: isMobile ? 14 : 16,
                  color: Colors.blue.shade600,
                ),
                SizedBox(width: isMobile ? 3 : 4),
                Text(
                  'نوع الدفع',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: isMobile ? 42 : 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
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
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: isMobile ? 16 : 18,
                                color: color,
                              ),
                              SizedBox(width: isMobile ? 6 : 8),
                              Text(
                                displayText,
                                style: TextStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                onChanged:
                    (value) => _applyFilterWithDebounce(
                      () => provider.setPaymentTypeFilter(value),
                    ),
                icon: Padding(
                  padding: EdgeInsets.only(left: isMobile ? 4 : 8),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: isMobile ? 20 : 24,
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

  // ✅ فلتر العميل المتجاوب
  Widget _buildResponsiveCustomerFilter(
    SalesProvider provider,
    bool isMobile,
    String validCustomerValue,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isMobile ? 6 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              right: isMobile ? 8 : 12,
              top: isMobile ? 6 : 8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: isMobile ? 14 : 16,
                  color: Colors.purple.shade600,
                ),
                SizedBox(width: isMobile ? 3 : 4),
                Text(
                  'العميل',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: isMobile ? 42 : 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: validCustomerValue,
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
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: isMobile ? 16 : 18,
                                color: color,
                              ),
                              SizedBox(width: isMobile ? 6 : 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 14,
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
                onChanged:
                    (value) => _applyFilterWithDebounce(() {
                      if (value != null) {
                        provider.setCustomerFilter(value);
                      }
                    }),
                icon: Padding(
                  padding: EdgeInsets.only(left: isMobile ? 4 : 8),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: isMobile ? 20 : 24,
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

  // ✅ فلتر التاريخ المتجاوب
  Widget _buildResponsiveDateFilter(SalesProvider provider, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isMobile ? 6 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: isMobile ? 100 : 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: isMobile ? 6 : 8,
                top: isMobile ? 6 : 8,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: isMobile ? 14 : 16,
                    color: Colors.black87,
                  ),
                  SizedBox(width: isMobile ? 3 : 4),
                  Text(
                    'التاريخ',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: isMobile ? 36 : 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                border: Border.all(color: Colors.black54, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: provider.dateFilterType,
                  items: [
                    DropdownMenuItem(
                      value: 'day',
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 6 : 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.today_rounded,
                              size: isMobile ? 16 : 18,
                              color: Colors.black87,
                            ),
                            SizedBox(width: isMobile ? 4 : 6),
                            Text(
                              'يوم',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'month',
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 6 : 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_view_month_rounded,
                              size: isMobile ? 16 : 18,
                              color: Colors.black87,
                            ),
                            SizedBox(width: isMobile ? 4 : 6),
                            Text(
                              'شهر',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'year',
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 6 : 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: isMobile ? 16 : 18,
                              color: Colors.black87,
                            ),
                            SizedBox(width: isMobile ? 4 : 6),
                            Text(
                              'سنة',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged:
                      (value) => _applyFilterWithDebounce(() {
                        if (value != null) provider.setDateFilterType(value);
                      }),
                  icon: Padding(
                    padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: isMobile ? 20 : 24,
                      color: Colors.black87,
                    ),
                  ),
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _buildResponsiveDateFilterContent(provider, isMobile),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ محتوى فلتر التاريخ المتجاوب
  Widget _buildResponsiveDateFilterContent(
    SalesProvider provider,
    bool isMobile,
  ) {
    switch (provider.dateFilterType) {
      case 'day':
        return _buildResponsiveDayFilter(provider, isMobile);
      case 'month':
        return _buildResponsiveMonthFilter(provider, isMobile);
      case 'year':
        return _buildResponsiveYearFilter(provider, isMobile);
      default:
        return _buildResponsiveDayFilter(provider, isMobile);
    }
  }

  // ✅ فلتر اليوم المتجاوب
  Widget _buildResponsiveDayFilter(SalesProvider provider, bool isMobile) {
    return GestureDetector(
      onTap: () => _selectDate(context, provider, isMobile),
      child: Container(
        height: isMobile ? 42 : 48,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
          border: Border.all(color: Colors.black54, width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.grey[100]!, Colors.white],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getDayFilterText(provider),
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w500,
                color:
                    provider.selectedDate == null
                        ? Colors.black54
                        : Colors.black,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[200]!,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: isMobile ? 16 : 18,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ فلتر الشهر المتجاوب
  Widget _buildResponsiveMonthFilter(SalesProvider provider, bool isMobile) {
    return Container(
      height: isMobile ? 42 : 48,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                border: Border.all(color: Colors.black54, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: provider.selectedMonth,
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 6 : 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_view_month_rounded,
                              size: isMobile ? 14 : 16,
                              color: Colors.black87,
                            ),
                            SizedBox(width: isMobile ? 4 : 6),
                            Text(
                              _getMonthName(month),
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  onChanged:
                      (month) => _applyFilterWithDebounce(() {
                        if (month != null) {
                          provider.setMonthFilter(month);
                          if (provider.selectedYear == null) {
                            provider.setYearFilter(DateTime.now().year);
                          }
                          _clearFiltersExceptDate(provider);
                        }
                      }),
                  hint: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_view_month_rounded,
                          size: isMobile ? 14 : 16,
                          color: Colors.black87,
                        ),
                        SizedBox(width: isMobile ? 4 : 6),
                        Text(
                          'اختر الشهر',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  icon: Padding(
                    padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: isMobile ? 18 : 20,
                      color: Colors.black87,
                    ),
                  ),
                  isExpanded: true,
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                border: Border.all(color: Colors.black54, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: provider.selectedYear,
                  items: _generateYearItems(isMobile),
                  onChanged:
                      (year) => _applyFilterWithDebounce(() {
                        if (year != null) {
                          provider.setYearFilter(year);
                          if (provider.selectedMonth == null) {
                            provider.setMonthFilter(DateTime.now().month);
                          }
                          _clearFiltersExceptDate(provider);
                        }
                      }),
                  hint: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_note_rounded,
                          size: isMobile ? 14 : 16,
                          color: Colors.black87,
                        ),
                        SizedBox(width: isMobile ? 4 : 6),
                        Text(
                          'السنة',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  icon: Padding(
                    padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: isMobile ? 18 : 20,
                      color: Colors.black87,
                    ),
                  ),
                  isExpanded: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ فلتر السنة المتجاوب
  Widget _buildResponsiveYearFilter(SalesProvider provider, bool isMobile) {
    return Container(
      height: isMobile ? 42 : 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
        border: Border.all(color: Colors.black54, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: provider.selectedYear,
          items: _generateYearItems(isMobile),
          onChanged:
              (year) => _applyFilterWithDebounce(() {
                if (year != null) {
                  provider.setYearFilter(year);
                  _clearFiltersExceptDate(provider);
                }
              }),
          hint: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8),
            child: Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: isMobile ? 14 : 16,
                  color: Colors.black87,
                ),
                SizedBox(width: isMobile ? 4 : 6),
                Text(
                  'اختر السنة',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          icon: Padding(
            padding: EdgeInsets.only(left: isMobile ? 2 : 4),
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: isMobile ? 18 : 20,
              color: Colors.black87,
            ),
          ),
          isExpanded: true,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ✅ فلتر الضريبة المتجاوب
  Widget _buildResponsiveTaxFilter(SalesProvider provider, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isMobile ? 6 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              right: isMobile ? 8 : 12,
              top: isMobile ? 6 : 8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: isMobile ? 14 : 16,
                  color: Colors.teal.shade600,
                ),
                SizedBox(width: isMobile ? 3 : 4),
                Text(
                  'الضريبة',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: isMobile ? 42 : 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
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
                    isMobile,
                  ),
                  _buildTaxDropdownItem(
                    'مضمنه بالضرائب',
                    Icons.verified_rounded,
                    Colors.green,
                    isMobile,
                  ),
                  _buildTaxDropdownItem(
                    'غير مضمنه بالضرائب',
                    Icons.do_not_disturb_rounded,
                    Colors.red,
                    isMobile,
                  ),
                ],
                onChanged:
                    (value) => _applyFilterWithDebounce(
                      () => provider.setTaxFilter(value),
                    ),
                icon: Padding(
                  padding: EdgeInsets.only(left: isMobile ? 4 : 8),
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: isMobile ? 20 : 24,
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

  // ✅ عنصر قائمة الضريبة المتجاوب
  DropdownMenuItem<String> _buildTaxDropdownItem(
    String text,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return DropdownMenuItem(
      value: text,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
        child: Row(
          children: [
            Icon(icon, size: isMobile ? 16 : 18, color: color),
            SizedBox(width: isMobile ? 6 : 8),
            Text(
              text,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ زر مسح الفلاتر المتجاوب
  Widget _buildResponsiveClearButton(SalesProvider provider, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isMobile ? 6 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(height: isMobile ? 0 : 24),
          Container(
            height: isMobile ? 42 : 48,
            width: isMobile ? double.infinity : 48,
            child: ElevatedButton(
              onPressed: provider.clearFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.blueGrey.shade700,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                padding: EdgeInsets.zero,
              ),
              child:
                  isMobile
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: Colors.blueGrey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'مسح الفلاتر',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blueGrey.shade600,
                            ),
                          ),
                        ],
                      )
                      : Icon(
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

  // ✅ دالة مساعدة للـ Debounce على الفلاتر
  void _applyFilterWithDebounce(Function() filterFunction) {
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(
      const Duration(milliseconds: 300),
      filterFunction,
    );
  }

  // ✅ بناء قائمة الفواتير للعرض على الموبايل
  Widget _buildMobileSalesList() {
    return Consumer2<SalesProvider, SettingsProvider>(
      builder: (context, salesProvider, settingsProvider, _) {
        final currencyName = settingsProvider.currencyName;

        if (salesProvider.sales.isEmpty && !salesProvider.isLoading) {
          return _buildEmptyState(salesProvider);
        }

        return Column(
          children: [
            // ✅ رأس المعلومات مع أدوات التحديد
            _buildMobileTableHeader(salesProvider),

            // ✅ قائمة الفواتير
            Expanded(
              child: ListView.builder(
                controller: _verticalScrollController,
                itemCount: salesProvider.sales.length + 1,
                itemBuilder: (context, index) {
                  if (index == salesProvider.sales.length) {
                    if (salesProvider.isLoading) {
                      return _buildLoadingIndicator(salesProvider);
                    }
                    if (!salesProvider.hasMore &&
                        salesProvider.sales.isNotEmpty) {
                      return _buildEndOfListIndicator(salesProvider);
                    }
                    if (salesProvider.hasMore && !salesProvider.isLoading) {
                      return _buildLoadMoreButton(salesProvider);
                    }
                    return Container();
                  }

                  final sale = salesProvider.sales[index];
                  return _buildMobileSaleCard(
                    sale,
                    salesProvider,
                    settingsProvider,
                    index,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ بطاقة بيع للعرض على الموبايل
  Widget _buildMobileSaleCard(
    Sale sale,
    SalesProvider salesProvider,
    SettingsProvider settingsProvider,
    int index,
  ) {
    final isCurrentArchiveMode = salesProvider.isArchiveMode;
    final isSelected = salesProvider.selectedSaleIds.contains(sale.id);

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isCurrentArchiveMode
                  ? Colors.orange.shade100
                  : isSelected
                  ? Colors.blue.shade300
                  : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showSaleDetails(sale.id!, context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: رقم التسلسلي، Checkbox، رقم الفاتورة
              Row(
                children: [
                  // ✅ الرقم التسلسلي
                  Container(
                    width: 30,
                    alignment: Alignment.center,
                    child: Text(
                      (index + 1).toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),

                  // ✅ Checkbox التحديد
                  if (!isCurrentArchiveMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        salesProvider.toggleSaleSelection(sale.id!);
                      },
                    ),

                  const Spacer(),

                  // رقم الفاتورة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isCurrentArchiveMode
                              ? Colors.orange[50]
                              : Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${sale.id}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color:
                            isCurrentArchiveMode
                                ? Colors.orange[800]
                                : Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // الصف الثاني: نوع الدفع
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPaymentTypeColor(
                        sale.paymentType,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sale.paymentType == 'cash' ? 'نقدي' : 'آجل',
                      style: TextStyle(
                        color: _getPaymentTypeColor(sale.paymentType),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // معلومات العميل
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sale.customerName ?? "بدون عميل",
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // المعلومات المالية
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المبلغ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${sale.totalAmount.toStringAsFixed(0)} ${settingsProvider.currencyName}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // التاريخ والوقت
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    sale.formattedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    sale.formattedTime,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // أزرار الإجراءات
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // زر التعديل (غير متاح للأرشيف)
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      color:
                          isCurrentArchiveMode
                              ? Colors.grey[400]
                              : Colors.orange[700],
                      size: 22,
                    ),
                    onPressed:
                        isCurrentArchiveMode
                            ? null
                            : () {
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
                    tooltip: 'تعديل',
                  ),

                  // زر الحذف/الإرجاع (غير متاح للأرشيف)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color:
                          isCurrentArchiveMode
                              ? Colors.grey[400]
                              : Colors.red[700],
                      size: 22,
                    ),
                    onPressed:
                        isCurrentArchiveMode
                            ? null
                            : () =>
                                _showDeleteConfirmationDialog(context, sale),
                    tooltip: 'حذف',
                  ),

                  // زر التفاصيل
                  IconButton(
                    icon: Icon(
                      Icons.visibility,
                      color:
                          isCurrentArchiveMode
                              ? Colors.blue[600]
                              : Colors.blue[700],
                      size: 22,
                    ),
                    onPressed: () => _showSaleDetails(sale.id!, context),
                    tooltip: 'تفاصيل',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ بناء جدول الفواتير للعرض على الكمبيوتر/التابلت
  Widget _buildDesktopDataTable(bool isTablet, bool isDesktop) {
    return Consumer2<SalesProvider, SettingsProvider>(
      builder: (context, salesProvider, settingsProvider, _) {
        final currencyName = settingsProvider.currencyName;
        final hasSelectedSales = salesProvider.selectedSaleIds.isNotEmpty;

        if (salesProvider.sales.isEmpty && !salesProvider.isLoading) {
          return _buildEmptyState(salesProvider);
        }

        // تحديد الأعمدة التي ستظهر بناءً على حجم الشاشة
        final showProfitColumn =
            isDesktop || (isTablet && !salesProvider.isArchiveMode);
        final showTimeColumn = isDesktop;
        final showCustomerColumn = isDesktop || isTablet;

        return Column(
          children: [
            // ✅ شريط التحديد Sticky (يظهر فقط عند التحديد)
            if (hasSelectedSales && !salesProvider.isArchiveMode)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[100]!),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${salesProvider.selectedSaleIds.length} فاتورة محددة',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),

                    // زر تحويل للكاش
                    ElevatedButton.icon(
                      icon: Icon(Icons.money_off, size: 16),
                      label: Text('تحويل لكاش'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[500],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        _showBatchPaymentDialog(context, salesProvider, 'cash');
                      },
                    ),

                    const SizedBox(width: 8),

                    // زر تحويل لأجل
                    ElevatedButton.icon(
                      icon: Icon(Icons.credit_card, size: 16),
                      label: Text('تحويل لأجل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[500],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        _showBatchPaymentDialog(
                          context,
                          salesProvider,
                          'credit',
                        );
                      },
                    ),

                    const SizedBox(width: 12),

                    // زر إلغاء التحديد
                    IconButton(
                      icon: Icon(Icons.clear, size: 20),
                      onPressed: () {
                        salesProvider.clearSelection();
                      },
                      tooltip: 'إلغاء التحديد',
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),

            // الجدول الرئيسي
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: isTablet ? 8 : 16,
                  vertical: 0,
                ),
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
                constraints: const BoxConstraints(minHeight: 200),
                child: Column(
                  children: [
                    // رأس المعلومات مع مؤشر الأرشيف
                    _buildTableHeader(salesProvider),

                    // ✅ الجدول مع التمرير
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingRowColor:
                                MaterialStateProperty.resolveWith<Color?>(
                                  (Set<MaterialState> states) =>
                                      salesProvider.isArchiveMode
                                          ? Colors.orange[50]
                                          : Colors.blue[50],
                                ),
                            dataRowMaxHeight: 56,
                            dataRowMinHeight: 48,
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  salesProvider.isArchiveMode
                                      ? Colors.orange[800]
                                      : Colors.blue[800],
                              fontSize: isTablet ? 14 : 15,
                            ),
                            dataTextStyle: TextStyle(
                              fontSize: isTablet ? 13 : 14,
                            ),
                            columnSpacing: isTablet ? 40 : 70,
                            horizontalMargin: isTablet ? 10 : 20,
                            columns: _buildDataTableColumns(
                              showProfitColumn,
                              showTimeColumn,
                              showCustomerColumn,
                              salesProvider,
                            ),
                            rows: _buildDataTableRows(
                              salesProvider,
                              settingsProvider,
                              salesProvider.sales,
                              showProfitColumn,
                              showTimeColumn,
                              showCustomerColumn,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ✅ مؤشرات التحميل والرسائل
                    if (salesProvider.isLoading)
                      _buildLoadingIndicator(salesProvider),

                    if (!salesProvider.hasMore &&
                        salesProvider.sales.isNotEmpty &&
                        !salesProvider.isLoading)
                      _buildEndOfListIndicator(salesProvider),

                    // ✅ زر تحميل المزيد
                    if (salesProvider.hasMore &&
                        !salesProvider.isLoading &&
                        salesProvider.sales.isNotEmpty)
                      _buildLoadMoreButton(salesProvider),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ بناء أعمدة الجدول بشكل ديناميكي
  List<DataColumn> _buildDataTableColumns(
    bool showProfitColumn,
    bool showTimeColumn,
    bool showCustomerColumn,
    SalesProvider salesProvider,
  ) {
    final columns = <DataColumn>[];
    if (!salesProvider.isArchiveMode) {
      columns.add(DataColumn(label: _buildSelectAllHeader(salesProvider)));
    }
    // ✅ عمود الرقم التسلسلي
    columns.add(
      DataColumn(
        label: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
    );

    // ✅ عمود Checkbox التحديد (مخفي في الأرشيف)

    if (showCustomerColumn) {
      columns.add(
        DataColumn(
          label: Text('العميل', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }

    columns.addAll([
      DataColumn(
        label: Text('المبلغ', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
    ]);

    columns.addAll([
      DataColumn(
        label: Text('النوع', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      DataColumn(
        label: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ]);

    columns.add(
      DataColumn(
        label: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );

    return columns;
  }

  // ✅ دالة لبناء header التحديد (Select All)
  Widget _buildSelectAllHeader(SalesProvider salesProvider) {
    final shownSales = salesProvider.sales;
    final allSelected =
        shownSales.isNotEmpty &&
        shownSales.every(
          (sale) => salesProvider.selectedSaleIds.contains(sale.id),
        );

    return Checkbox(
      value: allSelected,
      onChanged: (value) {
        if (value == true) {
          salesProvider.selectAllShownSales(shownSales);
        } else {
          salesProvider.clearSelection();
        }
      },
    );
  }

  // ✅ بناء صفوف الجدول بشكل ديناميكي
  List<DataRow> _buildDataTableRows(
    SalesProvider salesProvider,
    SettingsProvider settingsProvider,
    List<Sale> sales,
    bool showProfitColumn,
    bool showTimeColumn,
    bool showCustomerColumn,
  ) {
    return List<DataRow>.generate(
      sales.length,
      (index) => _buildDataRow(
        sales[index],
        salesProvider,
        settingsProvider,
        Key('sale_row_${sales[index].id}_${sales[index].date}'),
        showProfitColumn,
        showTimeColumn,
        showCustomerColumn,
        index,
      ),
      growable: false,
    );
  }

  // ✅ بناء صف واحد بشكل ديناميكي
  DataRow _buildDataRow(
    Sale sale,
    SalesProvider salesProvider,
    SettingsProvider settingsProvider,
    Key key,
    bool showProfitColumn,
    bool showTimeColumn,
    bool showCustomerColumn,
    int index,
  ) {
    final isCurrentArchiveMode = salesProvider.isArchiveMode;
    final isSelected = salesProvider.selectedSaleIds.contains(sale.id);
    final cells = <DataCell>[];
    // ✅ خلية Checkbox التحديد (مخفية في الأرشيف)
    if (!isCurrentArchiveMode) {
      cells.add(
        DataCell(
          Checkbox(
            value: isSelected,
            onChanged: (value) {
              salesProvider.toggleSaleSelection(sale.id!);
            },
          ),
        ),
      );
    }
    // ✅ خلية الرقم التسلسلي
    cells.add(
      DataCell(
        Container(
          alignment: Alignment.center,
          child: Text(
            (index + 1).toString(),
            style: TextStyle(
              fontSize: 14,
              color: isCurrentArchiveMode ? Colors.grey[600] : Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );

    // خلية العميل (إذا كانت معروضة)
    if (showCustomerColumn) {
      cells.add(
        DataCell(
          Text(
            sale.customerName ?? "بدون عميل",
            style: TextStyle(
              fontSize: 14,
              color:
                  isSelected
                      ? Colors.blue[700]
                      : isCurrentArchiveMode
                      ? Colors.grey[700]
                      : Colors.grey[800],
            ),
          ),
        ),
      );
    }

    // خلية المبلغ
    cells.add(
      DataCell(
        Text(
          '${sale.totalAmount.toStringAsFixed(0)} ${settingsProvider.currencyName}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.green[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    // خلية النوع
    cells.add(
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _getPaymentTypeColor(sale.paymentType).withOpacity(
              isSelected ? 0.15 : (isCurrentArchiveMode ? 0.05 : 0.1),
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getPaymentTypeColor(sale.paymentType).withOpacity(
                isSelected ? 0.3 : (isCurrentArchiveMode ? 0.2 : 0.3),
              ),
              width: 1,
            ),
          ),
          child: Text(
            sale.paymentType == 'cash' ? 'نقدي' : 'آجل',
            style: TextStyle(
              color: _getPaymentTypeColor(sale.paymentType).withOpacity(
                isSelected ? 1.0 : (isCurrentArchiveMode ? 0.6 : 1.0),
              ),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    // خلية التاريخ
    cells.add(
      DataCell(
        Text(
          sale.formattedDate,
          style: TextStyle(
            fontSize: 14,
            color:
                isSelected
                    ? Colors.blue[700]
                    : isCurrentArchiveMode
                    ? Colors.grey[600]
                    : Colors.grey[800],
          ),
        ),
      ),
    );

    // خلية الإجراءات
    cells.add(
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // زر التعديل (غير متاح للأرشيف)
            Container(
              decoration: BoxDecoration(
                color:
                    isCurrentArchiveMode ? Colors.grey[100] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isCurrentArchiveMode
                          ? Colors.grey[300]!
                          : Colors.orange[200]!,
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.edit,
                  size: 18,
                  color:
                      isCurrentArchiveMode
                          ? Colors.grey[400]
                          : Colors.orange[700],
                ),
                onPressed:
                    isCurrentArchiveMode
                        ? null
                        : () {
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
                tooltip:
                    isCurrentArchiveMode
                        ? 'لا يمكن تعديل الفواتير المؤرشفة'
                        : 'تعديل الفاتورة',
              ),
            ),
            const SizedBox(width: 8),

            // زر الحذف/الإرجاع (غير متاح للأرشيف)
            Container(
              decoration: BoxDecoration(
                color: isCurrentArchiveMode ? Colors.grey[100] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isCurrentArchiveMode
                          ? Colors.grey[300]!
                          : Colors.red[200]!,
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color:
                      isCurrentArchiveMode ? Colors.grey[400] : Colors.red[700],
                ),
                onPressed:
                    isCurrentArchiveMode
                        ? null
                        : () => _showDeleteConfirmationDialog(context, sale),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip:
                    isCurrentArchiveMode
                        ? 'لا يمكن حذف الفواتير المؤرشفة'
                        : 'حذف الفاتورة',
              ),
            ),

            // ✅ زر التفاصيل الإضافية
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: isCurrentArchiveMode ? Colors.blue[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isCurrentArchiveMode
                          ? Colors.blue[200]!
                          : Colors.blue[200]!,
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.visibility,
                  size: 18,
                  color:
                      isCurrentArchiveMode
                          ? Colors.blue[600]
                          : Colors.blue[700],
                ),
                onPressed: () => _showSaleDetails(sale.id!, context),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'عرض التفاصيل',
              ),
            ),
          ],
        ),
      ),
    );

    return DataRow(
      key: ValueKey(key),
      onSelectChanged: (_) => _showSaleDetails(sale.id!, context),
      color: MaterialStateProperty.resolveWith<Color?>((
        Set<MaterialState> states,
      ) {
        if (isSelected) {
          return Colors.blue[50];
        }
        return null;
      }),
      cells: cells,
    );
  }

  // ✅ رأس الجدول للكمبيوتر/التابلت
  Widget _buildTableHeader(SalesProvider salesProvider) {
    final hasSelectedSales = salesProvider.selectedSaleIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            salesProvider.isArchiveMode ? Colors.orange[50] : Colors.blue[50],
        border: Border(
          bottom: BorderSide(
            color:
                salesProvider.isArchiveMode
                    ? Colors.orange[100]!
                    : Colors.blue[100]!,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                salesProvider.isArchiveMode ? Icons.archive : Icons.list_alt,
                size: 18,
                color:
                    salesProvider.isArchiveMode
                        ? Colors.orange[700]
                        : Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salesProvider.isArchiveMode
                          ? 'أرشيف الفواتير'
                          : 'الفواتير الحالية',
                      style: TextStyle(
                        color:
                            salesProvider.isArchiveMode
                                ? Colors.orange[700]
                                : Colors.blue[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasSelectedSales
                          ? '${salesProvider.selectedSaleIds.length} فاتورة محددة من ${salesProvider.sales.length} فاتورة معروضة'
                          : 'عرض ${salesProvider.sales.length} من إجمالي ${salesProvider.loadedSalesCount} فاتورة',
                      style: TextStyle(
                        color:
                            salesProvider.isArchiveMode
                                ? Colors.orange[600]
                                : Colors.blue[600],
                        fontSize: 11,
                      ),
                    ),
                    if (salesProvider.isFilterActive) ...[
                      const SizedBox(height: 2),
                      Text(
                        salesProvider.activeFiltersDescription,
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),

              // ✅ أزرار التعديل الجماعي في Header
              if (hasSelectedSales && !salesProvider.isArchiveMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // زر تحويل للكاش
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.money_off,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        onPressed: () {
                          _showBatchPaymentDialog(
                            context,
                            salesProvider,
                            'cash',
                          );
                        },
                        tooltip: 'تحويل الفواتير المحددة لكاش',
                      ),
                    ),
                    const SizedBox(width: 8),

                    // زر تحويل لأجل
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.credit_card,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        onPressed: () {
                          _showBatchPaymentDialog(
                            context,
                            salesProvider,
                            'credit',
                          );
                        },
                        tooltip: 'تحويل الفواتير المحددة لأجل',
                      ),
                    ),
                    const SizedBox(width: 8),

                    // زر إلغاء التحديد
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        salesProvider.clearSelection();
                      },
                      tooltip: 'إلغاء التحديد',
                    ),
                  ],
                ),

              if (salesProvider.isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        salesProvider.isArchiveMode
                            ? Colors.orange
                            : Colors.blue,
                  ),
                ),
            ],
          ),

          // ✅ مؤشر الأرشيف مع معلومات إضافية
          if (salesProvider.isArchiveMode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'عرض فواتير سنة ${salesProvider.selectedYear} من الأرشيف - للقراءة فقط',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ رأس الجدول للعرض على الموبايل
  Widget _buildMobileTableHeader(SalesProvider salesProvider) {
    final hasSelectedSales = salesProvider.selectedSaleIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            salesProvider.isArchiveMode ? Colors.orange[50] : Colors.blue[50],
        border: Border(
          bottom: BorderSide(
            color:
                salesProvider.isArchiveMode
                    ? Colors.orange[100]!
                    : Colors.blue[100]!,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                salesProvider.isArchiveMode ? Icons.archive : Icons.list_alt,
                size: 18,
                color:
                    salesProvider.isArchiveMode
                        ? Colors.orange[700]
                        : Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salesProvider.isArchiveMode
                          ? 'أرشيف الفواتير'
                          : 'الفواتير الحالية',
                      style: TextStyle(
                        color:
                            salesProvider.isArchiveMode
                                ? Colors.orange[700]
                                : Colors.blue[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasSelectedSales
                          ? '${salesProvider.selectedSaleIds.length} فاتورة محددة'
                          : 'عرض ${salesProvider.sales.length} فاتورة',
                      style: TextStyle(
                        color:
                            salesProvider.isArchiveMode
                                ? Colors.orange[600]
                                : Colors.blue[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ أزرار التعديل الجماعي في الموبايل
              if (hasSelectedSales && !salesProvider.isArchiveMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.money_off,
                        size: 18,
                        color: Colors.green[700],
                      ),
                      onPressed: () {
                        _showBatchPaymentDialog(context, salesProvider, 'cash');
                      },
                      tooltip: 'تحويل للكاش',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.credit_card,
                        size: 18,
                        color: Colors.orange[700],
                      ),
                      onPressed: () {
                        _showBatchPaymentDialog(
                          context,
                          salesProvider,
                          'credit',
                        );
                      },
                      tooltip: 'تحويل لأجل',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        salesProvider.clearSelection();
                      },
                      tooltip: 'إلغاء التحديد',
                    ),
                  ],
                ),

              if (salesProvider.isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        salesProvider.isArchiveMode
                            ? Colors.orange
                            : Colors.blue,
                  ),
                ),
            ],
          ),

          // ✅ أزرار التعديل الجماعي أسفل Header في الموبايل
          if (hasSelectedSales && !salesProvider.isArchiveMode)
            Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.money_off, size: 16),
                        label: Text('تحويل للكاش'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[500],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () {
                          _showBatchPaymentDialog(
                            context,
                            salesProvider,
                            'cash',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.credit_card, size: 16),
                        label: Text('تحويل لأجل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[500],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () {
                          _showBatchPaymentDialog(
                            context,
                            salesProvider,
                            'credit',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ✅ مؤشر التحميل
  Widget _buildLoadingIndicator(SalesProvider salesProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          color: salesProvider.isArchiveMode ? Colors.orange : Colors.blue,
        ),
      ),
    );
  }

  // ✅ مؤشر نهاية القائمة
  Widget _buildEndOfListIndicator(SalesProvider salesProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            salesProvider.isArchiveMode ? Icons.archive : Icons.check_circle,
            size: 16,
            color:
                salesProvider.isArchiveMode
                    ? Colors.orange[600]
                    : Colors.green[600],
          ),
          const SizedBox(width: 8),
          Text(
            salesProvider.isArchiveMode
                ? 'تم تحميل جميع الفواتير المؤرشفة'
                : 'تم تحميل جميع الفواتير ✅',
            style: TextStyle(
              color:
                  salesProvider.isArchiveMode
                      ? Colors.orange[600]
                      : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ زر تحميل المزيد
  Widget _buildLoadMoreButton(SalesProvider salesProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: ElevatedButton.icon(
          icon: Icon(Icons.expand_more, size: 18),
          label: const Text('تحميل المزيد'),
          onPressed: () => salesProvider.loadMoreSales(),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                salesProvider.isArchiveMode
                    ? Colors.orange[100]
                    : Colors.blue[50],
            foregroundColor:
                salesProvider.isArchiveMode
                    ? Colors.orange[700]
                    : Colors.blue[700],
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color:
                    salesProvider.isArchiveMode
                        ? Colors.orange[200]!
                        : Colors.blue[200]!,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ حالة عدم وجود فواتير
  Widget _buildEmptyState(SalesProvider salesProvider) {
    if (salesProvider.hasLoadedSales) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 70, color: Colors.orange[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد فواتير تطابق الفلاتر',
              style: TextStyle(
                fontSize: 18,
                color: Colors.orange[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => salesProvider.clearAllFilters(),
              child: const Text('إزالة الفلاتر'),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'لا توجد فواتير',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث'),
              onPressed: () => salesProvider.fetchSales(),
            ),
          ],
        ),
      );
    }
  }

  // ✅ باقي الدوال المساعدة
  String _getDayFilterText(SalesProvider provider) {
    if (provider.selectedDate == null) return 'اختر التاريخ';
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

  List<DropdownMenuItem<int>> _generateYearItems(bool isMobile) {
    final currentYear = DateTime.now().year;
    return List.generate(5, (index) {
      final year = currentYear - index;
      return DropdownMenuItem(
        value: year,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8),
          child: Row(
            children: [
              Icon(
                Icons.event_note_rounded,
                size: isMobile ? 14 : 16,
                color: Colors.black87,
              ),
              SizedBox(width: isMobile ? 4 : 6),
              Text(
                year.toString(),
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _selectDate(
    BuildContext context,
    SalesProvider provider,
    bool isMobile,
  ) async {
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
      _applyFilterWithDebounce(() {
        provider.setDateFilter(picked);
        _clearFiltersExceptDate(provider);
      });
    }
  }

  // ✅ دالة لعرض تأكيد التعديل الجماعي
  Future<void> _showBatchPaymentDialog(
    BuildContext context,
    SalesProvider salesProvider,
    String targetPaymentType,
  ) async {
    final paymentName = targetPaymentType == 'cash' ? 'نقدي' : 'آجل';
    final count = salesProvider.selectedSaleIds.length;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تغيير طريقة الدفع'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل تريد تغيير طريقة الدفع لـ $count فاتورة إلى $paymentName؟',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        targetPaymentType == 'cash'
                            ? Colors.green[50]
                            : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          targetPaymentType == 'cash'
                              ? Colors.green[200]!
                              : Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color:
                            targetPaymentType == 'cash'
                                ? Colors.green[700]
                                : Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم تطبيق التغيير على جميع الفواتير المحددة',
                          style: TextStyle(
                            color:
                                targetPaymentType == 'cash'
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('تأكيد التغيير ($count فاتورة)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      targetPaymentType == 'cash'
                          ? Colors.green
                          : Colors.orange,
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await salesProvider.updateMultiplePaymentTypes(targetPaymentType);
        showAppToast(
          context,
          'تم تغيير طريقة الدفع لـ $count فاتورة إلى $paymentName',
          ToastType.success,
        );
      } catch (e) {
        showAppToast(context, 'حدث خطأ أثناء التغيير: $e', ToastType.error);
      }
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, Sale sale) {
    final provider = Provider.of<SalesProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (provider.isArchiveMode) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.archive, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text('فاتورة مؤرشفة'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('لا يمكن حذف الفواتير المؤرشفة.'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الفواتير القديمة مخزنة في الأرشيف للرجوع إليها فقط',
                            style: TextStyle(color: Colors.orange[700]),
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
                  child: const Text('حسناً'),
                ),
              ],
            ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                Text('هل أنت متأكد من رغبتك في حذف الفاتورة رقم ${sale.id}؟'),
                const SizedBox(height: 8),
                Text(
                  'المبلغ: ${sale.totalAmount.toStringAsFixed(0)} ${settings.currencyName}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text('التاريخ: ${sale.formattedDate}'),
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
                      Icon(
                        Icons.info_outline,
                        color: Colors.red[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم إرجاع جميع الكميات إلى المخزون',
                          style: TextStyle(color: Colors.red[700]),
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
                child: const Text('إلغاء'),
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
          ),
    );
  }

  void _deleteSale(Sale sale) async {
    try {
      final provider = Provider.of<SalesProvider>(context, listen: false);
      if (provider.isArchiveMode) {
        showAppToast(context, 'لا يمكن حذف فواتير الأرشيف', ToastType.warning);
        return;
      }
      await provider.deleteSale(sale.id!);
      showAppToast(
        context,
        'تم حذف الفاتورة رقم ${sale.id} بنجاح',
        ToastType.success,
      );
    } catch (e) {
      showAppToast(context, 'خطأ في حذف الفاتورة: $e', ToastType.error);
    }
  }

  void _showSaleDetails(int saleId, BuildContext context) {
    final provider = Provider.of<SalesProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => SaleDetailsDialog(saleId: saleId),
    );
  }

  Color _getPaymentTypeColor(String paymentType) {
    return paymentType == 'cash' ? Colors.green : Colors.orange;
  }
}
