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
  final List<Product> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;

  String _searchQuery = '';
  ProductFilter _currentFilter = ProductFilter.all;

  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _loadProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadProducts();
      }
    });
  }

  final ProductProvider _provider = ProductProvider();

  Future<void> _loadProducts({bool reset = false}) async {
    if (!reset && (_isLoading || !_hasMore))
      return; // ✅ يسمح بالتحميل لو reset=true

    setState(() {
      _isLoading = true;
    });

    if (reset) {
      _page = 0;
      _products.clear();
      _hasMore = true;
    }

    final newProducts = await _provider.getProducts(reset: reset);

    setState(() {
      _products.addAll(newProducts);
      _isLoading = false;
      _hasMore = newProducts.length == _provider.limit;
    });
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.toLowerCase();
    return _products.where((product) {
      final matchesSearch =
          query.isEmpty
              ? true
              : product.name.toLowerCase().contains(query) ||
                  product.barcode.toLowerCase().contains(query);

      final doesMatchFilter = matchesFilter(context, product, _currentFilter);

      return matchesSearch && doesMatchFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // 🔥 تحويل كل الواجهة للعربي
      child: BaseLayout(
        currentPage: 'المنتجات',
        showAppBar: true,
        title: 'إدارة المنتجات',
        actions: [
          // إذا كان لديك أي actions في AppBar أضفها هنا
          IconButton(
            onPressed: () {
              /* action */
            },
            icon: Icon(Icons.refresh),
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
                setState(() {
                  _currentFilter = filter;
                });
              },
            ),
            _buildSearchBar(),
            ProductTableHeader(columns: const [/* ... */]),
            Expanded(child: _buildProductsList()),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF6A3093)),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'المنتجات',
        style: TextStyle(
          color: Color(0xFF6A3093),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Product> _searchResults = [];

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.transparent,
      child: TextField(
        onChanged: (value) async {
          setState(() {
            _searchQuery = value;
          });

          if (value.trim().isEmpty) {
            setState(() {
              _searchResults = [];
            });
            return;
          }

          final results = await _provider.searchProducts(value);
          setState(() {
            _searchResults = results;
          });
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

  // استخدام القائمة في ListView
  List<Product> get displayedProducts {
    if (_searchQuery.isEmpty) return _products;
    return _searchResults;
  }

  Widget _buildProductsList() {
    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredProducts.isEmpty && !_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد منتجات',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProducts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredProducts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final product = _filteredProducts[index];
        return ProductItem(
          product: product,
          provider: _provider,
          onUpdate:
              () => setState(() {
                _loadProducts(reset: true);
              }),
        );
      },
    );
  }

  void _addNewProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProductScreen()),
    );

    await _loadProducts(reset: true);
    setState(() {});
  }
}
