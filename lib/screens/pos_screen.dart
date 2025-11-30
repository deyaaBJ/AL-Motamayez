import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/components/posPageCompoments/custom_app_bar.dart';
import 'package:shopmate/components/posPageCompoments/search_section.dart';
import 'package:shopmate/models/cart_item.dart';
import 'package:shopmate/models/customer.dart';
import 'package:shopmate/models/product.dart';
import 'package:shopmate/models/product_unit.dart';
import 'package:shopmate/models/sale.dart';
import 'package:shopmate/models/sale_item.dart';
import 'package:shopmate/providers/product_provider.dart';
import 'package:shopmate/providers/customer_provider.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/widgets/cart_item_widget.dart';
import 'package:shopmate/widgets/table_header_widget.dart';
import 'package:shopmate/widgets/customer_form_dialog.dart';

class PosScreen extends StatefulWidget {
  final Sale? existingSale;
  final bool isReturnMode;
  final bool isEditMode;

  const PosScreen({
    super.key,
    this.existingSale,
    this.isReturnMode = false,
    this.isEditMode = false,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final List<CartItem> _cartItems = [];
  double _totalAmount = 0.0;
  List<dynamic> _searchResults = [];
  bool _showSearchResults = false;
  FocusNode _searchFocusNode = FocusNode();
  String _searchType = 'product';
  bool _isSearching = false;
  final ProductProvider _provider = ProductProvider();

  // متغيرات للوضع الإرجاع/التعديل
  Sale? _originalSale;
  bool _isSaleLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();

    if (widget.existingSale != null && !_isSaleLoaded) {
      _loadExistingSale(widget.existingSale!);
    }
  }

  @override
  void didUpdateWidget(covariant PosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // منع إعادة التحميل إذا تغيرت الـ widget
    if (oldWidget.existingSale?.id != widget.existingSale?.id &&
        widget.existingSale != null &&
        !_isSaleLoaded) {
      _loadExistingSale(widget.existingSale!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // دالة محسنة لتحميل الفاتورة الموجودة
  Future<void> _loadExistingSale(Sale sale) async {
    if (_isLoading || _isSaleLoaded) return;

    _isLoading = true;

    try {
      _originalSale = sale;

      // جلب عناصر الفاتورة من قاعدة البيانات
      final List<SaleItem> saleItems = await _provider.getSaleItems(sale.id);

      print('🔄 جاري تحميل ${saleItems.length} عنصر من الفاتورة #${sale.id}');

      // مسح القائمة الحالية أولاً
      _cartItems.clear();

      for (final saleItem in saleItems) {
        try {
          // جلب بيانات المنتج
          final product = await _provider.getProductById(saleItem.productId);
          if (product != null) {
            // جلب الوحدات المتاحة
            List<ProductUnit> units = [];
            if (product.id != null) {
              units = await _provider.getProductUnits(product.id!);
              units = _removeDuplicateUnits(units);
            }

            // تحديد الوحدة المختارة من saleItem - الحل الآمن
            ProductUnit? selectedUnit;

            if (saleItem.unitId != null && units.isNotEmpty) {
              // البحث عن الوحدة المطابقة
              for (final unit in units) {
                if (unit.id == saleItem.unitId) {
                  selectedUnit = unit;
                  break;
                }
              }
              // إذا لم نجد وحدة مطابقة، نستخدم الأولى
              selectedUnit ??= units.first;
            } else if (units.isNotEmpty) {
              selectedUnit = units.first;
            }

            // إنشاء CartItem من SaleItem
            final cartItem = CartItem(
              product: product,
              quantity:
                  widget.isReturnMode ? -saleItem.quantity : saleItem.quantity,
              availableUnits: units,
              selectedUnit: selectedUnit,
            );

            _cartItems.add(cartItem);
            print('✅ تم إضافة ${product.name} بكمية ${cartItem.quantity}');
          } else {
            print('⚠️ المنتج غير موجود: ${saleItem.productId}');
          }
        } catch (e) {
          print('❌ خطأ في تحميل عنصر الفاتورة: $e');
        }
      }

      if (mounted) {
        setState(() {
          _calculateTotal();
          _isSaleLoaded = true;
        });

        if (_cartItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على عناصر في الفاتورة'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحميل ${_cartItems.length} عنصر من الفاتورة'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _isSaleLoaded = false;
      print('❌ خطأ في تحميل الفاتورة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الفاتورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Directionality(
      textDirection: TextDirection.rtl, // واجهة عربية كاملة
      child: BaseLayout(
        currentPage: 'المبيعات', // اسم الصفحة للسايدبار
        showAppBar: true,
        title: 'نقاط البيع',
        actions: [
          IconButton(
            onPressed: () {
              // أي عملية تحديث أو إعادة تحميل
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        floatingActionButton: null, // أو ضع FAB إذا احتجت
        child: Column(
          children: [
            // عرض معلومات الوضع الحالي
            if (widget.isReturnMode || widget.isEditMode) _buildModeBanner(),

            // قسم البحث
            SearchSection(
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchType: _searchType,
              isSearching: _isSearching,
              performSearch: _performSearch,
              onEnterPressed: _handleEnterPressed,
              clearSearch: _clearSearch,
              showSearchResults: _showSearchResults,
              refreshState: () => setState(() {}),
              onChangeSearchType: (type) {
                setState(() {
                  _searchType = type;
                  _searchController.clear();
                  _showSearchResults = false;
                  _searchResults.clear();
                });
              },
            ),

            // نتائج البحث
            if (_showSearchResults) _buildSearchResults(),

            // جدول العربة أو المبيعات
            Expanded(child: _buildCartTable()),

            // إجمالي المبيعات والأزرار
            _buildTotalAndButtons(),
          ],
        ),
      ),
    );
  }

  // بانر يوضح وضع التعديل أو الإرجاع
  Widget _buildModeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color:
          widget.isReturnMode
              ? Colors.orangeAccent.withOpacity(0.2)
              : Colors.blueAccent.withOpacity(0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isReturnMode ? Icons.assignment_return : Icons.edit,
            color: widget.isReturnMode ? Colors.orange : Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            widget.isReturnMode
                ? 'وضع الإرجاع - الفاتورة الأصلية #${_originalSale?.id}'
                : 'وضع التعديل - الفاتورة #${_originalSale?.id}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: widget.isReturnMode ? Colors.orange : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  _searchType == 'unit' ? Icons.inventory_2 : Icons.search,
                  color: const Color(0xFF6A3093),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'نتائج البحث (${_searchResults.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A3093),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      _showSearchResults = false;
                      _searchController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                _searchResults.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 32, color: Colors.grey),
                          SizedBox(height: 4),
                          Text(
                            'لا توجد نتائج',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return _buildSearchResultItem(item);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    if (item is Product) {
      return _buildProductResultItem(item);
    } else if (item is ProductUnit) {
      return _buildUnitResultItem(item);
    } else {
      return Container();
    }
  }

  Widget _buildProductResultItem(Product product) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.shopping_bag,
          color: Color(0xFF6A3093),
          size: 16,
        ),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'باركود: ${product.barcode}',
            style: const TextStyle(fontSize: 10),
          ),
          Text(
            'سعر: ₪${product.price.toStringAsFixed(2)} | مخزون: ${product.quantity}',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
      trailing:
          product.quantity > 0
              ? IconButton(
                icon: const Icon(
                  Icons.add_shopping_cart,
                  color: Colors.green,
                  size: 16,
                ),
                onPressed: () => _addProductFromSearch(product),
              )
              : const Text(
                'نفذ',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
      onTap: () => _addProductFromSearch(product),
    );
  }

  Widget _buildUnitResultItem(ProductUnit unit) {
    return FutureBuilder<Product?>(
      future: _provider.getProductById(unit.productId),
      builder: (context, snapshot) {
        final product = snapshot.data;
        if (product == null) {
          return Container();
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.inventory_2,
              color: Color(0xFF2196F3),
              size: 16,
            ),
          ),
          title: Text(
            '${product.name} - ${unit.unitName}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'باركود الوحدة: ${unit.barcode ?? "لا يوجد"}',
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                'سعر الوحدة: ₪${unit.sellPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
          trailing:
              product.quantity > 0
                  ? IconButton(
                    icon: const Icon(
                      Icons.add_shopping_cart,
                      color: Colors.blue,
                      size: 16,
                    ),
                    onPressed: () => _addUnitFromSearch(unit, product),
                  )
                  : const Text(
                    'نفذ',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          onTap: () {
            if (product.quantity > 0) {
              _addUnitFromSearch(unit, product);
            }
          },
        );
      },
    );
  }

  // الدوال المحسنة للبحث والإضافة
  Future<void> _performSearch(String query) async {
    if (_isSearching) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = <dynamic>[];

      if (_searchType == 'product') {
        final productsByName = await _provider.searchProductsByName(query);
        results.addAll(productsByName);

        final productsByBarcode = await _provider.searchProductsByBarcode(
          query,
        );
        for (final product in productsByBarcode) {
          if (!results.any(
            (item) => item is Product && item.id == product.id,
          )) {
            results.add(product);
          }
        }
      } else if (_searchType == 'unit') {
        final unitsByBarcode = await _provider.searchProductUnitsByBarcode(
          query,
        );
        for (final unit in unitsByBarcode) {
          final product = await _provider.getProductById(unit.productId);
          if (product != null) {
            results.add(unit);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _showSearchResults = true;
        _isSearching = false;
      });
    } catch (e) {
      print('Error performing search: $e');
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _handleEnterPressed(String query) async {
    if (_isSearching) return;

    if (_searchResults.isNotEmpty) {
      final firstResult = _searchResults.first;
      if (firstResult is Product) {
        _addProductFromSearch(firstResult);
      } else if (firstResult is ProductUnit) {
        final product = await _provider.getProductById(firstResult.productId);
        if (product != null && product.quantity > 0) {
          _addUnitFromSearch(firstResult, product);
        }
      }
    } else {
      await _performSearch(query);
      if (_searchResults.isNotEmpty) {
        final firstResult = _searchResults.first;
        if (firstResult is Product) {
          _addProductFromSearch(firstResult);
        } else if (firstResult is ProductUnit) {
          final product = await _provider.getProductById(firstResult.productId);
          if (product != null && product.quantity > 0) {
            _addUnitFromSearch(firstResult, product);
          }
        }
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _showSearchResults = false;
      _searchResults.clear();
      _searchFocusNode.requestFocus();
    });
  }

  void _addProductFromSearch(Product product) {
    if (product.quantity < 1) {
      _showOutOfStockDialog(product.name);
      return;
    }
    _addProductToCartDirectly(product);
    _clearSearchAfterAction();
  }

  void _addUnitFromSearch(ProductUnit unit, Product product) {
    if (product.quantity < 1) {
      _showOutOfStockDialog('${product.name} - ${unit.unitName}');
      return;
    }
    _addUnitToCartDirectly(unit, product);
    _clearSearchAfterAction();
  }

  void _clearSearchAfterAction() {
    setState(() {
      _showSearchResults = false;
      _searchController.clear();
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _addUnitToCartDirectly(ProductUnit unit, Product product) async {
    try {
      final units = await _provider.getProductUnits(product.id!);
      final distinctUnits = _removeDuplicateUnits(units);

      final existingItemIndex = _cartItems.indexWhere(
        (item) => item.product.barcode == product.barcode,
      );

      if (!mounted) return;
      setState(() {
        if (existingItemIndex != -1) {
          _cartItems[existingItemIndex].selectedUnit = unit;
        } else {
          _cartItems.add(
            CartItem(
              product: product,
              quantity: widget.isReturnMode ? -1 : 1,
              availableUnits: distinctUnits,
              selectedUnit: unit,
            ),
          );
        }
        _calculateTotal();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ${widget.isReturnMode ? 'إرجاع' : 'إضافة'} ${product.name} (${unit.unitName}) ${widget.isReturnMode ? 'من' : 'إلى'} السلة',
          ),
          backgroundColor: widget.isReturnMode ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error adding unit to cart: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // دالة مساعدة لإزالة التكرار من قائمة الوحدات
  List<ProductUnit> _removeDuplicateUnits(List<ProductUnit> units) {
    final seen = <int>{};
    return units.where((unit) {
      if (unit.id == null) return false;
      if (seen.contains(unit.id)) return false;
      seen.add(unit.id!);
      return true;
    }).toList();
  }

  Future<void> _addProductToCartDirectly(Product product) async {
    try {
      List<ProductUnit> units = [];
      if (product.id != null) {
        units = await _provider.getProductUnits(product.id!);
        units = _removeDuplicateUnits(units);
      }

      final existingItemIndex = _cartItems.indexWhere(
        (item) => item.product.barcode == product.barcode,
      );

      if (!mounted) return;
      setState(() {
        if (existingItemIndex != -1) {
          _cartItems[existingItemIndex].quantity +=
              widget.isReturnMode ? -1 : 1;
        } else {
          _cartItems.add(
            CartItem(
              product: product,
              quantity: widget.isReturnMode ? -1 : 1,
              availableUnits: units,
              selectedUnit: units.isNotEmpty ? units.first : null,
            ),
          );
        }
        _calculateTotal();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ${widget.isReturnMode ? 'إرجاع' : 'إضافة'} ${product.name} ${widget.isReturnMode ? 'من' : 'إلى'} السلة',
          ),
          backgroundColor: widget.isReturnMode ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error adding product to cart: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildCartTable() {
    if (_cartItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'لا توجد عناصر في السلة',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const TableHeaderWidget(),
              ..._cartItems
                  .asMap()
                  .entries
                  .map(
                    (entry) => CartItemWidget(
                      key: ValueKey(
                        'cart_item_${entry.key}_${entry.value.product.barcode}',
                      ),
                      item: entry.value,
                      onQuantityChange:
                          (item, change) => _updateQuantity(item, change),
                      onRemove: _removeFromCart,
                      onUnitChange: _updateSelectedUnit,
                      // isReturnMode: widget.isReturnMode, // ✅ تم إصلاح الخطأ هنا
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAndButtons() {
    final isNegativeTotal = _totalAmount < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color:
                  isNegativeTotal
                      ? Colors.orange.withOpacity(0.1)
                      : const Color(0xFFF8F5FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isNegativeTotal ? Colors.orange : const Color(0xFFE1D4F7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isReturnMode ? 'المبلغ المسترجع:' : 'المجموع الكلي:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isNegativeTotal
                            ? Colors.orange
                            : const Color(0xFF6A3093),
                  ),
                ),
                Text(
                  '₪${_totalAmount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        isNegativeTotal
                            ? Colors.orange
                            : const Color(0xFF8B5FBF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.isReturnMode || widget.isEditMode) ...[
                Expanded(
                  child: _buildActionButton(
                    widget.isReturnMode ? 'إتمام الإرجاع' : 'حفظ التعديلات',
                    widget.isReturnMode ? Icons.assignment_return : Icons.save,
                    widget.isReturnMode ? Colors.orange : Colors.blue,
                    _completeReturnOrEdit,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _buildActionButton(
                  'طباعة',
                  Icons.receipt,
                  const Color(0xFF8B5FBF),
                  _printInvoice,
                ),
              ),
              if (!widget.isReturnMode && !widget.isEditMode) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'إتمام البيع',
                    Icons.check_circle,
                    const Color(0xFF4CAF50),
                    _completeSale,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'بيع مؤجل',
                    Icons.schedule,
                    const Color(0xFFFF9800),
                    _recordDebtSale,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  'حذف',
                  Icons.delete_sweep,
                  const Color(0xFFF44336),
                  _clearCart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: _cartItems.isEmpty ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _updateQuantity(CartItem item, double change) {
    if (!mounted) return;
    setState(() {
      item.quantity += change;
      if (item.quantity == 0) {
        _cartItems.remove(item);
      }
      _calculateTotal();
    });
  }

  void _updateSelectedUnit(CartItem item, ProductUnit? unit) {
    if (!mounted) return;
    setState(() {
      item.selectedUnit = unit;
      _calculateTotal();
    });
  }

  void _removeFromCart(CartItem item) {
    if (!mounted) return;
    setState(() {
      _cartItems.remove(item);
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      double price = item.selectedUnit?.sellPrice ?? item.product.price;
      return sum + (price * item.quantity);
    });
  }

  void _showOutOfStockDialog(String productName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text('الكمية نفدت', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Text('المنتج "$productName" غير متوفر في المخزون.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسنًا'),
              ),
            ],
          ),
    );
  }

  Future<void> _printInvoice() async =>
      await _processSaleWithValidation(printInvoice: true);

  Future<void> _processSaleWithValidation({
    bool printInvoice = false,
    bool isDebtSale = false,
  }) async {
    _showSaleConfirmationDialog(printInvoice, isDebtSale);
  }

  void _showSaleConfirmationDialog(bool printInvoice, bool isDebtSale) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(widget.isReturnMode ? 'تأكيد الإرجاع' : 'تأكيد البيع'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المجموع: ₪${_totalAmount.abs().toStringAsFixed(2)}'),
                if (isDebtSale) const Text('نوع البيع: بيع مؤجل'),
                if (printInvoice) const Text('سيتم طباعة الفاتورة'),
                if (widget.isReturnMode) const Text('نوع العملية: إرجاع'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _finalizeSale(printInvoice, isDebtSale);
                },
                child: Text(
                  widget.isReturnMode ? 'تأكيد الإرجاع' : 'تأكيد البيع',
                ),
              ),
            ],
          ),
    );
  }

  void _finalizeSale(bool printInvoice, bool isDebtSale) {
    _clearCart();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isReturnMode
              ? 'تم إتمام الإرجاع بنجاح'
              : 'تم إتمام البيع ${isDebtSale ? 'المؤجل ' : ''}بنجاح',
        ),
        backgroundColor: widget.isReturnMode ? Colors.orange : Colors.green,
      ),
    );
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _totalAmount = 0.0;
    });
  }

  // دالة جديدة للإرجاع أو التعديل
  Future<void> _completeReturnOrEdit() async {
    print("ddddddddddddddddddddd");
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('السلة فارغة')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();

    try {
      // if (widget.isReturnMode) {
      //   // معالجة الإرجاع
      //   await productProvider.processReturn(
      //     originalSale: _originalSale!,
      //     returnItems: _cartItems,
      //     totalReturnAmount: _totalAmount.abs(),
      //     userRole: auth.role ?? 'user',
      //   );
      // } else
      if (widget.isEditMode) {
        print("===== الفاتورة قبل الحفظ (Edit Mode) =====");
        print("Original Sale: $_originalSale");

        print("Cart Items:");
        for (var item in _cartItems) {
          print(
            " - ${item.product.name} | qty: ${item.quantity} | price: ${item.product.price} | total: ${item.totalPrice}",
          );
        }

        print("Total Amount: $_totalAmount");
        print("=================================");

        await productProvider.updateSale(
          originalSale: _originalSale!,
          cartItems: _cartItems,
          totalAmount: _totalAmount,
          userRole: auth.role ?? 'user',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isReturnMode
                  ? 'تم إتمام الإرجاع بنجاح'
                  : 'تم تحديث الفاتورة بنجاح',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _completeSale() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('السلة فارغة')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();

    try {
      await productProvider.addSale(
        cartItems: _cartItems,
        totalAmount: _totalAmount,
        paymentType: 'cash',
        customerId: null,
        userRole: auth.role ?? 'user',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إتمام البيع بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _clearCart();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _recordDebtSale() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('السلة فارغة')));
      return;
    }

    final customerProvider = context.read<CustomerProvider>();

    await customerProvider.fetchCustomers();
    final List<Customer> customers = customerProvider.customers ?? [];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _buildCustomerSelectionDialog(customers),
    );
  }

  Widget _buildCustomerSelectionDialog(List<Customer> customers) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people, color: Color(0xFF6A3093)),
                ),
                const SizedBox(width: 12),
                const Text(
                  'اختر عميل',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A3093),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child:
                  customers.isEmpty
                      ? const Center(
                        child: Text(
                          'لا توجد عملاء',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.person,
                              color: Color(0xFF8B5FBF),
                            ),
                            title: Text(customer.name),
                            subtitle: Text(customer.phone!),
                            onTap: () {
                              Navigator.pop(context);
                              _finalizeSaleWithCustomer(customer);
                            },
                          );
                        },
                      ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6A3093),
                      side: const BorderSide(color: Color(0xFF6A3093)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddCustomerDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A3093),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('إضافة عميل جديد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog() {
    final customerProvider = context.read<CustomerProvider>();

    showDialog(
      context: context,
      builder:
          (context) => CustomerFormDialog(
            onSave: (customer) async {
              try {
                await customerProvider.addCustomer(customer);
                if (mounted) {
                  _finalizeSaleWithCustomer(customer);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في إضافة العميل: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
    );
  }

  Future<void> _finalizeSaleWithCustomer(Customer customer) async {
    final auth = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();

    try {
      await productProvider.addSale(
        cartItems: _cartItems,
        totalAmount: _totalAmount,
        paymentType: 'credit',
        customerId: customer.id,
        userRole: auth.role ?? 'user',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسجيل بيع مؤجل للعميل ${customer.name} بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _clearCart();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
