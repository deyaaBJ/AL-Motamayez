// providers/sales_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/sale.dart';

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

  // ✅ Cache للبيانات المحملة مسبقاً
  final Map<String, List<Sale>> _salesCache = {};
  String? _currentCacheKey;
  Timer? _cacheCleanupTimer;

  // ✅ متغير لتتبع آخر تحديث للسنة الحالية
  DateTime? _lastCurrentYearCacheUpdate;

  // ✅ بيانات محملة ومعروضة
  List<Sale> _allSales = [];
  List<Sale> _displayedSales = [];

  List<Sale> get sales => _displayedSales;
  int get loadedSalesCount => _allSales.length;
  bool get hasLoadedSales => _allSales.isNotEmpty;

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الفلاتر ██████████████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  String _selectedPaymentType = 'الكل';
  String _selectedCustomer = 'الكل';
  String _selectedTaxFilter = 'الكل';
  DateTime? _selectedDate;
  String _dateFilterType = 'day';
  int? _selectedMonth;
  int? _selectedYear;

  // Getters
  String get selectedPaymentType => _selectedPaymentType;
  String get selectedCustomer => _selectedCustomer;
  DateTime? get selectedDate => _selectedDate;
  String get selectedTaxFilter => _selectedTaxFilter;
  String get dateFilterType => _dateFilterType;
  int? get selectedMonth => _selectedMonth;
  int? get selectedYear => _selectedYear;

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

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ Getters جديدة ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  // ✅ Getter للحصول على نسبة الفلاتر
  String get filteredPercentage {
    if (_allSales.isEmpty) return "0%";
    final percentage =
        (_displayedSales.length / _allSales.length * 100).toInt();
    return "$percentage%";
  }

  // ✅ Getter لملخص الفلاتر
  Map<String, dynamic> get filterSummary {
    return {
      'totalLoaded': _allSales.length,
      'displayed': _displayedSales.length,
      'filteredOut': _allSales.length - _displayedSales.length,
      'percentage': filteredPercentage,
    };
  }

  // ✅ Getter للتحقق من وجود فلاتر نشطة
  bool get isFilterActive {
    return _selectedPaymentType != 'الكل' ||
        _selectedCustomer != 'الكل' ||
        _selectedTaxFilter != 'الكل' ||
        _selectedDate != null ||
        _selectedMonth != null ||
        _selectedYear != null ||
        _dateFilterType != 'day';
  }

  // ✅ Getter للتحقق من وضع الأرشيف
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

  // ✅ Getter لوصف الفلاتر النشطة
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
  // ████████████████████████████████ نظام الـ Cache ███████████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  SalesProvider() {
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

  // ✅ دالة لإنشاء مفتاح cache
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

  // ✅ دالة لتحديث الـ cache
  void _updateCache() {
    if (_currentCacheKey != null && _allSales.isNotEmpty) {
      _salesCache[_currentCacheKey!] = List.from(_allSales);
      print('✅ تم تحديث الـ cache للمفتاح: $_currentCacheKey');

      // ✅ تحديث وقت آخر تحديث إذا كان للسنة الحالية
      if (_selectedYear == DateTime.now().year) {
        _lastCurrentYearCacheUpdate = DateTime.now();
      }
    }
  }

  // ✅ دالة لتنظيف الـ cache القديم
  void _cleanupOldCache({int keepLast = 10}) {
    if (_salesCache.length > keepLast) {
      final keys = _salesCache.keys.toList();
      // احتفظ بـ keepLast الأحدث
      for (int i = 0; i < keys.length - keepLast; i++) {
        _salesCache.remove(keys[i]);
      }
      print('🧹 تم تنظيف الـ cache، بقي ${_salesCache.length} عنصر');
    }
  }

  // ✅ دالة للتحقق مما إذا كان يمكن التصفية محلياً
  bool _canFilterLocally() {
    // يمكن التصفية محلياً إذا:
    // 1. لدينا بيانات محملة
    // 2. لا نغير فلتر السنة (لأنه قد يحتاج بيانات جديدة)
    // 3. الفلاتر الأخرى يمكن تطبيقها على البيانات الحالية
    return _allSales.isNotEmpty &&
        !(_dateFilterType == 'year' &&
            _selectedYear != null &&
            !_salesCache.containsKey(_generateCacheKey()));
  }

  // ✅ دالة لتطبيق الفلاتر محلياً
  void _applyLocalFilters() {
    List<Sale> filtered = List.from(_allSales);

    // فلترة نوع الدفع
    if (_selectedPaymentType != 'الكل') {
      final paymentValue = _selectedPaymentType.toLowerCase();
      filtered =
          filtered.where((sale) => sale.paymentType == paymentValue).toList();
    }

    // فلترة العميل
    if (_selectedCustomer != 'الكل') {
      if (_selectedCustomer == 'بدون عميل') {
        filtered =
            filtered
                .where(
                  (sale) =>
                      sale.customerName == null || sale.customerName!.isEmpty,
                )
                .toList();
      } else {
        filtered =
            filtered
                .where((sale) => sale.customerName == _selectedCustomer)
                .toList();
      }
    }

    // فلترة الضريبة
    if (_selectedTaxFilter != 'الكل') {
      final taxValue = _selectedTaxFilter == 'مضمنه بالضرائب' ? 1 : 0;
      filtered = filtered.where((sale) => sale.showForTax == taxValue).toList();
    }

    // فلترة التاريخ (إذا كان محلياً)
    if (_dateFilterType == 'day' && _selectedDate != null) {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      filtered =
          filtered.where((sale) => sale.date.startsWith(dateStr)).toList();
    }

    _displayedSales = filtered;
    print(
      '✅ تم التصفية محلياً: ${_displayedSales.length} فاتورة من أصل ${_allSales.length}',
    );
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الفلاتر المتقدمة ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  void setDateFilterType(String type) {
    _dateFilterType = type;
    _resetAndFetch();
    notifyListeners();
  }

  void setMonthFilter(int month) {
    _selectedMonth = month;
    _dateFilterType = 'month';
    _resetAndFetch();
    notifyListeners();
  }

  void setYearFilter(int year) {
    _selectedYear = year;
    _dateFilterType = 'year';

    // ✅ تحقق من الـ cache أولاً
    final cacheKey = _generateCacheKey();

    // ✅ إذا كانت السنة الحالية، استخدم forceRefresh دائمًا
    final bool isCurrentYear = year == DateTime.now().year;

    if (_salesCache.containsKey(cacheKey) && !isCurrentYear) {
      print('✅ استخدام الـ cache الموجود للسنة: $year');
      _allSales = List.from(_salesCache[cacheKey]!);
      _displayedSales = List.from(_allSales);
      _currentCacheKey = cacheKey;
      _hasMore = false;
      notifyListeners();
      return;
    }

    // ✅ للسنة الحالية، استخدم forceRefresh دائمًا
    if (isCurrentYear) {
      print('🔄 السنة الحالية: إجبار إعادة تحميل البيانات');
      _resetAndFetch(forceRefresh: true);
    } else {
      _resetAndFetch();
    }

    notifyListeners();
  }

  // ✅ دالة للتحقق مما إذا كان يجب استخدام cache السنة الحالية
  bool _shouldUseCurrentYearCache() {
    if (_lastCurrentYearCacheUpdate == null) return false;

    final now = DateTime.now();
    final diff = now.difference(_lastCurrentYearCacheUpdate!);

    // ✅ استخدم cache فقط إذا كان التحديث منذ أقل من 2 دقيقة
    return diff.inMinutes < 2;
  }

  void clearDateFilter() {
    _selectedDate = null;
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';
    _resetAndFetch();
    notifyListeners();
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ بناء استعلام التاريخ ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  String _buildDateWhereClause() {
    switch (_dateFilterType) {
      case 'day':
        if (_selectedDate != null) {
          final dateStr = _selectedDate!.toIso8601String().split('T')[0];
          return "s.date LIKE '$dateStr%'";
        }
        break;
      case 'month':
        if (_selectedMonth != null && _selectedYear != null) {
          final monthStr = _selectedMonth!.toString().padLeft(2, '0');
          return "s.date LIKE '$_selectedYear-$monthStr-%'";
        }
        break;
      case 'year':
        if (_selectedYear != null) {
          return "s.date LIKE '$_selectedYear-%'";
        }
        break;
    }
    return '1=1';
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ تحديث الـ Cache للفاتورة الجديدة ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  // ✅ تحديث الـ Cache للفاتورة الجديدة
  Future<void> updateCacheWithNewSale(Sale newSale) async {
    try {
      print('🔄 بدء تحديث الـ cache بفاتورة جديدة #${newSale.id}');

      // 1. تحديث cache للسنة الحالية
      final currentYear = DateTime.now().year;
      final yearCacheKey =
          'payment=الكل|customer=الكل|tax=الكل|dateType=year|month=null|year=$currentYear|date=null';

      if (_salesCache.containsKey(yearCacheKey)) {
        // تحقق أولاً إذا كانت الفاتورة موجودة بالفعل (لتجنب التكرار)
        final existingIndex = _salesCache[yearCacheKey]!.indexWhere(
          (s) => s.id == newSale.id,
        );
        if (existingIndex == -1) {
          // أضف الفاتورة الجديدة إلى بداية الـ Cache
          _salesCache[yearCacheKey]!.insert(0, newSale);
          print(
            '✅ تم تحديث cache السنة $currentYear بفاتورة جديدة #${newSale.id}',
          );

          // تحديث وقت آخر تحديث
          _lastCurrentYearCacheUpdate = DateTime.now();
        } else {
          print(
            'ℹ️ الفاتورة #${newSale.id} موجودة بالفعل في cache السنة $currentYear',
          );
        }
      } else {
        // إذا لم يكن هناك cache للسنة الحالية، قم بإنشائه
        print(
          '⚠️ لا يوجد cache للسنة $currentYear، سيتم إنشاؤه عند التحميل التالي',
        );
      }

      // 2. تحديث cache حسب التاريخ (اليوم)
      try {
        final saleDate = DateTime.parse(newSale.date);
        final dayCacheKey =
            'payment=الكل|customer=الكل|tax=الكل|dateType=day|month=null|year=null|date=${saleDate.toIso8601String().substring(0, 10)}';

        if (_salesCache.containsKey(dayCacheKey)) {
          final existingIndex = _salesCache[dayCacheKey]!.indexWhere(
            (s) => s.id == newSale.id,
          );
          if (existingIndex == -1) {
            _salesCache[dayCacheKey]!.insert(0, newSale);
            print('✅ تم تحديث cache اليوم بفاتورة جديدة #${newSale.id}');
          }
        }
      } catch (e) {
        print('❌ خطأ في معالجة تاريخ الفاتورة: $e');
      }

      // 3. إذا كنا نعرض البيانات الحالية، قم بتحديثها مباشرة
      final currentCacheKey = _currentCacheKey;
      if (currentCacheKey != null &&
          currentCacheKey.contains('dateType=year') &&
          currentCacheKey.contains('year=$currentYear')) {
        // تحقق من عدم وجود الفاتورة بالفعل
        final existingIndex = _allSales.indexWhere((s) => s.id == newSale.id);
        if (existingIndex == -1) {
          _allSales.insert(0, newSale);
          _displayedSales.insert(0, newSale);
          print(
            '✅ تم إضافة الفاتورة الجديدة #${newSale.id} إلى العرض الحالي (السنة الحالية)',
          );
          notifyListeners();
        }
      }

      // 4. إذا كنا نعرض اليوم، قم بتحديث العرض
      if (_dateFilterType == 'day' && _selectedDate != null) {
        try {
          final saleDate = DateTime.parse(newSale.date);
          final selectedDateStr =
              _selectedDate!.toIso8601String().split('T')[0];
          final saleDateStr = saleDate.toIso8601String().split('T')[0];

          if (selectedDateStr == saleDateStr) {
            final existingIndex = _allSales.indexWhere(
              (s) => s.id == newSale.id,
            );
            if (existingIndex == -1) {
              _allSales.insert(0, newSale);
              _displayedSales.insert(0, newSale);
              print('✅ تم إضافة الفاتورة الجديدة #${newSale.id} إلى عرض اليوم');
              notifyListeners();
            }
          }
        } catch (e) {
          print('❌ خطأ في مقارنة التواريخ: $e');
        }
      }

      // 5. تحديث cache للمفتاح الحالي إذا كان موجوداً
      if (_currentCacheKey != null &&
          _salesCache.containsKey(_currentCacheKey)) {
        final existingIndex = _salesCache[_currentCacheKey]!.indexWhere(
          (s) => s.id == newSale.id,
        );
        if (existingIndex == -1) {
          _salesCache[_currentCacheKey]!.insert(0, newSale);
          print('✅ تم تحديث cache المفتاح الحالي بفاتورة جديدة #${newSale.id}');
        }
      }

      print('✅ تم الانتهاء من تحديث الـ cache للفاتورة الجديدة #${newSale.id}');
    } catch (e) {
      print('❌ خطأ في تحديث الـ cache: $e');
      print('❌ تفاصيل الخطأ: ${e.toString()}');
    }
  }

  // ✅ إعادة تحميل الـ Cache للسنة الحالية
  Future<void> reloadCurrentYearCache() async {
    final currentYear = DateTime.now().year;
    final cacheKey =
        'payment=الكل|customer=الكل|tax=الكل|dateType=year|month=null|year=$currentYear|date=null';

    try {
      print('🔄 بدء إعادة تحميل cache السنة $currentYear');

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
      ''');

      final sales = result.map((e) => Sale.fromMap(e)).toList();
      _salesCache[cacheKey] = sales;

      // تحديث وقت آخر تحديث
      _lastCurrentYearCacheUpdate = DateTime.now();

      print(
        '✅ تم إعادة تحميل cache السنة $currentYear بـ ${sales.length} فاتورة',
      );

      // إذا كنا نعرض السنة الحالية، قم بتحديث البيانات مباشرة
      if (_selectedYear == currentYear && _dateFilterType == 'year') {
        _allSales = List.from(sales);
        _displayedSales = List.from(sales);
        print('✅ تم تحديث العرض الحالي بـ ${sales.length} فاتورة');
        notifyListeners();
      }
    } catch (e) {
      print('❌ خطأ في إعادة تحميل cache السنة الحالية: $e');
      print('❌ تفاصيل الخطأ: ${e.toString()}');
    }
  }

  // ✅ إلغاء الـ Cache للسنة الحالية (لإجبار إعادة التحميل)
  void invalidateCurrentYearCache() {
    final currentYear = DateTime.now().year;
    final cacheKey =
        'payment=الكل|customer=الكل|tax=الكل|dateType=year|month=null|year=$currentYear|date=null';

    _salesCache.remove(cacheKey);
    _lastCurrentYearCacheUpdate = null;
    print('🗑️ تم إلغاء cache السنة $currentYear لإجبار إعادة التحميل');
  }

  // ✅ تحديث الـ Cache لجميع المفاتيح المتعلقة بسنة معينة
  void invalidateYearCache(int year) {
    final keysToRemove = <String>[];

    for (final key in _salesCache.keys) {
      if (key.contains('year=$year')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _salesCache.remove(key);
    }

    if (year == DateTime.now().year) {
      _lastCurrentYearCacheUpdate = null;
    }

    print('🗑️ تم إلغاء ${keysToRemove.length} cache لسنة $year');
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ التحميل التدريجي مع الفلاتر ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  int todaySalesCount = 0;

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

  // ✅ دالة لإعادة التعيين والجلب
  // ✅ دالة لإعادة التعيين والجلب
  void _resetAndFetch({bool forceRefresh = false}) {
    _page = 0;
    _allSales.clear();
    _displayedSales.clear();
    _hasMore = true;
    Future.microtask(() => _fetchSalesWithFilters(forceRefresh: forceRefresh));
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ نظام الاستماع للتحديثات ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  // ✅ StreamController لتلقي تحديثات الفواتير الجديدة
  final StreamController<int> _newSaleController =
      StreamController<int>.broadcast();
  Stream<int> get newSaleStream => _newSaleController.stream;

  // ✅ إعلام بإضافة فاتورة جديدة
  void notifyNewSaleAdded(int saleId) {
    print('📢 إشعار بإضافة فاتورة جديدة #$saleId');
    _newSaleController.add(saleId);

    // ✅ تحديث الـ Cache للسنة الحالية مباشرة
    invalidateCurrentYearCache();

    // ✅ إذا كنا نعرض السنة الحالية، قم بإعادة التحميل
    if (_selectedYear == DateTime.now().year && _dateFilterType == 'year') {
      print('🔄 إعادة تحميل عرض السنة الحالية تلقائيًا');
      Future.delayed(const Duration(milliseconds: 500), () {
        fetchSales(forceRefresh: true);
      });
    }
  }

  // ✅ دالة لفحص وجود فاتورة في السنة الحالية
  Future<bool> isSaleInCurrentYear(int saleId) async {
    try {
      final db = await _dbHelper.db;
      final currentYear = DateTime.now().year;

      final result = await db.rawQuery(
        '''
      SELECT COUNT(*) as count 
      FROM sales 
      WHERE id = ? AND date LIKE '$currentYear-%'
      ''',
        [saleId],
      );

      return (result.first['count'] as int) > 0;
    } catch (e) {
      print('❌ خطأ في فحص سنة الفاتورة: $e');
      return false;
    }
  }

  // ✅ التحميل التدريجي للفواتير مع الـ cache
  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ التحميل التدريجي مع الفلاتر ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  Future<void> _fetchSalesWithFilters({
    bool loadMore = false,
    bool forceRefresh = false,
  }) async {
    if (_isLoading || (!_hasMore && loadMore)) return;

    // ✅ تحقق مما إذا كنا في السنة الحالية
    bool isCurrentYear =
        _selectedYear == DateTime.now().year; // تم تغيير final إلى bool عادي

    // ✅ إذا كان forceRefresh، ألغِ cache المفتاح الحالي
    if (forceRefresh) {
      final cacheKey = _generateCacheKey();
      _salesCache.remove(cacheKey);
      print('🔄 forceRefresh: تم إلغاء cache للمفتاح: $cacheKey');

      if (isCurrentYear) {
        _lastCurrentYearCacheUpdate = null;
      }
    }

    // ✅ تحقق من الـ cache أولاً (فقط للتحميل الأولي)
    final cacheKey = _generateCacheKey();

    // ✅ لا تستخدم cache للسنة الحالية إذا مر أكثر من دقيقتين على آخر تحديث
    final bool shouldUseCache =
        _salesCache.containsKey(cacheKey) &&
        (!loadMore) &&
        (!isCurrentYear || _shouldUseCurrentYearCache());

    if (shouldUseCache) {
      print('✅ استخدام الـ cache الموجود للمفتاح: $cacheKey');
      _allSales = List.from(_salesCache[cacheKey]!);
      _displayedSales = List.from(_allSales);
      _currentCacheKey = cacheKey;
      _hasMore = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    if (!loadMore) {
      notifyListeners();
    }

    if (!loadMore) {
      _page = 0;
      _allSales.clear();
      _hasMore = true;
    }

    final db = await _dbHelper.db;

    try {
      // ✅ تحديد الجدول بناءً على الفلتر الزمني
      final bool shouldUseArchive;
      final int? selectedYear = _selectedYear;
      final int currentYear = DateTime.now().year;

      if (_dateFilterType == 'year' && selectedYear != null) {
        shouldUseArchive = selectedYear < currentYear;
      } else if (_dateFilterType == 'month' && selectedYear != null) {
        shouldUseArchive = selectedYear < currentYear;
      } else if (_dateFilterType == 'day' && _selectedDate != null) {
        shouldUseArchive = _selectedDate!.year < currentYear;
      } else {
        // بدون فلتر تاريخ → نعرض السنة الحالية فقط
        shouldUseArchive = false;

        // إذا لم يكن هناك فلتر تاريخ، نضبط فلتر السنة على السنة الحالية تلقائياً
        if (_selectedYear == null && !loadMore) {
          _selectedYear = currentYear;
          _dateFilterType = 'year';
          isCurrentYear = true; // تحديث القيمة هنا
        }
      }

      String table = shouldUseArchive ? "sales_archive s" : "sales s";

      // ✅ بناء استعلام التاريخ
      String dateCondition = _buildDateWhereClause();

      // ✅ بناء جميع شروط الفلتر
      final List<String> conditions = [dateCondition];

      // فلترة نوع الدفع
      if (_selectedPaymentType != 'الكل') {
        final paymentValue = _selectedPaymentType.toLowerCase();
        conditions.add("s.payment_type = '$paymentValue'");
      }

      // فلترة العميل
      if (_selectedCustomer != 'الكل') {
        if (_selectedCustomer == 'بدون عميل') {
          conditions.add("s.customer_id IS NULL");
        } else {
          conditions.add("c.name = '$_selectedCustomer'");
        }
      }

      // فلترة الضريبة
      if (_selectedTaxFilter != 'الكل') {
        final taxValue = _selectedTaxFilter == 'مضمنه بالضرائب' ? 1 : 0;
        conditions.add("s.show_for_tax = $taxValue");
      }

      String whereClause = conditions.join(' AND ');

      // ✅ الاستعلام النهائي
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
      ORDER BY s.date DESC
      LIMIT $_limit OFFSET ${_page * _limit}
    ''');

      final newSales = result.map((e) => Sale.fromMap(e)).toList();

      if (newSales.length < _limit) {
        _hasMore = false;
      }

      if (loadMore) {
        _allSales.addAll(newSales);
        _updateCache(); // تحديث الـ cache
      } else {
        _allSales = newSales;
        _currentCacheKey = cacheKey;
        _salesCache[cacheKey] = List.from(_allSales); // حفظ في الـ cache

        // ✅ تحديث وقت آخر تحديث للسنة الحالية
        if (isCurrentYear) {
          _lastCurrentYearCacheUpdate = DateTime.now();
        }
      }

      _page++;

      // ✅ تعيين البيانات المعروضة
      _displayedSales = List.from(_allSales);

      // ✅ طباعة معلومات التصحيح
      print('═══════════════════════════════════════════════════════');
      print('📊 جلب الفواتير - الصفحة: $_page');
      print('📋 الجدول المستخدم: ${shouldUseArchive ? 'الأرشيف' : 'الحالي'}');
      print('🔍 فلتر التاريخ: $_dateFilterType');
      print('📅 السنة: $_selectedYear');
      print('🔍 الشروط: $whereClause');
      print('✅ تم تحميل ${newSales.length} فاتورة');
      print('🔑 مفتاح الـ cache: $cacheKey');
      print('💾 إجمالي مفاتيح الـ cache: ${_salesCache.length}');
      print('⏰ آخر تحديث للسنة الحالية: $_lastCurrentYearCacheUpdate');
      print('═══════════════════════════════════════════════════════');
    } catch (e) {
      print('❌ خطأ في جلب الفواتير: $e');
      print('❌ تفاصيل الخطأ: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال الفلترة المحسنة ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  void setPaymentTypeFilter(String? value) {
    final oldValue = _selectedPaymentType;
    _selectedPaymentType = value ?? 'الكل';

    // ✅ إذا كان نفس القيمة، لا تفعل شيئاً
    if (oldValue == _selectedPaymentType) return;

    // ✅ إذا كان يمكن التصفية محلياً، استخدمها
    if (_canFilterLocally()) {
      _applyLocalFilters();
      notifyListeners();
    } else {
      _resetAndFetch();
    }
  }

  void setCustomerFilter(String? value) {
    final oldValue = _selectedCustomer;
    _selectedCustomer = value ?? 'الكل';

    if (oldValue == _selectedCustomer) return;

    if (_canFilterLocally()) {
      _applyLocalFilters();
      notifyListeners();
    } else {
      _resetAndFetch();
    }
  }

  void setDateFilter(DateTime? date) {
    _selectedDate = date;
    _dateFilterType = 'day';

    // ✅ تحقق من الـ cache أولاً
    final cacheKey = _generateCacheKey();
    if (_salesCache.containsKey(cacheKey)) {
      print('✅ استخدام الـ cache الموجود للتاريخ');
      _allSales = List.from(_salesCache[cacheKey]!);
      _displayedSales = List.from(_allSales);
      _currentCacheKey = cacheKey;
      _hasMore = false;
      notifyListeners();
      return;
    }

    _resetAndFetch();
  }

  void setTaxFilter(String? value) {
    final oldValue = _selectedTaxFilter;
    _selectedTaxFilter = value ?? 'الكل';

    if (oldValue == _selectedTaxFilter) return;

    if (_canFilterLocally()) {
      _applyLocalFilters();
      notifyListeners();
    } else {
      _resetAndFetch();
    }
  }

  void clearFilters() {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';

    if (_canFilterLocally()) {
      _displayedSales = List.from(_allSales);
      notifyListeners();
    } else {
      _resetAndFetch();
    }
  }

  void clearAllFilters() {
    _selectedPaymentType = 'الكل';
    _selectedCustomer = 'الكل';
    _selectedTaxFilter = 'الكل';
    _selectedDate = null;
    _selectedMonth = null;
    _selectedYear = null;
    _dateFilterType = 'day';

    // ✅ استخدام الـ cache الافتراضي (السنة الحالية)
    final currentYear = DateTime.now().year;
    final defaultCacheKey =
        'payment=الكل|customer=الكل|tax=الكل|dateType=year|month=null|year=$currentYear|date=null';

    if (_salesCache.containsKey(defaultCacheKey) &&
        _shouldUseCurrentYearCache()) {
      print('✅ استخدام الـ cache الافتراضي');
      _allSales = List.from(_salesCache[defaultCacheKey]!);
      _displayedSales = List.from(_allSales);
      _currentCacheKey = defaultCacheKey;
      _hasMore = false;
      notifyListeners();
    } else {
      // تعيين السنة الحالية وجلب البيانات
      _selectedYear = currentYear;
      _dateFilterType = 'year';
      _resetAndFetch();
    }
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
    _currentCacheKey = null;
    _lastCurrentYearCacheUpdate = null;
    notifyListeners();
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ الدوال العامة للاستخدام ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  Future<void> fetchSales({
    bool loadMore = false,
    bool forceRefresh = false,
  }) async {
    // إذا كان هذا أول تحميل ولم يكن هناك فلتر سنة، نضبط السنة الحالية
    if (!loadMore && _selectedYear == null) {
      _selectedYear = DateTime.now().year;
      _dateFilterType = 'year';
    }

    await _fetchSalesWithFilters(
      loadMore: loadMore,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> loadMoreSales() async {
    if (_hasMore && !_isLoading) {
      await _fetchSalesWithFilters(loadMore: true);
    }
  }

  void applyDefaultFilter() {
    if (_selectedYear == null) {
      _selectedYear = DateTime.now().year;
      _dateFilterType = 'year';
      _resetAndFetch();
    }
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ Prefetching للبيانات ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  // ✅ تحميل بيانات السنة الحالية مسبقاً
  Future<void> prefetchCurrentYear() async {
    final currentYear = DateTime.now().year;
    final cacheKey =
        'payment=الكل|customer=الكل|tax=الكل|dateType=year|month=null|year=$currentYear|date=null';

    if (_salesCache.containsKey(cacheKey)) {
      return; // البيانات موجودة بالفعل
    }

    try {
      print('🔄 بدء تحميل بيانات السنة $currentYear مسبقاً');

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

      print('✅ تم تحميل ${sales.length} فاتورة للسنة $currentYear مسبقاً');
    } catch (e) {
      print('❌ خطأ في تحميل البيانات المسبق: $e');
    }
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال التحديث المعدلة (بدون copyWith) ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  Future<void> updatePaymentType(
    int saleId,
    String paymentType, {
    int? customerId,
  }) async {
    final db = await _dbHelper.db;

    // تأكد إن القيمة فقط 'cash' أو 'credit'
    if (paymentType != 'cash' && paymentType != 'credit') {
      throw Exception('نوع الدفع غير صالح. يجب أن يكون "cash" أو "credit".');
    }

    // إعداد البيانات للتحديث
    Map<String, dynamic> updateData = {'payment_type': paymentType};

    // إذا كان credit وتم تمرير customerId، أضفه للبيانات
    if (paymentType == 'credit') {
      updateData['customer_id'] = customerId;
    }

    // تنفيذ التحديث في قاعدة البيانات
    int count = await db.update(
      'sales',
      updateData,
      where: 'id = ?',
      whereArgs: [saleId],
    );

    // تحقق إذا لم يتم التحديث لأي سجل
    if (count == 0) {
      throw Exception('فشل التعديل: لم يتم العثور على الفاتورة بالرقم المحدد.');
    }

    // ✅ تحديث البيانات المحلية
    final index = _allSales.indexWhere((sale) => sale.id == saleId);
    if (index != -1) {
      // إنشاء Sale جديد مع البيانات المحدثة
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

    // إعداد البيانات للتحديث
    Map<String, dynamic> updateData = {'show_for_tax': showForTax ? 1 : 0};

    // تنفيذ التحديث في قاعدة البيانات
    int count = await db.update(
      'sales',
      updateData,
      where: 'id = ?',
      whereArgs: [saleId],
    );

    // تحقق إذا لم يتم التحديث لأي سجل
    if (count == 0) {
      throw Exception('فشل التعديل: لم يتم العثور على الفاتورة بالرقم المحدد.');
    }

    // ✅ تحديث البيانات المحلية
    final index = _allSales.indexWhere((sale) => sale.id == saleId);
    if (index != -1) {
      // إنشاء Sale جديد مع البيانات المحدثة
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

  // دالة مساعدة لإنشاء Sale جديد (بديل عن copyWith)
  Sale _createUpdatedSale({
    required Sale oldSale,
    String? paymentType,
    int? showForTax,
    int? customerId,
  }) {
    return Sale(
      id: oldSale.id,
      date: oldSale.date,
      totalAmount: oldSale.totalAmount,
      totalProfit: oldSale.totalProfit,
      customerId: customerId ?? oldSale.customerId,
      customerName: oldSale.customerName,
      paymentType: paymentType ?? oldSale.paymentType,
      showForTax:
          showForTax != null ? showForTax == 1 : (oldSale.showForTax == 1),
    );
  }

  Future<Map<String, dynamic>> getSaleDetails(int saleId) async {
    final db = await _dbHelper.db;

    // ✅ تحديد الجدول بناءً على سنة الفاتورة
    bool useArchive = false;

    // أولاً نحاول البحث في sales
    var saleResult = await db.rawQuery(
      '''
      SELECT s.*, c.name as customer_name, c.phone as customer_phone
      FROM sales s 
      LEFT JOIN customers c ON s.customer_id = c.id 
      WHERE s.id = ?
      ''',
      [saleId],
    );

    // إذا لم نجد في sales، نبحث في الأرشيف
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

    // ✅ تحديد جدول العناصر بناءً على مصدر الفاتورة
    String itemsTable = useArchive ? 'sale_items_archive' : 'sale_items';

    // عناصر الفاتورة مع معلومات الوحدات
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

  Future<void> deleteSale(int saleId) async {
    final db = await _dbHelper.db;

    await db.transaction((txn) async {
      // 1. جلب عناصر الفاتورة أولاً
      final saleItems = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      // 2. إرجاع الكميات إلى المخزون
      for (var item in saleItems) {
        final int productId = item['product_id'] as int;
        final double quantity =
            (item['quantity'] is int)
                ? (item['quantity'] as int).toDouble()
                : item['quantity'] as double;
        final String unitType = item['unit_type'] as String;
        final int? unitId = item['unit_id'] as int?;

        double quantityToReturn = quantity;

        // إذا كانت وحدة مخصصة، نحتاج لمعرفة معامل التحويل
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

        // إرجاع الكمية إلى المخزون
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [quantityToReturn, productId],
        );
      }

      // 3. حذف عناصر الفاتورة
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);

      // 4. حذف الفاتورة الرئيسية
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });

    // 5. إزالة الفاتورة من القائمة المحلية
    _allSales.removeWhere((sale) => sale.id == saleId);
    _displayedSales.removeWhere((sale) => sale.id == saleId);

    // 6. تحديث الـ cache
    _updateCache();

    // 7. إلغاء cache السنة الحالية إذا كانت الفاتورة من السنة الحالية
    try {
      final saleIndex = _allSales.indexWhere((sale) => sale.id == saleId);
      if (saleIndex != -1) {
        final sale = _allSales[saleIndex];
        final saleDate = DateTime.parse(sale.date);
        if (saleDate.year == DateTime.now().year) {
          invalidateCurrentYearCache();
        }
      }
    } catch (e) {
      print('❌ خطأ في تحديد سنة الفاتورة المحذوفة: $e');
    }

    notifyListeners();

    print('🗑️ تم حذف الفاتورة #$saleId وإرجاع الكميات إلى المخزون');
  }

  // █████████████████████████████████████████████████████████████████████████
  // ████████████████████████████████ دوال مساعدة للتحديث الفوري ███████████████████████████████████████
  // █████████████████████████████████████████████████████████████████████████

  // ✅ إضافة فاتورة جديدة مباشرة إلى البيانات المعروضة
  Future<void> addNewSaleDirectly(Sale newSale) async {
    try {
      print('➕ إضافة فاتورة جديدة مباشرة إلى البروفايدر #${newSale.id}');

      // 1. أضف الفاتورة إلى بداية القوائم
      _allSales.insert(0, newSale);
      _displayedSales.insert(0, newSale);

      // 2. تحديث الـ Cache
      await updateCacheWithNewSale(newSale);

      // 3. إشعار المستمعين بالتغيير
      notifyListeners();

      print('✅ تم إضافة الفاتورة #${newSale.id} بنجاح إلى البروفايدر');
    } catch (e) {
      print('❌ خطأ في إضافة الفاتورة مباشرة: $e');
    }
  }

  // ✅ تحديث فاتورة موجودة
  Future<void> updateSaleDirectly(Sale updatedSale) async {
    try {
      print('✏️ تحديث فاتورة مباشرة في البروفايدر #${updatedSale.id}');

      // 1. تحديث الفاتورة في القائمة
      final index = _allSales.indexWhere((sale) => sale.id == updatedSale.id);
      if (index != -1) {
        _allSales[index] = updatedSale;
        _displayedSales[index] = updatedSale;

        // 2. تحديث الـ Cache
        _updateCache();

        // 3. إشعار المستمعين بالتغيير
        notifyListeners();

        print('✅ تم تحديث الفاتورة #${updatedSale.id} بنجاح');
      } else {
        print('⚠️ الفاتورة #${updatedSale.id} غير موجودة في القائمة');
      }
    } catch (e) {
      print('❌ خطأ في تحديث الفاتورة مباشرة: $e');
    }
  }
}
