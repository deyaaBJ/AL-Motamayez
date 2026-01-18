// providers/sales_provider.dart
import 'dart:async';
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
    Set<String> names = {'الكل'};
    for (var sale in _allSales) {
      if (sale.customerName != null && sale.customerName!.isNotEmpty) {
        names.add(sale.customerName!);
      } else {
        names.add('بدون عميل');
      }
    }
    return names.toList();
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

    _isLoading = true;
    notifyListeners();

    final db = await _dbHelper.db;

    try {
      String table = "sales s";

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
          conditions.add("c.name = ?");
          args.add(_selectedCustomer);
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

      // ✅ جلب العدد الكلي مرة واحدة فقط
      if (!loadMore) {
        final countResult = await db.rawQuery('''
        SELECT COUNT(*) as total
        FROM $table
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE $whereClause
      ''', args);

        final totalCount = (countResult.first['total'] as int?) ?? 0;
        print('📊 العدد الكلي: $totalCount فاتورة');

        // ✅ إذا كان العدد الكلي أقل من أو يساوي الـ limit، ما نحتاج pagination
        if (totalCount <= _limit) {
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
          FROM $table
          LEFT JOIN customers c ON s.customer_id = c.id
          WHERE $whereClause
          ORDER BY s.date DESC, s.id DESC
        ''', args);

          _allSales = result.map((e) => Sale.fromMap(e)).toList();
          _displayedSales = List.from(_allSales);
          _hasMore = false;

          print(
            '✅ تم تحميل ${_allSales.length} فاتورة مباشرة (بدون pagination)',
          );
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // ✅ حساب OFFSET صحيح بناءً على عدد الفواتير الحالية
      int currentOffset = loadMore ? _allSales.length : 0;

      print('🔢 حساب الـ OFFSET:');
      print('   - loadMore: $loadMore');
      print('   - الفواتير الحالية: ${_allSales.length}');
      print('   - OFFSET: $currentOffset');

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
      FROM $table
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE $whereClause
      ORDER BY s.date DESC, s.id DESC
      LIMIT $_limit OFFSET $currentOffset
    ''', args);

      final newSales = result.map((e) => Sale.fromMap(e)).toList();

      print('📥 الفواتير الجديدة: ${newSales.length}');

      if (newSales.isNotEmpty) {
        if (loadMore) {
          _allSales.addAll(newSales);
        } else {
          _allSales = newSales;
        }

        // ✅ تحديث الـ hasMore بناءً على إذا كانت الفواتير الجديدة أقل من الـ limit
        _hasMore = newSales.length == _limit;

        // ✅ تحديث الـ displayedSales
        _displayedSales = List.from(_allSales);

        print('✅ الفواتير الكلية: ${_allSales.length}');
      } else {
        _hasMore = false;
        print('❌ لا توجد فواتير جديدة، تم تعيين hasMore=false');
      }
    } catch (e) {
      print('❌ خطأ في جلب الفواتير: $e');
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
      print(
        '🏁 انتهى التحميل. hasMore=$_hasMore, الفواتير=${_allSales.length}',
      );
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
      final saleResult = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );

      if (saleResult.isEmpty) {
        throw Exception('الفاتورة غير موجودة');
      }

      final sale = saleResult.first;
      final double totalAmount =
          (sale['total_amount'] is int)
              ? (sale['total_amount'] as int).toDouble()
              : sale['total_amount'] as double;

      final String paymentType = sale['payment_type'] as String;
      final int? customerId = sale['customer_id'] as int?;

      final saleItems = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      for (var item in saleItems) {
        final int productId = item['product_id'] as int;
        final double quantity =
            (item['quantity'] is int)
                ? (item['quantity'] as int).toDouble()
                : item['quantity'] as double;

        final String unitType = item['unit_type'] as String;
        final int? unitId = item['unit_id'] as int?;

        double quantityToReturn = quantity;

        if (unitType == 'custom' && unitId != null) {
          final unitResult = await txn.query(
            'product_units',
            columns: ['contain_qty'],
            where: 'id = ?',
            whereArgs: [unitId],
          );

          if (unitResult.isNotEmpty) {
            final double containQty =
                (unitResult.first['contain_qty'] is int)
                    ? (unitResult.first['contain_qty'] as int).toDouble()
                    : unitResult.first['contain_qty'] as double;

            quantityToReturn = quantity * containQty;
          }
        }

        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [quantityToReturn, productId],
        );
      }

      if (paymentType == 'credit' && customerId != null) {
        await txn.rawUpdate(
          '''
        UPDATE customer_balance
        SET balance = balance - ?, last_updated = ?
        WHERE customer_id = ?
        ''',
          [totalAmount, DateTime.now().toIso8601String(), customerId],
        );
      }

      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });

    _allSales.removeWhere((sale) => sale.id == saleId);
    _displayedSales.removeWhere((sale) => sale.id == saleId);

    _updateCache();
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

    final itemsResult = await db.rawQuery(
      '''
      SELECT 
        si.*, 
        p.name as product_name,
        p.base_unit as product_base_unit,
        pu.unit_name as custom_unit_name,
        pu.contain_qty as unit_contain_qty
      FROM $itemsTable si 
      JOIN products p ON si.product_id = p.id 
      LEFT JOIN product_units pu ON si.unit_id = pu.id
      WHERE si.sale_id = ?
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
