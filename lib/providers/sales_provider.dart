// providers/sales_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/sale.dart';
import 'dart:developer';

class SalesProvider extends ChangeNotifier {
  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ المتغيرات الأساسية ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  int _page = 0;
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  final DBHelper _dbHelper = DBHelper();

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ نظام الـ Cache ███████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  final Map<String, List<Sale>> _salesCache = {};
  String? _currentCacheKey;
  Timer? _cacheCleanupTimer;
  DateTime? _lastCurrentYearCacheUpdate;

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

  List<String> get paymentTypes => ['الكل', 'cash', 'credit'];

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
    final customerList = names.where((name) => name != 'الكل').toList()
      ..sort();
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
      filters.add('دفع: ${_selectedPaymentType == 'cash' ? 'نقدي' : 'آجل'}');
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
    _isLoading = false;
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

  void setYearFilter(int year) {
    _selectedYear = year;
    _tempSelectedYear = year;
    _dateFilterType = 'year';
    _tempDateFilterType = 'year';

    print('🎯 تطبيق فلتر السنة: $year');
    clearSalesData(); // ✅ مسح البيانات القديمة أولاً
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
    _lastCurrentYearCacheUpdate = null;
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
    print('🚀 بدء التحميل: loadMore=$loadMore, page=$_page, hasMore=$_hasMore');

    if (_isLoading) {
      print('❌ التحميل جاري، تم إيقاف الطلب');
      return;
    }

    if (loadMore && !_hasMore) {
      print('❌ لا يوجد المزيد، تم إيقاف الطلب');
      return;
    }

    // ✅ التحقق من الكاش قبل جلب البيانات
    final cacheKey = _generateCacheKey();
    if (!forceRefresh && _salesCache.containsKey(cacheKey)) {
      print('✅ استخدام الكاش للبيانات');
      _allSales = _salesCache[cacheKey]!;
      final int displayCount = ((_page + 1) * _limit)
          .clamp(0, _allSales.length)
          .toInt();
      _displayedSales = _allSales.sublist(0, displayCount);
      _hasMore = _allSales.length > _displayedSales.length;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final db = await _dbHelper.db;

    try {
      String table = "sales s";
      int totalCount = 0;

      List<dynamic> args = [];
      String dateCondition = _buildDateWhereClause(args);

      final List<String> conditions = [dateCondition];

      if (_selectedPaymentType != 'الكل') {
        final paymentValue = _selectedPaymentType.toLowerCase();
        conditions.add("s.payment_type = ?");
        args.add(paymentValue);
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

      print('🔍 الاستعلام: WHERE $whereClause');
      print('🔍 الـ Args: $args');

      // ✅ جلب العدد الكلي للنتائج الحالية لتحديد hasMore بدقة
      final countResult = await db.rawQuery('''
        SELECT COUNT(*) as total
        FROM $table
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE $whereClause
      ''', args);

      totalCount = countResult.first['total'] as int? ?? 0;

      // ✅ جلب البيانات مع حدود الصفحة
      final offset = _page * _limit;
      final result = await db.rawQuery('''
      SELECT s.*, c.name as customer_name
      FROM $table
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE $whereClause
      ORDER BY s.date DESC
      LIMIT $_limit OFFSET $offset
      ''', args);

      if (result.isNotEmpty) {
        final sales = result.map((row) => Sale.fromMap(row)).toList();
        _allSales.addAll(sales);
        final int displayCount = ((_page + 1) * _limit)
            .clamp(0, _allSales.length)
            .toInt();
        _displayedSales = _allSales.sublist(0, displayCount);
        _page++;
        _hasMore = _allSales.length < totalCount;
      } else {
        _hasMore = false;
      }

      // ✅ تحديث الكاش
      _updateCache();
    } catch (e) {
      log('❌ خطأ أثناء جلب البيانات: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSalesData() {
    _page = 0;
    _allSales.clear();
    _displayedSales.clear();
    _hasMore = true;
    _isLoading = false;
    print('🧹 تم مسح بيانات الفواتير السابقة');
    notifyListeners();
  }

  Future<void> fetchSales({
    bool loadMore = false,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    if (!loadMore) {
      _allSales.clear();
      _hasMore = true;
      notifyListeners();
    }

    final db = await _dbHelper.db;

    try {
      // بناء الاستعلام...
      String whereClause = "1=1"; // قاعدة البداية

      List<dynamic> args = [];

      // إضافة الشروط...

      int offset = loadMore ? _allSales.length : 0;

      final result = await db.rawQuery('''
      SELECT * FROM sales 
      WHERE $whereClause 
      ORDER BY date DESC, id DESC 
      LIMIT $_limit OFFSET $offset
    ''', args);

      final newSales = result.map((e) => Sale.fromMap(e)).toList();

      if (loadMore) {
        _allSales.addAll(newSales);
      } else {
        _allSales = newSales;
      }

      // إذا كانت النتائج أقل من الـ limit، يعني ما فيه زيادة
      _hasMore = newSales.length == _limit;

      _displayedSales = List.from(_allSales);
    } catch (e) {
      print('خطأ: $e');
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSales() async {
    print('🔄 زر عرض المزيد - بدء');
    print('   - hasMore: $_hasMore');
    print('   - isLoading: $_isLoading');
    print('   - الصفحة الحالية: $_page');
    print('   - الفواتير الحالية: ${_allSales.length}');

    if (!_hasMore) {
      print('❌ لا يوجد المزيد، تم إيقاف التحميل');
      return;
    }

    if (_isLoading) {
      print('❌ التحميل جاري، تم إيقاف التحميل');
      return;
    }

    print('✅ بدء تحميل المزيد من الفواتير');
    await _fetchSalesWithFilters(loadMore: true);
    print('✅ تم تحميل المزيد. الفواتير الآن: ${_allSales.length}');
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

    Map<String, dynamic> updateData = {'payment_type': paymentType};

    if (paymentType == 'credit') {
      updateData['customer_id'] = customerId;
    }

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
        customerId: customerId ?? oldSale.customerId,
        customerName: oldSale.customerName,
        paymentType: paymentType,
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

        // 4️⃣ إرجاع الكمية للمنتج الإجمالي
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [quantity, productId],
        );
      }

      // 5️⃣ إذا لم تكن هناك تفاصيل دفعات، نرجع الكميات العادية
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

      // 6️⃣ تعديل رصيد الزبون إذا كانت فاتورة آجلة
      if (paymentType == 'credit' && customerId != null) {
        await txn.rawUpdate(
          '''
        UPDATE customer_balance 
        SET balance = balance - ?, last_updated = ?
        WHERE customer_id = ?
        ''',
          [totalAmount, DateTime.now().toIso8601String(), customerId],
        );

        log('💳 تعديل رصيد الزبون ID: $customerId بمقدار: -$totalAmount');
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
      _lastCurrentYearCacheUpdate = DateTime.now();
    } catch (e) {
      log('❌ خطأ في تحميل البيانات المسبق: $e');
    }
  }
}
