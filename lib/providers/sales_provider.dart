// providers/sales_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../db/db_helper.dart';
import '../models/sale.dart';
import '../utils/app_logger.dart';
import 'debt_provider.dart';
import 'dart:developer';

class SalesProvider extends ChangeNotifier {
  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ المتغيرات الأساسية ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  int _page = 0;
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoading = false;
  int _requestSerial = 0;

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  final DBHelper _dbHelper = DBHelper();

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ نظام الـ Cache ███████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  final Map<String, List<Sale>> _salesCache = {};
  String? _currentCacheKey;
  Timer? _cacheCleanupTimer;

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الفلاتر الحقيقية (المطبقة) ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  String _selectedPaymentType = 'الكل';
  String _selectedCustomer = 'الكل';
  String _selectedTaxFilter = 'الكل';
  DateTime? _selectedDate;
  String _dateFilterType = 'day';
  int? _selectedMonth;
  int? _selectedYear;

  // Getters للفلاتر المطبقة
  String get selectedPaymentType => _selectedPaymentType;
  String get selectedCustomer => _selectedCustomer;
  DateTime? get selectedDate => _selectedDate;
  String get selectedTaxFilter => _selectedTaxFilter;
  String get dateFilterType => _dateFilterType;
  int? get selectedMonth => _selectedMonth;
  int? get selectedYear => _selectedYear;

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الفلاتر المؤقتة (للاختيار) ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████
  bool _taxUserMode = false;

  String _tempSelectedPaymentType = 'الكل';
  String _tempSelectedCustomer = 'الكل';
  String _tempSelectedTaxFilter = 'الكل';
  DateTime? _tempSelectedDate;
  String _tempDateFilterType = 'day';
  int? _tempSelectedMonth;
  int? _tempSelectedYear;

  // Getters للفلاتر المؤقتة
  String get tempSelectedPaymentType => _tempSelectedPaymentType;
  String get tempSelectedCustomer => _tempSelectedCustomer;
  DateTime? get tempSelectedDate => _tempSelectedDate;
  String get tempSelectedTaxFilter => _tempSelectedTaxFilter;
  String get tempDateFilterType => _tempDateFilterType;
  int? get tempSelectedMonth => _tempSelectedMonth;
  int? get tempSelectedYear => _tempSelectedYear;

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ بيانات الفواتير ███████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  List<Sale> _allSales = [];
  List<Sale> _displayedSales = [];

  List<Sale> get sales => _displayedSales;
  int get loadedSalesCount => _allSales.length;
  bool get hasLoadedSales => _allSales.isNotEmpty;

  List<int> selectedSaleIds = [];
  bool isBatchEditing = false;
  int todaySalesCount = 0;

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ Getters جديدة ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  List<String> get paymentTypes => [
    'الكل',
    'cash',
    'credit',
    'debt',
    'settled',
  ];

  List<String> get customerNames {
    final Set<String> names = {'الكل'};
    for (var sale in _allSales) {
      final normalizedName = sale.customerName?.trim();
      if (normalizedName != null && normalizedName.isNotEmpty) {
        names.add(normalizedName);
      } else {
        names.add('بدون عميل');
      }
    }
    final customerList = names.where((name) => name != 'الكل').toList()..sort();
    return ['الكل', ...customerList];
  }

  List<String> get months => [
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

  List<int> get years {
    final currentYear = DateTime.now().year;
    return List.generate(5, (index) => currentYear - index);
  }

  String get filteredPercentage {
    if (_allSales.isEmpty) return "0%";
    final percentage =
        (_displayedSales.length / _allSales.length * 100).toInt();
    return "$percentage%";
  }

  bool get isFilterActive {
    return _selectedPaymentType != 'الكل' ||
        _selectedCustomer != 'الكل' ||
        _selectedTaxFilter != 'الكل' ||
        _selectedDate != null ||
        _selectedMonth != null ||
        _selectedYear != null ||
        _dateFilterType != 'day';
  }

  bool get isArchiveMode {
    if (_dateFilterType == 'year' && _selectedYear != null) {
      return _selectedYear! < DateTime.now().year;
    }
    if (_dateFilterType == 'month' && _selectedYear != null) {
      return _selectedYear! < DateTime.now().year;
    }
    if (_dateFilterType == 'day' && _selectedDate != null) {
      return _selectedDate!.year < DateTime.now().year;
    }
    return false;
  }

  String get activeFiltersDescription {
    final filters = <String>[];

    if (_selectedPaymentType != 'الكل') {
      filters.add('دفع: ${_getPaymentFilterLabel(_selectedPaymentType)}');
    }

    if (_selectedCustomer != 'الكل') {
      filters.add('عميل: $_selectedCustomer');
    }

    if (_selectedTaxFilter != 'الكل') {
      filters.add('ضريبة: $_selectedTaxFilter');
    }

    if (_dateFilterType == 'day' && _selectedDate != null) {
      final date = _selectedDate!;
      filters.add('تاريخ: ${date.year}-${date.month}-${date.day}');
    } else if (_dateFilterType == 'month' &&
        _selectedMonth != null &&
        _selectedYear != null) {
      filters.add('شهر: ${months[_selectedMonth! - 1]} $_selectedYear');
    } else if (_dateFilterType == 'year' && _selectedYear != null) {
      filters.add('سنة: $_selectedYear');
    }

    return filters.isEmpty ? 'لا توجد فلاتر' : filters.join('، ');
  }

  String _getPaymentFilterLabel(String paymentType) {
    switch (paymentType) {
      case 'cash':
        return 'نقدي';
      case 'credit':
        return 'آجل';
      case 'debt':
        return 'دين';
      case 'settled':
        return 'مسدد';
      default:
        return paymentType;
    }
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ Constructor ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  SalesProvider() {
    // تهيئة الفلاتر المؤقتة بقيم الفلاتر الحقيقية
    _tempSelectedPaymentType = _selectedPaymentType;
    _tempSelectedCustomer = _selectedCustomer;
    _tempSelectedTaxFilter = _selectedTaxFilter;
    _tempSelectedDate = _selectedDate;
    _tempDateFilterType = _dateFilterType;
    _tempSelectedMonth = _selectedMonth;
    _tempSelectedYear = _selectedYear;

    // تنظيف الـ cache كل 5 دقائق
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupOldCache();
    });
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    super.dispose();
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال الفلاتر المؤقتة ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  void setTempDateFilterType(String type) {
    _tempDateFilterType = type;
    // إعادة تعيين القيم المؤقتة الأخرى عند تغيير النوع
    if (type == 'day') {
      _tempSelectedMonth = null;
      _tempSelectedYear = null;
    } else if (type == 'month') {
      _tempSelectedDate = null;
    } else if (type == 'year') {
      _tempSelectedDate = null;
      _tempSelectedMonth = null;
    }
    notifyListeners();
  }

  void setTempMonthFilter(int month) {
    _tempSelectedMonth = month;
    _tempDateFilterType = 'month';
    notifyListeners();
  }

  void setTempYearFilter(int year) {
    _tempSelectedYear = year;
    _tempDateFilterType = 'year';
    notifyListeners();
  }

  void setTempDateFilter(DateTime? date) {
    _tempSelectedDate = date;
    _tempDateFilterType = 'day';
    notifyListeners();
  }

  void setTempPaymentTypeFilter(String? value) {
    _tempSelectedPaymentType = value ?? 'الكل';
    notifyListeners();
  }

  void setTempCustomerFilter(String? value) {
    _tempSelectedCustomer = value ?? 'الكل';
    notifyListeners();
  }

  void setTempTaxFilter(String? value) {
    _tempSelectedTaxFilter = value ?? 'الكل';
    notifyListeners();
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال التطبيق والتحقق ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  // ✅ تحقق من اكتمال الاختيار (لتمكين زر التطبيق)
  bool get isTempFilterComplete {
    switch (_tempDateFilterType) {
      case 'day':
        return _tempSelectedDate != null;
      case 'month':
        return _tempSelectedMonth != null && _tempSelectedYear != null;
      case 'year':
        return _tempSelectedYear != null;
      default:
        return false;
    }
  }

  // ✅ تطبيق الفلاتر المؤقتة (نسخ من المؤقت إلى الحقيقي وتنفيذ البحث)
  Future<void> applyTempFilters() async {
    if (!isTempFilterComplete) return;

    // نسخ القيم المؤقتة إلى الحقيقية
    _selectedPaymentType = _tempSelectedPaymentType;
    _selectedCustomer = _tempSelectedCustomer;
    _selectedTaxFilter = _tempSelectedTaxFilter;
    _selectedDate = _tempSelectedDate;
    _dateFilterType = _tempDateFilterType;
    _selectedMonth = _tempSelectedMonth;
    _selectedYear = _tempSelectedYear;

    // إعادة تعيين وجلب البيانات
    _resetAndFetch(forceRefresh: true);
    notifyListeners();
  }

  // ✅ إعادة تعيين الفلاتر المؤقتة إلى القيم الحالية
  void resetTempFilters() {
    _tempSelectedPaymentType = _selectedPaymentType;
    _tempSelectedCustomer = _selectedCustomer;
    _tempSelectedTaxFilter = _selectedTaxFilter;
    _tempSelectedDate = _selectedDate;
    _tempDateFilterType = _dateFilterType;
    _tempSelectedMonth = _selectedMonth;
    _tempSelectedYear = _selectedYear;
    notifyListeners();
  }

  void resetPagination() {
    _page = 0;
    _hasMore = true;
    _isLoading = false;
    notifyListeners();
  }

  // ✅ دالة لإعادة تعيين كل شيء مع الحفاظ على Cache
  void resetForNewSearch() {
    _page = 0;
    _allSales.clear();
    _displayedSales.clear();
    _hasMore = true;
    selectedSaleIds.clear();
    _currentCacheKey = null;
    notifyListeners();
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال الفلاتر الحقيقية ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████
  void setPaymentTypeFilter(String? value) {
    _selectedPaymentType = value ?? 'الكل';
    _tempSelectedPaymentType = _selectedPaymentType;
    resetForNewSearch(); // ✅ إعادة تعيين للبحث الجديد
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void setCustomerFilter(String? value) {
    _selectedCustomer = value ?? 'الكل';
    _tempSelectedCustomer = _selectedCustomer;
    resetForNewSearch(); // ✅ إعادة تعيين للبحث الجديد
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void setDateFilter(DateTime? date) {
    _selectedDate = date;
    _tempSelectedDate = date;
    _dateFilterType = 'day';
    _tempDateFilterType = 'day';
    resetForNewSearch(); // ✅ إعادة تعيين للبحث الجديد
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void applyDayFilter(DateTime? date) {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';
    _selectedDate = date;
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';

    _tempSelectedPaymentType = 'الكل';
    _tempSelectedCustomer = 'الكل';
    _tempSelectedTaxFilter = 'الكل';
    _tempSelectedDate = date;
    _tempSelectedMonth = null;
    _tempSelectedYear = null;
    _tempDateFilterType = 'day';

    resetForNewSearch();
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void setTaxFilter(String? value) {
    _selectedTaxFilter = value ?? 'الكل';
    _tempSelectedTaxFilter = _selectedTaxFilter;
    resetForNewSearch(); // ✅ إعادة تعيين للبحث الجديد
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void setDateFilterType(String type) {
    _dateFilterType = type;
    _tempDateFilterType = type;
    resetForNewSearch(); // ✅ إعادة تعيين للبحث الجديد
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void setMonthFilter(int month) {
    _selectedMonth = month;
    _tempSelectedMonth = month;
    _dateFilterType = 'month';
    _tempDateFilterType = 'month';
    resetForNewSearch(); // ✅ إعادة تعيين للبحث الجديد
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void applyMonthFilter({required int month, required int year}) {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';
    _selectedDate = null;
    _selectedMonth = month;
    _selectedYear = year;
    _dateFilterType = 'month';

    _tempSelectedPaymentType = 'الكل';
    _tempSelectedCustomer = 'الكل';
    _tempSelectedTaxFilter = 'الكل';
    _tempSelectedDate = null;
    _tempSelectedMonth = month;
    _tempSelectedYear = year;
    _tempDateFilterType = 'month';

    resetForNewSearch();
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void setYearFilter(int year) {
    _selectedYear = year;
    _tempSelectedYear = year;
    _dateFilterType = 'year';
    _tempDateFilterType = 'year';

    appLog('🎯 تطبيق فلتر السنة: $year', name: 'SalesProvider');
    clearSalesData(); // ✅ مسح البيانات القديمة أولاً
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void applyYearFilter(int year) {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';
    _selectedDate = null;
    _selectedMonth = null;
    _selectedYear = year;
    _dateFilterType = 'year';

    _tempSelectedPaymentType = 'الكل';
    _tempSelectedCustomer = 'الكل';
    _tempSelectedTaxFilter = 'الكل';
    _tempSelectedDate = null;
    _tempSelectedMonth = null;
    _tempSelectedYear = year;
    _tempDateFilterType = 'year';

    resetForNewSearch();
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void clearDateFilter() {
    _selectedDate = null;
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';

    _tempSelectedDate = null;
    _tempSelectedMonth = null;
    _tempSelectedYear = null;
    _tempDateFilterType = 'day';

    _resetAndFetch(forceRefresh: true);
  }

  void clearFilters() {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';

    _tempSelectedPaymentType = 'الكل';
    _tempSelectedCustomer = 'الكل';
    _tempSelectedTaxFilter = 'الكل';

    // ✅ استخدام resetForNewSearch بدلاً من مجرد تعيين _displayedSales
    resetForNewSearch();
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void clearAllFilters() {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';
    _selectedDate = null;
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';

    _tempSelectedPaymentType = 'الكل';
    _tempSelectedCustomer = 'الكل';
    _tempSelectedTaxFilter = 'الكل';
    _tempSelectedDate = null;
    _tempDateFilterType = 'day';
    _tempSelectedMonth = null;
    _tempSelectedYear = null;

    // ✅ استخدام resetForNewSearch
    resetForNewSearch();
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void reset() {
    _allSales.clear();
    _displayedSales.clear();
    _isLoading = false;
    _hasMore = true;
    _page = 0;

    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedDate = null;
    _selectedTaxFilter = 'الكل';
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';

    _tempSelectedPaymentType = 'الكل';
    _tempSelectedCustomer = 'الكل';
    _tempSelectedTaxFilter = 'الكل';
    _tempSelectedDate = null;
    _tempDateFilterType = 'day';
    _tempSelectedMonth = null;
    _tempSelectedYear = null;

    _currentCacheKey = null;
    notifyListeners();
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ نظام الـ Cache ███████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  String _generateCacheKey() {
    final keyParts = [
      'payment=$_selectedPaymentType',
      'customer=$_selectedCustomer',
      'tax=$_selectedTaxFilter',
      'dateType=$_dateFilterType',
      'month=$_selectedMonth',
      'year=$_selectedYear',
      if (_selectedDate != null)
        'date=${_selectedDate!.toIso8601String().substring(0, 10)}',
    ];
    return keyParts.join('|');
  }

  void _updateCache() {
    if (_currentCacheKey != null && _allSales.isNotEmpty) {
      _salesCache[_currentCacheKey!] = List.from(_allSales);
    }
  }

  void _cleanupOldCache({int keepLast = 10}) {
    if (_salesCache.length > keepLast) {
      final keys = _salesCache.keys.toList();
      for (int i = 0; i < keys.length - keepLast; i++) {
        _salesCache.remove(keys[i]);
      }
    }
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ بناء استعلام التاريخ ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  String _buildDateWhereClause(List<dynamic> args) {
    switch (_dateFilterType) {
      case 'day':
        if (_selectedDate != null) {
          final dateStr = _selectedDate!.toIso8601String().split('T')[0];
          args.add('$dateStr%');
          return "s.date LIKE ?";
        }
        break;
      case 'month':
        if (_selectedMonth != null && _selectedYear != null) {
          final monthStr = _selectedMonth!.toString().padLeft(2, '0');
          args.add('$_selectedYear-$monthStr-%');
          return "s.date LIKE ?";
        }
        break;
      case 'year':
        if (_selectedYear != null) {
          args.add('$_selectedYear-%');
          return "s.date LIKE ?";
        }
        break;
    }
    return '1=1';
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ التحميل والتصفية ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  void _resetAndFetch({bool forceRefresh = false}) {
    resetForNewSearch(); // ✅ استخدام الدالة الجديدة
    Future.microtask(() => _fetchSalesWithFilters(forceRefresh: forceRefresh));
  }

  Future<void> _fetchSalesWithFilters({
    bool loadMore = false,
    bool forceRefresh = false,
  }) async {
    appLog(
      '🚀 بدء التحميل: loadMore=$loadMore, page=$_page, hasMore=$_hasMore',
      name: 'SalesProvider',
    );
    final int requestId = loadMore ? _requestSerial : ++_requestSerial;

    if (_isLoading) {
      appLog('❌ التحميل جاري، تم إيقاف الطلب', name: 'SalesProvider');
      return;
    }

    if (loadMore && !_hasMore) {
      appLog('❌ لا يوجد المزيد، تم إيقاف الطلب', name: 'SalesProvider');
      return;
    }

    final cacheKey = _generateCacheKey();
    _currentCacheKey = cacheKey;

    // ✅ استخدم الكاش فقط إذا ما كان loadMore
    if (!forceRefresh && !loadMore && _salesCache.containsKey(cacheKey)) {
      appLog('✅ استخدام الكاش للبيانات', name: 'SalesProvider');
      _allSales = _salesCache[cacheKey]!;
      _displayedSales = _allSales;
      // ✅ احسب hasMore من الكاش مقارنةً بالعدد الكلي
      _hasMore = false; // بنخليها false هون وبنتحقق من DB لو احتجنا
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final db = await _dbHelper.db;

    try {
      final String table =
          isArchiveMode
              ? '''(
              SELECT id, date, total_amount, total_profit, customer_id, payment_type,
                     paid_amount, remaining_amount, show_for_tax, user_id
              FROM sales
              UNION ALL
              SELECT id, date, total_amount, total_profit, customer_id, payment_type,
                     paid_amount, remaining_amount, show_for_tax, user_id
              FROM sales_archive
            ) s'''
              : 'sales s';
      int totalCount = 0;

      List<dynamic> args = [];
      String dateCondition = _buildDateWhereClause(args);

      final List<String> conditions = [dateCondition];
      if (_taxUserMode) {
        conditions.add("s.show_for_tax = 1");
      }
      if (_selectedPaymentType != 'الكل') {
        final paymentValue = _selectedPaymentType.toLowerCase();

        if (paymentValue == 'debt') {
          conditions.add("s.payment_type = 'credit'");
          conditions.add('COALESCE(s.remaining_amount, s.total_amount) > 0');
        } else if (paymentValue == 'settled') {
          conditions.add("s.payment_type = 'credit'");
          conditions.add('COALESCE(s.remaining_amount, 0) <= 0');
        } else {
          conditions.add("s.payment_type = ?");
          args.add(paymentValue);
        }
      }

      if (_selectedCustomer != 'الكل') {
        if (_selectedCustomer == 'بدون عميل') {
          conditions.add("s.customer_id IS NULL");
        } else {
          conditions.add("TRIM(c.name) = TRIM(?)");
          args.add(_selectedCustomer.trim());
        }
      }

      if (_selectedTaxFilter != 'الكل') {
        final taxValue = _selectedTaxFilter == 'مضمنه بالضرائب' ? 1 : 0;
        conditions.add("s.show_for_tax = ?");
        args.add(taxValue);
      }

      String whereClause = conditions.join(' AND ');

      appLog('🔍 الاستعلام: WHERE $whereClause', name: 'SalesProvider');
      appLog('🔍 الـ Args: $args', name: 'SalesProvider');

      // ✅ جلب العدد الكلي للنتائج الحالية لتحديد hasMore بدقة
      final countResult = await db.rawQuery('''
        SELECT COUNT(*) as total
        FROM $table
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE $whereClause
      ''', args);

      totalCount = countResult.first['total'] as int? ?? 0;

      // ✅ إذا loadMore، زيادة الصفحة قبل حساب offset
      if (loadMore) {
        _page = _page + 1; // زيادة الصفحة أولاً
      }

      // ✅ جلب البيانات مع حدود الصفحة
      final offset = _page * _limit;
      appLog(
        '🔢 Pagination: loadMore=$loadMore, _page=$_page, offset=$offset, limit=$_limit',
        name: 'SalesProvider',
      );
      final result = await db.rawQuery('''
      SELECT s.*, c.name as customer_name
      FROM $table
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE $whereClause
      ORDER BY s.date DESC
      LIMIT $_limit OFFSET $offset
      ''', args);

      if (requestId != _requestSerial) {
        appLog('⚠️ تم تجاهل نتيجة قديمة لطلب سابق', name: 'SalesProvider');
        return;
      }

      if (result.isNotEmpty) {
        final sales = result.map((row) => Sale.fromMap(row)).toList();

        // 🔍 تتبع البيانات المحملة من قاعدة البيانات
        log('📥 Loaded ${sales.length} sales from DB');
        for (int i = 0; i < (sales.length > 3 ? 3 : sales.length); i++) {
          final sale = sales[i];
          log(
            '  Sale[$i]: id=${sale.id}, showForTax=${sale.showForTax}, amount=${sale.totalAmount}',
          );
        }

        if (loadMore) {
          _allSales.addAll(sales);
          // ✅ لا نزيد _page هنا لأننا زيدناها قبل الاستعلام
        } else {
          _allSales = sales;
          // ✅ أول استعلام بـ _page = 0
        }
        // ✅ عرض كل ما تم تحميله بدل حساب displayCount
        _displayedSales = _allSales;
        // ✅ تحديد hasMore هل في المزيد في الـ database
        _hasMore = _allSales.length < totalCount;
        appLog(
          '📊 بعد الاستعلام: _page=$_page, _allSales.length=${_allSales.length}, totalCount=$totalCount, _hasMore=$_hasMore',
          name: 'SalesProvider',
        );
      } else {
        if (!loadMore) {
          _allSales = [];
          _displayedSales = [];
        }
        _hasMore = false;
      }

      // ✅ تحديث الكاش
      _updateCache();
    } catch (e) {
      log('❌ خطأ أثناء جلب البيانات: $e');
    } finally {
      if (requestId == _requestSerial) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clearSalesData() {
    _page = 0;
    _allSales.clear();
    _displayedSales.clear();
    _hasMore = true;
    appLog('🧹 تم مسح بيانات الفواتير السابقة', name: 'SalesProvider');
    notifyListeners();
  }

  Future<void> fetchSales({
    bool loadMore = false,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) {
      appLog(
        '⏳ تم تجاهل fetchSales لأن التحميل ما زال جاريًا',
        name: 'SalesProvider',
      );
      return;
    }

    final shouldClearBeforeFetch = !loadMore && !hasLoadedSales;
    if (shouldClearBeforeFetch) {
      resetForNewSearch();
    }
    await _fetchSalesWithFilters(
      loadMore: loadMore,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> loadMoreSales() async {
    appLog('🔄 زر عرض المزيد - بدء', name: 'SalesProvider');
    appLog('   - hasMore: $_hasMore', name: 'SalesProvider');
    appLog('   - isLoading: $_isLoading', name: 'SalesProvider');
    appLog('   - الصفحة الحالية: $_page', name: 'SalesProvider');
    appLog('   - الفواتير الحالية: ${_allSales.length}', name: 'SalesProvider');

    if (!_hasMore || _isLoading) return;

    appLog('✅ بدء تحميل المزيد من الفواتير', name: 'SalesProvider');
    // ✅ forceRefresh: true عشان يتجاوز الكاش
    await _fetchSalesWithFilters(loadMore: true, forceRefresh: true);
    appLog(
      '✅ تم تحميل المزيد. الفواتير الآن: ${_allSales.length}',
      name: 'SalesProvider',
    );
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال التحديث ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  Future<void> updatePaymentType(
    int saleId,
    String paymentType, {
    int? customerId,
  }) async {
    final db = await _dbHelper.db;

    if (paymentType != 'cash' && paymentType != 'credit') {
      throw Exception('نوع الدفع غير صالح. يجب أن يكون "cash" أو "credit".');
    }

    int? resolvedCustomerId;

    await db.transaction((txn) async {
      final saleResult = await txn.query(
        'sales',
        columns: [
          'id',
          'total_amount',
          'payment_type',
          'customer_id',
          'paid_amount',
          'remaining_amount',
        ],
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );

      if (saleResult.isEmpty) {
        throw Exception(
          'فشل التعديل: لم يتم العثور على الفاتورة بالرقم المحدد.',
        );
      }

      final saleData = saleResult.first;
      final oldPaymentType = saleData['payment_type'] as String;
      final oldCustomerId = saleData['customer_id'] as int?;
      final totalAmount = (saleData['total_amount'] as num).toDouble();
      final oldPaidAmount =
          (saleData['paid_amount'] as num?)?.toDouble() ??
          (oldPaymentType == 'cash' ? totalAmount : 0.0);
      final oldRemainingAmount =
          (saleData['remaining_amount'] as num?)?.toDouble() ??
          (oldPaymentType == 'credit' ? totalAmount : 0.0);

      resolvedCustomerId =
          paymentType == 'credit' ? (customerId ?? oldCustomerId) : null;

      if (paymentType == 'credit' && resolvedCustomerId == null) {
        throw Exception('يجب اختيار عميل قبل تحويل الفاتورة إلى آجل.');
      }

      final newPaidAmount =
          paymentType == 'cash'
              ? totalAmount
              : oldPaymentType == 'credit'
              ? oldPaidAmount
              : 0.0;
      final newRemainingAmount =
          paymentType == 'credit'
              ? oldPaymentType == 'credit'
                  ? oldRemainingAmount
                  : totalAmount
              : 0.0;

      final updateData = <String, dynamic>{
        'payment_type': paymentType,
        'customer_id': resolvedCustomerId,
        'paid_amount': newPaidAmount,
        'remaining_amount': newRemainingAmount,
      };

      final count = await txn.update(
        'sales',
        updateData,
        where: 'id = ?',
        whereArgs: [saleId],
      );

      if (count == 0) {
        throw Exception(
          'فشل التعديل: لم يتم العثور على الفاتورة بالرقم المحدد.',
        );
      }

      if (oldPaymentType == 'credit' &&
          oldCustomerId != null &&
          oldRemainingAmount > 0) {
        await _applyCustomerBalanceDelta(
          txn: txn,
          customerId: oldCustomerId,
          delta: -oldRemainingAmount,
        );
      }

      if (paymentType == 'credit' &&
          resolvedCustomerId != null &&
          newRemainingAmount > 0) {
        await _applyCustomerBalanceDelta(
          txn: txn,
          customerId: resolvedCustomerId!,
          delta: newRemainingAmount,
        );
      }
    });

    final index = _allSales.indexWhere((sale) => sale.id == saleId);
    if (index != -1) {
      final oldSale = _allSales[index];
      final updatedSale = Sale(
        id: oldSale.id,
        date: oldSale.date,
        totalAmount: oldSale.totalAmount,
        totalProfit: oldSale.totalProfit,
        customerId: resolvedCustomerId,
        customerName: oldSale.customerName,
        paymentType: paymentType,
        paidAmount:
            paymentType == 'cash' ? oldSale.totalAmount : oldSale.paidAmount,
        remainingAmount:
            paymentType == 'credit'
                ? oldSale.paymentType == 'credit'
                    ? oldSale.remainingAmount
                    : oldSale.totalAmount
                : 0.0,
        showForTax: oldSale.showForTax,
      );
      _allSales[index] = updatedSale;
      _updateCache();
    }

    notifyListeners();
  }

  Future<void> updateShowForTax(int saleId, bool showForTax) async {
    final db = await _dbHelper.db;

    Map<String, dynamic> updateData = {'show_for_tax': showForTax ? 1 : 0};

    int count = await db.update(
      'sales',
      updateData,
      where: 'id = ?',
      whereArgs: [saleId],
    );

    if (count == 0) {
      throw Exception('فشل التعديل: لم يتم العثور على الفاتورة بالرقم المحدد.');
    }

    final index = _allSales.indexWhere((sale) => sale.id == saleId);
    if (index != -1) {
      final oldSale = _allSales[index];
      final updatedSale = Sale(
        id: oldSale.id,
        date: oldSale.date,
        totalAmount: oldSale.totalAmount,
        totalProfit: oldSale.totalProfit,
        customerId: oldSale.customerId,
        customerName: oldSale.customerName,
        paymentType: oldSale.paymentType,
        paidAmount: oldSale.paidAmount,
        remainingAmount: oldSale.remainingAmount,
        showForTax: showForTax,
      );
      _allSales[index] = updatedSale;
      _updateCache();
    }

    notifyListeners();
  }

  Future<void> deleteSale(int saleId) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      // 1️⃣ جلب الفاتورة
      final sale = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );

      if (sale.isEmpty) {
        throw Exception('الفاتورة غير موجودة');
      }

      final saleData = sale.first;
      final double totalAmount = (saleData['total_amount'] as num).toDouble();
      final double remainingAmount =
          (saleData['remaining_amount'] as num?)?.toDouble() ??
          ((saleData['payment_type'] == 'credit') ? totalAmount : 0.0);
      final String paymentType = saleData['payment_type'] as String;
      final int? customerId = saleData['customer_id'] as int?;

      // 2️⃣ جلب تفاصيل خصم الدفعات من سجل الدفعات أو من sale_items
      List<Map<String, dynamic>> batchReturns = [];

      try {
        // جلب من sale_batch_log إذا موجود
        final batchLog = await txn.query(
          'sale_batch_log',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );

        if (batchLog.isNotEmpty) {
          for (var log in batchLog) {
            batchReturns.add({
              'batchId': log['batch_id'] as int,
              'quantity': log['deducted_quantity'] as double,
              'costPrice': log['cost_price'] as double,
              'productId': log['product_id'] as int,
              'expiryDate': log['expiry_date'] as String?,
            });
          }
        } else {
          // جلب من sale_items إذا لم يكن هناك سجل
          final items = await txn.query(
            'sale_items',
            where: 'sale_id = ? AND product_id IS NOT NULL',
            whereArgs: [saleId],
          );

          for (var item in items) {
            if (item['batch_details'] != null) {
              final details = jsonDecode(item['batch_details'] as String);
              final List<Map<String, dynamic>> itemDeductions =
                  List<Map<String, dynamic>>.from(details);

              for (var deduction in itemDeductions) {
                batchReturns.add({
                  ...deduction,
                  'productId': item['product_id'] as int,
                });
              }
            }
          }
        }
      } catch (e) {
        log('⚠️ لم يتم العثور على سجل الدفعات: $e');
      }

      // 3️⃣ إرجاع الكميات للدفعات
      for (var returnItem in batchReturns) {
        final batchId = returnItem['batchId'] as int;
        final double quantity = (returnItem['quantity'] as num).toDouble();
        final int productId = returnItem['productId'] as int;

        // التحقق من وجود الدفعة
        final batch = await txn.query(
          'product_batches',
          where: 'id = ?',
          whereArgs: [batchId],
        );

        if (batch.isNotEmpty) {
          // الدفعة موجودة - إضافة الكمية
          final double currentQty =
              (batch.first['remaining_quantity'] as num).toDouble();
          await txn.update(
            'product_batches',
            {
              'remaining_quantity': currentQty + quantity,
              'active': 1, // إعادة تفعيل
            },
            where: 'id = ?',
            whereArgs: [batchId],
          );

          log(
            '✅ إرجاع $quantity للدفعة $batchId (أصبحت: ${currentQty + quantity})',
          );
        } else {
          // الدفعة محذوفة - إنشاء دفعة جديدة
          await txn.insert('product_batches', {
            'product_id': productId,
            'quantity': quantity,
            'remaining_quantity': quantity,
            'cost_price': returnItem['costPrice'] ?? 0,
            'expiry_date':
                returnItem['expiryDate'] ??
                DateTime.now().add(Duration(days: 365)).toIso8601String(),
            'production_date': DateTime.now().toIso8601String(),
            'active': 1,
            'created_at': DateTime.now().toIso8601String(),
          });

          log('✅ إنشاء دفعة جديدة للمنتج $productId بكمية $quantity');
        }

        // Restore the aggregate product stock for each returned batch.
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [quantity, productId],
        );
      }

      if (batchReturns.isEmpty) {
        final saleItems = await txn.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );

        for (var item in saleItems) {
          final int? productId = item['product_id'] as int?;
          if (productId == null) continue;

          final double quantity = (item['quantity'] as num).toDouble();
          final int? unitId = item['unit_id'] as int?;

          double qtyToReturn = quantity;

          if (unitId != null) {
            final unit = await txn.query(
              'product_units',
              where: 'id = ?',
              whereArgs: [unitId],
            );

            if (unit.isNotEmpty) {
              final double containQty =
                  (unit.first['contain_qty'] as num).toDouble();
              qtyToReturn = quantity * containQty;
            }
          }

          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity + ? WHERE id = ?',
            [qtyToReturn, productId],
          );
        }
      }

      if (paymentType == 'credit' &&
          customerId != null &&
          remainingAmount > 0) {
        await _applyCustomerBalanceDelta(
          txn: txn,
          customerId: customerId,
          delta: -remainingAmount,
        );

        log(
          'Adjusted customer balance for deleted sale $saleId by -$remainingAmount',
        );
      }
      // 7️⃣ حذف السجلات
      await txn.delete(
        'sale_batch_log',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);

      log('🗑️ تم حذف الفاتورة $saleId بنجاح');
    });

    // تحديث الواجهة
    _allSales.removeWhere((sale) => sale.id == saleId);
    _displayedSales.removeWhere((sale) => sale.id == saleId);
    notifyListeners();
  }

  Future<Map<String, dynamic>> getSaleDetails(int saleId) async {
    final db = await _dbHelper.db;

    bool useArchive = false;

    var saleResult = await db.rawQuery(
      '''
    SELECT s.*, c.name as customer_name, c.phone as customer_phone
    FROM sales s 
    LEFT JOIN customers c ON s.customer_id = c.id 
    WHERE s.id = ?
    ''',
      [saleId],
    );

    if (saleResult.isEmpty) {
      saleResult = await db.rawQuery(
        '''
      SELECT s.*, c.name as customer_name, c.phone as customer_phone
      FROM sales_archive s 
      LEFT JOIN customers c ON s.customer_id = c.id 
      WHERE s.id = ?
      ''',
        [saleId],
      );
      useArchive = true;
    }

    if (saleResult.isEmpty) {
      throw Exception('الفاتورة غير موجودة');
    }

    String itemsTable = useArchive ? 'sale_items_archive' : 'sale_items';

    // استعلام محسن لدعم الخدمات والمنتجات
    final itemsResult = await db.rawQuery(
      '''
    SELECT 
      si.*, 
      -- اسم المنتج (للمنتجات فقط) أو اسم الخدمة
      COALESCE(
        p.name, 
        si.custom_unit_name, 
        'غير معروف'
      ) as item_name,
      -- نوع المنتج: product أو service
      CASE 
        WHEN si.unit_type = 'service' THEN 'service'
        ELSE 'product'
      END as item_type,
      -- الوحدة الأساسية للمنتج (للمنتجات فقط)
      p.base_unit as product_base_unit,
      -- اسم الوحدة المخصصة (إذا كانت موجودة)
      pu.unit_name as custom_unit_name,
      pu.contain_qty as unit_contain_qty,
      -- سعر التكلفة
      CASE 
        WHEN si.unit_type = 'service' THEN 0.0
        ELSE p.cost_price 
      END as product_cost_price,
      -- معلومات إضافية للخدمات
      CASE 
        WHEN si.unit_type = 'service' THEN 1
        ELSE 0
      END as is_service
    FROM $itemsTable si 
    LEFT JOIN products p ON si.product_id = p.id 
    LEFT JOIN product_units pu ON si.unit_id = pu.id
    WHERE si.sale_id = ?
    ORDER BY 
      CASE 
        WHEN si.unit_type = 'service' THEN 1
        ELSE 0
      END,
      si.id
    ''',
      [saleId],
    );

    return {
      'sale': Sale.fromMap(saleResult.first),
      'items': itemsResult,
      'isFromArchive': useArchive,
    };
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال مساعدة أخرى ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  void toggleSaleSelection(int saleId) {
    if (selectedSaleIds.contains(saleId)) {
      selectedSaleIds.remove(saleId);
    } else {
      selectedSaleIds.add(saleId);
    }
    notifyListeners();
  }

  void selectAllShownSales(List<Sale> shownSales) {
    selectedSaleIds = shownSales.map((sale) => sale.id).toList();
    notifyListeners();
  }

  void clearSelection() {
    selectedSaleIds.clear();
    notifyListeners();
  }

  Future<void> updateMultiplePaymentTypes(String paymentType) async {
    if (selectedSaleIds.isEmpty) return;

    for (int saleId in selectedSaleIds) {
      await updatePaymentType(saleId, paymentType);
    }

    selectedSaleIds.clear();
    notifyListeners();
  }

  Future<double> settleSelectedSales({
    String? note,
    required DebtProvider debtProvider, // ✅ أضف هاد
  }) async {
    if (selectedSaleIds.isEmpty) {
      throw Exception('لم يتم تحديد أي فواتير للتسديد.');
    }

    final uniqueIds = selectedSaleIds.toSet().toList();
    final db = await _dbHelper.db;
    final placeholders = List.filled(uniqueIds.length, '?').join(',');
    final selectedSales = await db.rawQuery('''
      SELECT id, customer_id, payment_type, total_amount, remaining_amount
      FROM sales
      WHERE id IN ($placeholders)
      ORDER BY date ASC, id ASC
      ''', uniqueIds);

    if (selectedSales.isEmpty) {
      throw Exception('الفواتير المحددة غير موجودة.');
    }

    if (selectedSales.any((sale) => sale['payment_type'] != 'credit')) {
      throw Exception('يمكن تسديد الفواتير الآجلة فقط.');
    }

    final customerIds =
        selectedSales
            .map((sale) => sale['customer_id'] as int?)
            .whereType<int>()
            .toSet();

    if (customerIds.length != 1 ||
        selectedSales.any((sale) => sale['customer_id'] == null)) {
      throw Exception('يجب أن تكون كل الفواتير المحددة لنفس العميل.');
    }

    final totalSettled = selectedSales.fold<double>(
      0.0,
      (sum, sale) =>
          sum + ((sale['remaining_amount'] as num?)?.toDouble() ?? 0.0),
    );

    if (totalSettled <= 0.0001) {
      throw Exception('كل الفواتير المحددة مسددة مسبقاً.');
    }

    await debtProvider.recordCustomerPayment(
      customerId: customerIds.first,
      amount: totalSettled,
      note: note ?? 'تسديد ${selectedSales.length} فاتورة محددة',
      saleIds: uniqueIds,
    );

    for (final saleId in uniqueIds) {
      final index = _allSales.indexWhere((sale) => sale.id == saleId);
      if (index == -1) continue;

      final oldSale = _allSales[index];
      _allSales[index] = Sale(
        id: oldSale.id,
        date: oldSale.date,
        totalAmount: oldSale.totalAmount,
        totalProfit: oldSale.totalProfit,
        customerId: oldSale.customerId,
        customerName: oldSale.customerName,
        paymentType: oldSale.paymentType,
        paidAmount: oldSale.totalAmount,
        remainingAmount: 0.0,
        showForTax: oldSale.showForTax,
      );
    }

    for (int i = 0; i < _displayedSales.length; i++) {
      if (!uniqueIds.contains(_displayedSales[i].id)) continue;

      final oldSale = _displayedSales[i];
      _displayedSales[i] = Sale(
        id: oldSale.id,
        date: oldSale.date,
        totalAmount: oldSale.totalAmount,
        totalProfit: oldSale.totalProfit,
        customerId: oldSale.customerId,
        customerName: oldSale.customerName,
        paymentType: oldSale.paymentType,
        paidAmount: oldSale.totalAmount,
        remainingAmount: 0.0,
        showForTax: oldSale.showForTax,
      );
    }

    selectedSaleIds.clear();
    _updateCache();
    notifyListeners();
    return totalSettled;
  }

  Future<void> addNewSaleDirectly(Sale newSale) async {
    try {
      _allSales.insert(0, newSale);
      _displayedSales.insert(0, newSale);
      _updateCache();
      notifyListeners();
    } catch (e) {
      log('❌ خطأ في إضافة الفاتورة مباشرة: $e');
    }
  }

  Future<void> updateSaleDirectly(Sale updatedSale) async {
    try {
      final index = _allSales.indexWhere((sale) => sale.id == updatedSale.id);
      if (index != -1) {
        _allSales[index] = updatedSale;
        _displayedSales[index] = updatedSale;
        _updateCache();
        notifyListeners();
      }
    } catch (e) {
      log('❌ خطأ في تحديث الفاتورة مباشرة: $e');
    }
  }

  Future<void> loadTodaySalesCount() async {
    final db = await _dbHelper.db;
    final result = await db.rawQuery("""
      SELECT COUNT(*) as count 
      FROM sales
      WHERE SUBSTR(date, 1, 10) = DATE('now')
    """);
    todaySalesCount = result.first['count'] as int;
    notifyListeners();
  }

  Future<void> prefetchCurrentYear() async {
    final currentYear = DateTime.now().year;
    final cacheKey =
        'payment=الكل|customer=الكل|tax=الكل|dateType=year|month=null|year=$currentYear|date=null';

    if (_salesCache.containsKey(cacheKey)) {
      return;
    }

    try {
      final db = await _dbHelper.db;
      final result = await db.rawQuery('''
        SELECT 
          s.id,
          s.date,
          s.total_amount,
          s.total_profit,
          s.customer_id,
          c.name AS customer_name,
          s.payment_type,
          s.show_for_tax
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE s.date LIKE '$currentYear-%'
        ORDER BY s.date DESC
        LIMIT 100
      ''');

      final sales = result.map((e) => Sale.fromMap(e)).toList();
      _salesCache[cacheKey] = sales;
    } catch (e) {
      log('❌ خطأ في تحميل البيانات المسبق: $e');
    }
  }

  Future<void> _applyCustomerBalanceDelta({
    required DatabaseExecutor txn,
    required int customerId,
    required double delta,
  }) async {
    await txn.rawInsert(
      '''
      INSERT INTO customer_balance (customer_id, balance, last_updated)
      VALUES (?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(customer_id)
      DO UPDATE SET
        balance = balance + excluded.balance,
        last_updated = CURRENT_TIMESTAMP
      ''',
      [customerId, delta],
    );
  }

  void invalidateAndRefresh() {
    _salesCache.clear();
    _currentCacheKey = null;
    _page = 0;
    _allSales.clear();
    _displayedSales.clear();
    _hasMore = true;
    _selectedTaxFilter = 'الكل';
    _tempSelectedTaxFilter = 'الكل';
    _fetchSalesWithFilters(forceRefresh: true);
  }

  void enableTaxMode() {
    _taxUserMode = true;
  }

  void disableTaxMode() {
    _taxUserMode = false;
  }
}
