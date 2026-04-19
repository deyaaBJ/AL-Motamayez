import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/batch.dart';
import 'package:motamayez/models/batch_filter.dart';
import 'package:motamayez/providers/batch_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/widgets/batch_filter_bar.dart';
import 'package:motamayez/widgets/batch_item.dart';
import 'package:motamayez/widgets/batch_table_header.dart';
import 'package:provider/provider.dart';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  bool _isInitialLoading = false;
  String _searchQuery = '';
  BatchFilter _currentFilter = BatchFilter(); // للعرض فقط
  List<Batch> _searchResults = [];
  int _nearExpiryAlertDays = 7;
  int _noExpiryCount = 0;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late BatchProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<BatchProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _nearExpiryAlertDays = settings.nearExpiryAlertDays;

    if (_provider.currentFilter != null) {
      _currentFilter = _provider.currentFilter!;
    }

    _setupScrollListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_provider.batches.isEmpty &&
        !_isInitialLoading &&
        !_provider.isLoadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitialBatches();
      });
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !_provider.isLoadingMore &&
          _provider.hasMore &&
          _searchQuery.isEmpty) {
        _loadMoreBatches();
      }
    });
  }

  Future<void> _loadInitialBatches() async {
    if (_isInitialLoading) return;
    setState(() {
      _isInitialLoading = true;
      _currentFilter = BatchFilter(); // مسح الفلتر من الـ state
    });
    try {
      // مسح الفلتر من الـ provider أيضاً
      _provider.currentFilter = null;
      // تحميل بدون فلتر (عرض جميع الواردات)
      await _provider.loadBatches(reset: true, filter: null);
      final stats = await _provider.getBatchStats();
      if (mounted) {
        setState(() {
          _noExpiryCount =
              (stats['no_expiry_active'] ?? 0) +
              (stats['no_expiry_inactive'] ?? 0);
        });
      }
    } catch (e) {
      _showErrorSnackbar('حدث خطأ في تحميل الواردات: $e');
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadMoreBatches() async {
    if (_searchQuery.isNotEmpty) return;
    // استخدام الفلتر الحالي من الـ provider (الذي تم تطبيقه بالفعل)
    await _provider.loadBatches(reset: false, filter: _provider.currentFilter);
  }

  // ✅ تعديل الدالة لاستقبال BatchFilter? (قد يكون null)
  Future<void> _applyFilter(BatchFilter? filter) async {
    if (filter == null) {
      await _loadInitialBatches();
      return;
    }

    if (_provider.isLoadingMore) return;

    setState(() {
      _currentFilter = filter;
      _isInitialLoading = true;
    });

    try {
      await _provider.loadBatches(reset: true, filter: filter);
      final stats = await _provider.getBatchStats();
      if (mounted) {
        setState(() {
          _noExpiryCount =
              (stats['no_expiry_active'] ?? 0) +
              (stats['no_expiry_inactive'] ?? 0);
        });
      }
    } catch (e) {
      _showErrorSnackbar('خطأ في تطبيق الفلاتر: $e');
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _showNoExpiryBatches() async {
    await _applyFilter(BatchFilter(expiryFilter: 'بدون تاريخ'));
  }

  Future<void> _onSearchChanged(String value) async {
    final trimmedValue = value.trim();
    if (trimmedValue == _searchQuery) return;
    setState(() => _searchQuery = trimmedValue);
    if (trimmedValue.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await _provider.searchBatches(trimmedValue);
      setState(() => _searchResults = results.cast<Batch>());
    } catch (e) {
      log('Error searching: $e');
      _showErrorSnackbar('خطأ في البحث: $e');
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: '🔍 ابحث عن دفعة...',
            hintStyle: TextStyle(fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(Icons.clear, size: 18),
                      onPressed: _clearSearch,
                      color: Colors.grey,
                    )
                    : Icon(Icons.search, size: 18, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Consumer<BatchProvider>(
      builder: (context, provider, child) {
        final allBatches = provider.batches;
        final nearBatches =
            allBatches
                .where(
                  (batch) =>
                      batch.daysRemaining <= _nearExpiryAlertDays &&
                      batch.daysRemaining > 0,
                )
                .length;
        final expiredBatches =
            allBatches.where((batch) => batch.daysRemaining < 0).length;
        final goodBatches =
            allBatches
                .where((batch) => batch.daysRemaining > _nearExpiryAlertDays)
                .length;
        return Card(
          elevation: 1,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _buildStatItem('الكل', allBatches.length, Color(0xFF6A3093)),
                _buildStatItem('جيد', goodBatches, Colors.green),
                _buildStatItem('قريب', nearBatches, Colors.orange),
                _buildStatItem('منتهي', expiredBatches, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  List<Batch> get _displayedBatches {
    if (_searchQuery.isNotEmpty) return _searchResults;
    log(
      '📱 [_displayedBatches] _provider.batches.length: ${_provider.batches.length}',
    );
    for (var i = 0; i < _provider.batches.length; i++) {
      final batch = _provider.batches[i];
      log(
        '📱 [_displayedBatches] Batch $i: ${batch.productName}, expiry=${batch.expiryDate}',
      );
    }
    return _provider.batches;
  }

  Widget _buildBatchesList() {
    final batchesToDisplay = _displayedBatches;
    if (_isInitialLoading && batchesToDisplay.isEmpty) {
      return _buildLoadingIndicator();
    }
    if (batchesToDisplay.isEmpty &&
        !_isInitialLoading &&
        !_provider.isLoadingMore) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: _loadInitialBatches,
      color: Color(0xFF6A3093),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(bottom: 20),
        itemCount:
            batchesToDisplay.length + (_shouldShowLoadingIndicator ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == batchesToDisplay.length) {
            return _buildLoadingMoreIndicator();
          }
          final batch = batchesToDisplay[index];
          return BatchItem(
            batch: batch,
            provider: _provider,
            onUpdate: _loadInitialBatches,
            nearExpiryAlertDays: _nearExpiryAlertDays,
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF6A3093), strokeWidth: 2),
          SizedBox(height: 16),
          Text('جاري تحميل الواردات...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6A3093)),
            SizedBox(height: 8),
            Text(
              'جاري تحميل المزيد...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  bool get _shouldShowLoadingIndicator {
    return _provider.hasMore &&
        _provider.isLoadingMore &&
        _searchQuery.isEmpty &&
        _provider.batches.isNotEmpty;
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchQuery.isNotEmpty
                          ? Icons.search_off
                          : Icons.inventory_2,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 24),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'لا توجد نتائج للبحث "$_searchQuery"'
                          : 'لا توجد واردات',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'حاول البحث بكلمات أخرى'
                          : 'يمكنك إضافة واردات جديدة من شاشة فاتورة الشراء',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_searchQuery.isNotEmpty) SizedBox(height: 24),
                    if (_searchQuery.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _clearSearch,
                        icon: Icon(Icons.refresh, size: 18),
                        label: Text('إعادة تعيين البحث'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6A3093),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
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

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'الواردات',
        title: 'إدارة الدُفعات',
        child: Column(
          children: [
            BatchFilterBar(
              currentFilter: _currentFilter,
              onFilterChanged: _applyFilter,
              noExpiryCount: _noExpiryCount,
              onShowNoExpiry: _showNoExpiryBatches,
            ),
            _buildStatsCard(),
            _buildSearchBar(),
            BatchTableHeader(),
            Expanded(flex: 10, child: _buildBatchesList()),
          ],
        ),
      ),
    );
  }
}
