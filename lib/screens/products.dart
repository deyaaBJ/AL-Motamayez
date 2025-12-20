import 'package:flutter/material.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/models/productFilter.dart';
import 'package:shopmate/providers/product_provider.dart';
import 'package:shopmate/models/product.dart';
import 'package:shopmate/screens/add_product_screen.dart' show AddProductScreen;
import 'package:shopmate/widgets/product_filter_bar.dart';
import 'package:shopmate/widgets/product_item.dart';
import 'package:shopmate/widgets/product_table_header.dart';

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
    _loadInitialProducts();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _provider.hasMore &&
          _searchQuery.isEmpty) {
        print('Loading more products...');
        _loadMoreProducts();
      }
    });
  }

  Future<void> _loadInitialProducts() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await _provider.loadProducts(reset: true);
    } catch (e) {
      print('Error loading initial products: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ في تحميل المنتجات: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoading || !_provider.hasMore || _searchQuery.isNotEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _provider.loadProducts(reset: false);
    } catch (e) {
      print('Error loading more products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ دالة لعرض العدد الإجمالي (يمكن استخدامها في AppBar)
  Widget _buildTotalProductsIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFF6A3093).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2, size: 16, color: Color(0xFF6A3093)),
          SizedBox(width: 4),
          Text(
            '${_provider.totalProducts}',
            style: TextStyle(
              color: Color(0xFF6A3093),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'المنتجات',
        showAppBar: true,
        title: 'إدارة المنتجات',
        actions: [
          _buildTotalProductsIndicator(),
          IconButton(
            onPressed: _loadInitialProducts,
            icon: Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewProduct,
          backgroundColor: const Color(0xFF8B5FBF),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
        child: Column(
          children: [
            ProductFilterBar(
              currentFilter: _currentFilter,
              onFilterChanged: (filter) {
                setState(() => _currentFilter = filter);
              },
            ),
            _buildSearchBar(),
            ProductTableHeader(columns: productTableColumns),

            Expanded(child: _buildProductsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.transparent,
      child: TextField(
        onChanged: (value) async {
          setState(() => _searchQuery = value.trim());

          if (value.isEmpty) {
            setState(() => _searchResults = []);
            return;
          }

          final results = await _provider.searchProducts(value);
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
    );
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
          onUpdate: _loadInitialProducts,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.inventory_2,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'لا توجد نتائج للبحث "${_searchQuery}"'
                : 'لا توجد منتجات',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadInitialProducts,
              child: const Text('تحديث'),
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
    await _loadInitialProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
