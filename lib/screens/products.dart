import 'package:flutter/material.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/productFilter.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/screens/add_product_screen.dart'
    show AddProductScreen;
import 'package:motamayez/widgets/product_filter_bar.dart';
import 'package:motamayez/widgets/product_item.dart';
import 'package:motamayez/widgets/product_table_header.dart';
import 'dart:developer';
import 'package:provider/provider.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  ProductFilter _currentFilter = ProductFilter.all;
  List<Product> _searchResults = [];

  final ScrollController _scrollController = ScrollController();
  final ProductProvider _provider = ProductProvider();
  final List<HeaderColumn> productTableColumns = [
    HeaderColumn(label: 'المنتج', flex: 3),
    HeaderColumn(label: 'سعر البيع', flex: 2),
    HeaderColumn(label: 'سعر الشراء', flex: 2),
    HeaderColumn(label: 'الكمية', flex: 2),
    HeaderColumn(label: 'الحالة', flex: 1),
    HeaderColumn(label: 'الإجراءات', flex: 1),
  ];

  @override
  void initState() {
    super.initState();
    _loadProductsByFilter(_currentFilter, reset: true);
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _provider.hasMore &&
          _searchQuery.isEmpty) {
        log('Loading more products...');
        _loadMoreProducts();
      }
    });
  }

  // ✅ دالة جديدة: تحميل المنتجات حسب الفلتر
  Future<void> _loadProductsByFilter(
    ProductFilter filter, {
    bool reset = true,
  }) async {
    if (_isLoading) return;

    setState(() {
      _currentFilter = filter;
      _isLoading = true;
    });

    try {
      await _provider.loadProductsByFilter(filter, reset: reset);
    } catch (e) {
      log('Error loading products by filter: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ في تحميل المنتجات: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ تحديث دالة _loadMoreProducts
  Future<void> _loadMoreProducts() async {
    if (_isLoading || !_provider.hasMore || _searchQuery.isNotEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _provider.loadMoreProducts();
    } catch (e) {
      log('Error loading more products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ تحديث شريط البحث ليتناسب مع الفلتر
  // ✅ Search Bar مع عدد المنتجات بجانبه
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.transparent,
      child: Row(
        children: [
          // ✅ عدد المنتجات (شارة صغيرة)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getFilterColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getFilterColor(), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2, size: 16, color: _getFilterColor()),
                const SizedBox(width: 6),
                Text(
                  '${_provider.totalProducts}',
                  style: TextStyle(
                    color: _getFilterColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ✅ Search Bar (ياخد باقي المساحة)
          Expanded(
            child: TextField(
              onChanged: (value) async {
                setState(() => _searchQuery = value.trim());

                if (value.isEmpty) {
                  setState(() => _searchResults = []);
                  return;
                }

                bool? active;
                switch (_currentFilter) {
                  case ProductFilter.inactive:
                    active = false;
                    break;
                  case ProductFilter.all:
                    active = null;
                    break;
                  default:
                    active = true;
                }

                final results = await _provider.searchProducts(
                  value,
                  active: active,
                );
                setState(() => _searchResults = results);
              },
              decoration: InputDecoration(
                hintText: '🔍 ابحث عن منتج...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ مؤشر العدد الإجمالي (محسّن)
  Widget _buildTotalProductsIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getFilterColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getFilterColor(), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getFilterIcon(), size: 16, color: _getFilterColor()),
          SizedBox(width: 6),
          Text(
            '${_provider.totalProducts} ${_getFilterLabel()}',
            style: TextStyle(
              color: _getFilterColor(),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ⬅️ دوال مساعدة لتحديد الألوان والرموز حسب الفلتر
  Color _getFilterColor() {
    switch (_currentFilter) {
      case ProductFilter.inactive:
        return Colors.red;
      case ProductFilter.available:
        return Colors.green;
      case ProductFilter.unavailable:
        return Colors.orange;
      case ProductFilter.lowStock:
        return Colors.amber;
      default:
        return Color(0xFF6A3093);
    }
  }

  IconData _getFilterIcon() {
    switch (_currentFilter) {
      case ProductFilter.inactive:
        return Icons.block;
      case ProductFilter.available:
        return Icons.check_circle;
      case ProductFilter.unavailable:
        return Icons.cancel;
      case ProductFilter.lowStock:
        return Icons.warning;
      default:
        return Icons.inventory_2;
    }
  }

  String _getFilterLabel() {
    switch (_currentFilter) {
      case ProductFilter.inactive:
        return 'غير نشط';
      case ProductFilter.available:
        return 'متوفر';
      case ProductFilter.unavailable:
        return 'غير متوفر';
      case ProductFilter.lowStock:
        return 'منخفض';
      default:
        return 'منتج';
    }
  }

  // ✅ الحصول على المنتجات المعروضة
  List<Product> get _displayedProducts {
    if (_searchQuery.isNotEmpty) {
      return _searchResults.where((product) {
        return matchesFilter(context, product, _currentFilter);
      }).toList();
    }

    return _provider.products.where((product) {
      return matchesFilter(context, product, _currentFilter);
    }).toList();
  }

  Widget _buildProductsList() {
    final productsToDisplay = _displayedProducts;

    if (_isLoading && productsToDisplay.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (productsToDisplay.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount:
          productsToDisplay.length + (_shouldShowLoadingIndicator ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == productsToDisplay.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final product = productsToDisplay[index];
        return ProductItem(
          product: product,
          provider: _provider,
          onUpdate: () => _loadProductsByFilter(_currentFilter, reset: true),
        );
      },
    );
  }

  bool get _shouldShowLoadingIndicator {
    return _isLoading &&
        _provider.hasMore &&
        _searchQuery.isEmpty &&
        _provider.products.isNotEmpty;
  }

  Widget _buildEmptyState() {
    String emptyMessage = 'لا توجد منتجات';
    IconData emptyIcon = Icons.inventory_2;

    switch (_currentFilter) {
      case ProductFilter.inactive:
        emptyMessage = 'لا توجد منتجات غير نشطة';
        emptyIcon = Icons.block;
        break;
      case ProductFilter.available:
        emptyMessage = 'لا توجد منتجات متوفرة';
        emptyIcon = Icons.check_circle;
        break;
      case ProductFilter.unavailable:
        emptyMessage = 'لا توجد منتجات غير متوفرة';
        emptyIcon = Icons.cancel;
        break;
      case ProductFilter.lowStock:
        emptyMessage = 'لا توجد منتجات منخفضة المخزون';
        emptyIcon = Icons.warning;
        break;
      default:
        emptyMessage = 'لا توجد منتجات';
        emptyIcon = Icons.inventory_2;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : emptyIcon,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'لا توجد نتائج للبحث "$_searchQuery"'
                : emptyMessage,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  () => _loadProductsByFilter(_currentFilter, reset: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getFilterColor(),
              ),
              child: Text('تحديث', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  void _addNewProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProductScreen()),
    );
    await _loadProductsByFilter(_currentFilter, reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'المنتجات',
        title: 'إدارة المنتجات',
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewProduct,
          backgroundColor: const Color(0xFF8B5FBF),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
        child: Column(
          children: [
            ProductFilterBar(
              currentFilter: _currentFilter,
              onFilterChanged: _loadProductsByFilter,
            ),
            // ✅ شيل _buildTotalProductsIndicator() إذا بدك، أو خليه فوق
            _buildSearchBar(), // ✅ هلأ فيه العدد بجانبه
            ProductTableHeader(columns: productTableColumns),
            Expanded(child: _buildProductsList()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

// ✅ دالة الفلترة المحدثة (يجب أن تكون في ملف منفصل ولكن نضيفها هنا للتوضيح)
// تأكد من وجود هذه الدالة في صفحة ProductsScreen
bool matchesFilter(
  BuildContext context,
  Product product,
  ProductFilter currentFilter,
) {
  // الحصول على الإعدادات من Provider
  try {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final threshold = settingsProvider.lowStockThreshold;

    switch (currentFilter) {
      case ProductFilter.all:
        return true; // يظهر جميع المنتجات

      case ProductFilter.available:
        return product.quantity > 0;

      case ProductFilter.unavailable:
        return product.quantity == 0;

      case ProductFilter.lowStock:
        return product.quantity > 0 && product.quantity <= threshold;

      case ProductFilter.inactive:
        return !product.active; // المنتجات غير النشطة فقط
    }
  } catch (e) {
    // إذا حدث خطأ في Provider، استخدم قيم افتراضية
    log('Error in matchesFilter: $e');
    final threshold = 5; // قيمة افتراضية

    switch (currentFilter) {
      case ProductFilter.all:
        return true;
      case ProductFilter.available:
        return product.quantity > 0;
      case ProductFilter.unavailable:
        return product.quantity == 0;
      case ProductFilter.lowStock:
        return product.quantity > 0 && product.quantity <= threshold;
      case ProductFilter.inactive:
        return !product.active;
    }
  }
}
