import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motamayez/providers/sales_provider.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/components/posPageCompoments/search_section.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/models/cart_item.dart';
import 'package:motamayez/models/customer.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/models/product_unit.dart';
import 'package:motamayez/models/sale.dart';
import 'package:motamayez/models/sale_item.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/providers/customer_provider.dart';
import 'package:motamayez/providers/debt_provider.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/services/thermal_receipt_printer.dart';
import 'package:motamayez/widgets/cart_item_widget.dart';
import 'package:motamayez/widgets/table_header_widget.dart';
import 'package:motamayez/widgets/customer_form_dialog.dart';
import 'dart:developer';

class PosScreen extends StatefulWidget {
  final Sale? existingSale;
  final bool isEditMode;

  const PosScreen({super.key, this.existingSale, this.isEditMode = false});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final List<CartItem> _cartItems = [];
  double _totalAmount = 0.0; // مجموع العناصر
  double _finalAmount = 0.0; // المجموع النهائي بعد التعديل
  bool _isTotalModified = false; // هل تم تعديل المجموع؟
  final TextEditingController _totalEditorController = TextEditingController();

  List<dynamic> _searchResults = [];
  bool _showSearchResults = false;
  final FocusNode _searchFocusNode = FocusNode();
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
    _totalEditorController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingSale(Sale sale) async {
    if (_isLoading || _isSaleLoaded) return;

    _isLoading = true;

    try {
      _originalSale = sale;

      final List<SaleItem> saleItems = await _provider.getSaleItems(sale.id);

      log('🔄 جاري تحميل ${saleItems.length} عنصر من الفاتورة #${sale.id}');

      _cartItems.clear();

      for (final saleItem in saleItems) {
        try {
          if (saleItem.itemType == 'service' || saleItem.productId == null) {
            final serviceItem = CartItem.service(
              serviceName: saleItem.itemName,
              price: saleItem.price,
            );
            serviceItem.quantity = saleItem.quantity;
            serviceItem.setCustomPrice(saleItem.price);
            _cartItems.add(serviceItem);
            continue;
          }

          final product = await _provider.getProductById(saleItem.productId!);
          if (product != null) {
            List<ProductUnit> units = [];
            if (product.id != null) {
              units = await _provider.getProductUnits(product.id!);
              units = _removeDuplicateUnits(units);
            }

            ProductUnit? selectedUnit;

            if (saleItem.unitId != null && units.isNotEmpty) {
              for (final unit in units) {
                if (unit.id == saleItem.unitId) {
                  selectedUnit = unit;
                  break;
                }
              }
            }

            final defaultUnitPrice =
                selectedUnit?.effectivePrice ?? product.effectivePrice;
            final hasCustomPrice =
                (saleItem.price - defaultUnitPrice).abs() > 0.0001;

            final cartItem = CartItem.product(
              product: product,
              quantity: saleItem.quantity,
              availableUnits: units,
              selectedUnit: selectedUnit,
              customPrice: hasCustomPrice ? saleItem.price : null,
            );

            _cartItems.add(cartItem);
          }
        } catch (e) {
          log('Error loading invoice item: $e');
        }
      }

      if (mounted) {
        setState(() {
          _totalAmount = _cartItems.fold(0.0, (sum, item) {
            return sum + (item.unitPrice * item.quantity);
          });
          _finalAmount = sale.totalAmount;
          _isTotalModified = (_finalAmount != _totalAmount);
          _isSaleLoaded = true;
        });
      }
    } catch (e) {
      _isSaleLoaded = false;
      log('❌ خطأ في تحميل الفاتورة: $e');
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = Provider.of<SettingsProvider>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: '',

        floatingActionButton: null,
        child: Column(
          children: [
            if (widget.isEditMode) _buildModeBanner(),

            Row(
              children: [
                Expanded(
                  child: SearchSection(
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
                    addService: _addService,
                  ),
                ),
                const SizedBox(width: 8),

                // زر إضافة خدمة
              ],
            ),

            if (_showSearchResults) _buildSearchResults(),

            Expanded(child: _buildCartTable()),

            _buildTotalAndButtons(settings),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      // ignore: deprecated_member_use
      color: Colors.blueAccent.withOpacity(0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.edit, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(
            'وضع التعديل - الفاتورة #${_originalSale?.id}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
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
            // ignore: deprecated_member_use
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
            'سعر: ${_getCurrency()}${product.price.toStringAsFixed(2)} | مخزون: ${product.quantity}',
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
                'سعر الوحدة: ${_getCurrency()}${unit.effectivePrice.toStringAsFixed(2)}',
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

  String _getCurrency() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    return settings.currencyName;
  }

  Future<void> _performSearch(String query) async {
    if (_isSearching || query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = <dynamic>[];
      final trimmedQuery = query.trim();

      // تحديد إذا البحث أرقام (باركود) أو نص (اسم)
      final isBarcodeSearch = double.tryParse(trimmedQuery) != null;

      // 1️⃣ البحث بالـ units المرتبطة بالباركود
      if (isBarcodeSearch) {
        final unitsByBarcode = await _provider.searchProductUnitsByBarcode(
          trimmedQuery,
        );
        for (final unit in unitsByBarcode) {
          final product = await _provider.getProductById(unit.productId);
          if (product != null) {
            results.add(unit);
          }
        }

        final productsByBarcode = await _provider.searchProductsByBarcode(
          trimmedQuery,
        );
        for (final product in productsByBarcode) {
          final isUnitAlreadyAdded = results.any(
            (item) => item is ProductUnit && item.productId == product.id,
          );
          if (!isUnitAlreadyAdded) {
            results.add(product);
          }
        }
      }

      // 2️⃣ التحقق من العناصر الموجودة في الكارت
      if (widget.isEditMode && _cartItems.isNotEmpty) {
        for (final cartItem in _cartItems) {
          final product = cartItem.product;

          if ((!isBarcodeSearch && product!.name.contains(trimmedQuery)) ||
              (isBarcodeSearch &&
                  product != null &&
                  product.barcode != null &&
                  product.barcode!.isNotEmpty &&
                  product.barcode!.contains(trimmedQuery))) {
            if (!results.any(
              (item) =>
                  (item is Product && item.id == product.id) ||
                  (item is ProductUnit && item.productId == product.id),
            )) {
              if (cartItem.selectedUnit != null) {
                results.add(cartItem.selectedUnit!);
              } else {
                results.add(product);
              }
            }
          }
        }
      }

      // 3️⃣ البحث بالاسم لو النتائج فارغة أو إذا البحث نص
      if ((!isBarcodeSearch || results.isEmpty) && _searchType == 'product') {
        final productsByName = await _provider.searchProductsByName(
          trimmedQuery,
        );
        for (final product in productsByName) {
          if (!results.any(
            (item) =>
                (item is Product && item.id == product.id) ||
                (item is ProductUnit && item.productId == product.id),
          )) {
            results.add(product);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _showSearchResults = results.isNotEmpty;
        _isSearching = false;
      });
    } catch (e) {
      log('Error performing search: $e');
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _handleEnterPressed(String query) async {
    if (_isSearching) return;

    await _performSearch(query);

    if (_searchResults.isNotEmpty) {
      final firstResult = _searchResults.first;

      if (firstResult is ProductUnit) {
        final unit = firstResult;
        final product = await _provider.getProductById(unit.productId);
        if (product != null) {
          _addUnitFromSearch(unit, product);
          _clearSearchAfterAction();
        }
      } else if (firstResult is Product) {
        if (widget.isEditMode) {
          final existingItemIndex = _cartItems.indexWhere(
            (item) => item.product?.id == firstResult.id,
          );

          if (existingItemIndex != -1) {
            _updateQuantity(_cartItems[existingItemIndex], 1);
            _clearSearchAfterAction();
            return;
          }
        }

        _addProductFromSearch(firstResult);
        _clearSearchAfterAction();
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
    if (product.quantity <= 0) {
      _showOutOfStockDialog(product.name);
      return;
    }
    _addProductToCartDirectly(product);
    _clearSearchAfterAction();
  }

  Future<void> _addUnitFromSearch(ProductUnit unit, Product product) async {
    if (product.quantity <= 0) {
      _showOutOfStockDialog('${product.name} - ${unit.unitName}');
      return;
    }

    List<ProductUnit> allUnits = [];
    if (product.id != null) {
      allUnits = await _provider.getProductUnits(product.id!);
      allUnits = _removeDuplicateUnits(allUnits);
    }

    final existingItemIndex = _cartItems.indexWhere(
      (item) =>
          item.product?.id == product.id && item.selectedUnit?.id == unit.id,
    );

    if (existingItemIndex != -1) {
      _updateQuantity(_cartItems[existingItemIndex], 1);
    } else {
      ProductUnit? matchingUnit;
      for (var u in allUnits) {
        if (u.id == unit.id) {
          matchingUnit = u;
          break;
        }
      }

      matchingUnit ??= unit;

      setState(() {
        _cartItems.add(
          CartItem.product(
            product: product,
            quantity: 1,
            availableUnits: allUnits,
            selectedUnit: matchingUnit,
          ),
        );
        _calculateTotal();
      });
    }

    showAppToast(
      // ignore: use_build_context_synchronously
      context,
      'تم إضافة ${product.name} (${unit.unitName}) إلى السلة',
      ToastType.success,
    );
  }

  void _clearSearchAfterAction() {
    setState(() {
      _showSearchResults = false;
      _searchController.clear();
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _addProductToCartDirectly(Product product) async {
    try {
      List<ProductUnit> allUnits = [];
      if (product.id != null) {
        allUnits = await _provider.getProductUnits(product.id!);
        allUnits = _removeDuplicateUnits(allUnits);
      }

      if (widget.isEditMode && _originalSale != null) {
        final saleItems = await _provider.getSaleItems(_originalSale!.id);
        SaleItem? existingSaleItem;
        try {
          existingSaleItem = saleItems.firstWhere(
            (item) => item.productId == product.id,
          );
        } catch (e) {
          existingSaleItem = null;
        }

        ProductUnit? selectedUnitForEdit;

        if (existingSaleItem != null && existingSaleItem.unitId != null) {
          for (final unit in allUnits) {
            if (unit.id == existingSaleItem.unitId) {
              selectedUnitForEdit = unit;
              break;
            }
          }
        }

        final existingItemIndex = _cartItems.indexWhere(
          (item) =>
              item.product?.id == product.id &&
              item.selectedUnit?.id == selectedUnitForEdit?.id,
        );

        if (!mounted) return;
        setState(() {
          if (existingItemIndex != -1) {
            _cartItems[existingItemIndex].quantity += 1;
          } else {
            _cartItems.add(
              CartItem.product(
                product: product,
                quantity: 1,
                availableUnits: allUnits,
                selectedUnit: selectedUnitForEdit,
              ),
            );
          }
          _calculateTotal();
        });
      } else {
        // الحالة العادية (ليست وضع التعديل)
        final existingItemIndex = _cartItems.indexWhere(
          (item) => item.product?.id == product.id && item.selectedUnit == null,
        );

        if (!mounted) return;
        setState(() {
          if (existingItemIndex != -1) {
            _cartItems[existingItemIndex].quantity += 1;
          } else {
            _cartItems.add(
              CartItem.product(
                product: product,
                quantity: 1,
                availableUnits: allUnits,
                selectedUnit: null,
              ),
            );
          }
          _calculateTotal();
        });
      }

      if (!mounted) return;
      showAppToast(
        context,
        'تم إضافة ${product.name} إلى السلة',
        ToastType.success,
      );
    } catch (e) {
      log('Error adding product to cart: $e');
      if (!mounted) return;
      showAppToast(context, 'خطأ: $e', ToastType.error);
    }
  }

  List<ProductUnit> _removeDuplicateUnits(List<ProductUnit> units) {
    final seen = <int>{};
    return units.where((unit) {
      if (unit.id == null) return false;
      if (seen.contains(unit.id)) return false;
      seen.add(unit.id!);
      return true;
    }).toList();
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
              ..._cartItems.asMap().entries.map(
                (entry) => CartItemWidget(
                  key: ValueKey(
                    'cart_item_${entry.key}_${entry.value.product?.barcode}',
                  ),
                  item: entry.value,
                  onQuantityChange:
                      (item, change) => _updateQuantity(item, change),
                  onRemove: _removeFromCart,
                  onUnitChange: _updateSelectedUnit,
                  onPriceChange: _updateItemPrice,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAndButtons(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // عرض المجموع النهائي مع إمكانية التعديل
          GestureDetector(
            onTap: () => _showTotalEditor(context, settings),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color:
                    _isTotalModified
                        ? const Color(0xFFFFF8E1)
                        : const Color(0xFFF8F5FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _isTotalModified
                          ? Colors.orange
                          : const Color(0xFFE1D4F7),
                ),
              ),
              child: Column(
                children: [
                  if (_isTotalModified)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'مجموع العناصر:',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          '${settings.currencyName} ${_totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  if (_isTotalModified) const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isTotalModified
                            ? 'المجموع النهائي:'
                            : 'المجموع الكلي:',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${settings.currencyName} ${_finalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  _isTotalModified
                                      ? Colors.orange[800]
                                      : const Color(0xFF8B5FBF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.edit,
                            size: 18,
                            color: Color(0xFF6A3093),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isTotalModified)
                    const Text(
                      '(معدل)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              if (widget.isEditMode) ...[
                Expanded(
                  child: _buildActionButton(
                    'حفظ التعديلات',
                    Icons.save,
                    Colors.blue,
                    _completeReturnOrEdit,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _buildActionButton(
                  'البيع وطباعة الفاتورة',
                  Icons.check_circle,
                  const Color.fromARGB(255, 102, 76, 175),
                  _openReceiptPreview, // هنا التغيير
                ),
              ),
              if (!widget.isEditMode) ...[
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

  // دالة لعرض محرر المجموع الكلي
  void _showTotalEditor(BuildContext context, SettingsProvider settings) {
    _totalEditorController.text = _finalAmount.toStringAsFixed(2);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, color: Colors.blue),
                SizedBox(width: 8),
                Text('تعديل مجموع الفاتورة'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'مجموع العناصر: ${settings.currencyName} ${_totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _totalEditorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'المجموع الجديد',
                    suffixText: settings.currencyName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('مجموع العناصر'),
                        onPressed: () {
                          _totalEditorController.text = _totalAmount
                              .toStringAsFixed(2);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.money_off, size: 16),
                        label: const Text('مجاني'),
                        onPressed: () {
                          _totalEditorController.text = '0';
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final String value = _totalEditorController.text.trim();
                  if (value.isNotEmpty) {
                    double? newTotal = double.tryParse(value);
                    if (newTotal != null && newTotal >= 0) {
                      setState(() {
                        _finalAmount = newTotal;
                        _isTotalModified = (newTotal != _totalAmount);
                      });
                      Navigator.pop(context);

                      if (newTotal == 0) {
                        showAppToast(
                          context,
                          'تم تعيين الفاتورة إلى 0 (مجانية)',
                          ToastType.success,
                        );
                      } else if (newTotal != _totalAmount) {
                        showAppToast(
                          context,
                          'تم تعديل مجموع الفاتورة بنجاح',
                          ToastType.success,
                        );
                      }
                    } else {
                      showAppToast(
                        context,
                        'الرجاء إدخال رقم صالح',
                        ToastType.error,
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A3093),
                ),
                child: const Text(
                  'حفظ التغيير',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      double price = item.unitPrice;
      return sum + (price * item.quantity);
    });

    // إذا لم يتم تعديل المجموع النهائي يدويًا، يساوي مجموع العناصر
    if (!_isTotalModified) {
      _finalAmount = _totalAmount;
    }

    // مهم: إعادة رسم الشاشة بعد الحساب
    if (mounted) setState(() {});
  }

  // Update total when price changes

  void _updateQuantity(CartItem item, double change) {
    if (!mounted) return;
    setState(() {
      item.quantity += change;
      if (item.quantity <= 0) {
        _cartItems.remove(item);
      }
      _calculateTotal();
    });
  }

  void _updateItemPrice(CartItem item, double? newPrice) {
    if (!mounted) return;
    setState(() {
      item.setCustomPrice(newPrice);
      _calculateTotal();
    });
  }

  void _updateSelectedUnit(CartItem item, ProductUnit? unit) {
    if (!mounted) return;
    setState(() {
      item.selectedUnit = unit;
      // When the unit changes, fall back to that unit's default price.
      // This prevents the previous unit's price from sticking in edit mode.
      item.setCustomPrice(null);
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

  Future<void> _openReceiptPreview() async {
    if (_cartItems.isEmpty) {
      showAppToast(context, 'السلة فارغة', ToastType.warning);
      return;
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final logerIp = settings.logerIp;
    if (logerIp == null || logerIp.isEmpty) {
      showAppToast(
        context,
        'يرجى إعداد طابعة الفواتير في الإعدادات',
        ToastType.warning,
      );
      return;
    }

    // -------- PAYMENT POPUP --------
    final paymentResult = await _showPaymentDialog();
    if (paymentResult == null) return; // المستخدم ضغط إلغاء

    final double paidAmount = paymentResult['paid']!;
    final double changeAmount = paymentResult['change']!;
    final double dueAmount = paymentResult['due']!;

    // -------- GET CASHIER NAME --------
    final currentUser = auth.currentUser; // عدّل حسب AuthProvider عندك
    final cashierName = currentUser?['name'] ?? 'غير معروف';

    // -------- GET ADMIN PHONE --------
    final admins = await auth.getUsersByRole('admin');
    final phone = admins.isNotEmpty ? admins.first['phone'] : null;

    try {
      final marketName = settings.marketName ?? 'متجري';

      int? receiptNumber;
      if (widget.isEditMode && _originalSale != null) {
        receiptNumber = _originalSale!.id;
      }

      await ThermalReceiptloger.logReceipt(
        cartItems: _cartItems,
        marketName: marketName,
        adminPhone: phone,
        totalAmount: _totalAmount,
        finalAmount: _finalAmount,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
        dueAmount: dueAmount,
        cashierName: cashierName,
        isTotalModified: _isTotalModified,
        dateTime: DateTime.now(),
        receiptNumber: receiptNumber,
        currency: settings.currencyName,
        paperSize: settings.paperSize ?? '58mm',
        logerIp: logerIp,
        logerPort: settings.logerPort ?? 9100,
      );

      // ignore: use_build_context_synchronously
      showAppToast(context, 'تم إرسال الفاتورة إلى الطابعة', ToastType.success);
    } catch (e) {
      log('خطأ في الطباعة: $e');
      showAppToast(
        // ignore: use_build_context_synchronously
        context,
        'فشلت الطباعة - سيتم إتمام البيع',
        ToastType.warning,
      );
    }
    await Future.delayed(const Duration(seconds: 2));

    _completeSale();
  }

  // -------- PAYMENT DIALOG --------
  Future<Map<String, double>?> _showPaymentDialog() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currency = settings.currencyName;
    final TextEditingController paidController = TextEditingController();
    double changeAmount = 0;
    double dueAmount = 0;

    return showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            void calculate() {
              final paid = double.tryParse(paidController.text) ?? 0;
              if (paid >= _finalAmount) {
                changeAmount = paid - _finalAmount;
                dueAmount = 0;
              } else {
                changeAmount = 0;
                dueAmount = _finalAmount - paid;
              }
              setState(() {});
            }

            return AlertDialog(
              title: const Text('تفاصيل الدفع', textAlign: TextAlign.right),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // المجموع النهائي
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$currency ${_finalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                      const Text(
                        'المجموع النهائي:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // حقل المبلغ المدفوع
                  TextField(
                    controller: paidController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: 'المبلغ المدفوع ($currency)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                    onChanged: (_) => calculate(),
                    autofocus: true,
                  ),

                  const SizedBox(height: 12),

                  // الباقي للزبون
                  if (changeAmount > 0)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$currency ${changeAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text('الباقي للزبون:'),
                        ],
                      ),
                    ),

                  // المبلغ المستحق
                  if (dueAmount > 0)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$currency ${dueAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text('المبلغ المستحق:'),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      paidController.text.isEmpty
                          ? null
                          : () {
                            final paid =
                                double.tryParse(paidController.text) ?? 0;
                            Navigator.pop(ctx, {
                              'paid': paid,
                              'change': changeAmount,
                              'due': dueAmount,
                            });
                          },
                  icon: const Icon(Icons.print),
                  label: const Text('طباعة الفاتورة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _totalAmount = 0.0;
      _finalAmount = 0.0;
      _isTotalModified = false;
      _totalEditorController.clear();
    });
  }

  Future<void> _completeReturnOrEdit() async {
    if (_cartItems.isEmpty) {
      showAppToast(context, 'السلة فارغة', ToastType.warning);
      return;
    }

    final auth = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();

    try {
      // تحقق من أن جميع المنتجات لديها كمية كافية (باستثناء الخدمات)
      for (final item in _cartItems) {
        if (!item.isService && item.product != null) {
          final product = item.product!;
          final double requiredQty =
              item.selectedUnit != null
                  ? item.quantity * item.selectedUnit!.containQty
                  : item.quantity;

          if (product.quantity < requiredQty) {
            showAppToast(
              context,
              'الكمية غير كافية لـ ${product.name}',
              ToastType.error,
            );
            return;
          }
        }
      }

      if (widget.isEditMode) {
        await productProvider.updateSale(
          originalSale: _originalSale!,
          cartItems: _cartItems,
          totalAmount: _finalAmount,
          userRole: auth.role ?? 'user',
        );
      }

      if (mounted) {
        context.read<SalesProvider>().invalidateAndRefresh();

        showAppToast(context, 'تم تحديث الفاتورة بنجاح', ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'خطأ: $e', ToastType.warning);
      }
    }
  }

  void _completeSale() async {
    if (_cartItems.isEmpty) {
      showAppToast(context, 'السلة فارغة', ToastType.warning);
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final productProvider = context.read<ProductProvider>();

    try {
      // تحقق من أن جميع المنتجات لديها كمية كافية (باستثناء الخدمات)
      for (final item in _cartItems) {
        if (!item.isService && item.product != null) {
          final product = item.product!;
          final double requiredQty =
              item.selectedUnit != null
                  ? item.quantity * item.selectedUnit!.containQty
                  : item.quantity;
          if (product.quantity < requiredQty) {
            showAppToast(
              context,
              'الكمية غير كافية لـ ${product.name}',
              ToastType.error,
            );
            return;
          }
        }
      }

      await productProvider.addSale(
        cartItems: _cartItems,
        totalAmount: _finalAmount,
        paymentType: 'cash',
        customerId: null,
        userRole: auth.role ?? 'user',
        userId: user?["id"],
      );

      if (mounted) {
        context.read<SalesProvider>().invalidateAndRefresh();

        showAppToast(context, 'تم إتمام البيع بنجاح', ToastType.success);
        _clearCart();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage =
            e
                .toString()
                .replaceAll("Exception: ", "")
                .replaceAll("Bad state: ", "")
                .trim();

        showAppToast(context, 'خطأ: $errorMessage', ToastType.error);
      }
    }
  }

  void _recordDebtSale() async {
    if (_cartItems.isEmpty) {
      showAppToast(context, 'السلة فارغة', ToastType.warning);
      return;
    }

    final customerProvider = context.read<CustomerProvider>();

    customerProvider.clearSearch();
    await customerProvider.fetchCustomers(reset: true);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _buildCustomerSelectionDialog(),
    );
  }

  Widget _buildCustomerSelectionDialog() {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, child) {
        final customers = customerProvider.displayedCustomers;
        final isLoading = customerProvider.isLoading;
        final hasMore = customerProvider.hasMore;

        // متغير لمنع التحميل المتكرر
        bool isLoadingMore = false;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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

                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // استخدم ScrollUpdateNotification بدل ScrollEndNotification
                      if (notification is ScrollUpdateNotification) {
                        // تحقق إذا وصلنا لـ 90% من نهاية السكرول
                        if (notification.metrics.pixels >=
                                notification.metrics.maxScrollExtent * 0.9 &&
                            hasMore &&
                            !isLoading &&
                            !isLoadingMore) {
                          isLoadingMore = true;

                          // تحميل المزيد
                          customerProvider.loadMoreCustomers().then((_) {
                            // إعادة تعيين بعد تأخير قصير
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                isLoadingMore = false;
                              },
                            );
                          });
                        }
                      }
                      return false;
                    },
                    child:
                        customers.isEmpty && !isLoading
                            ? const Center(
                              child: Text(
                                'لا توجد عملاء',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    // نضيف loader إذا كان في hasMore
                                    itemCount:
                                        customers.length +
                                        (hasMore && customers.isNotEmpty
                                            ? 1
                                            : 0),
                                    itemBuilder: (context, index) {
                                      // إذا وصلنا لنهاية القائمة
                                      if (index == customers.length) {
                                        // نعرض loader فقط إذا كان في hasMore ولم يكن في تحميل
                                        if (hasMore && !isLoadingMore) {
                                          return const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        } else if (isLoadingMore) {
                                          // إذا كان في تحميل، نعرض loader مختلف أو نختفي
                                          return const SizedBox.shrink();
                                        } else {
                                          return const SizedBox.shrink();
                                        }
                                      }

                                      final customer = customers[index];
                                      return Material(
                                        color: Colors.transparent,
                                        child: ListTile(
                                          leading: const Icon(
                                            Icons.person,
                                            color: Color(0xFF8B5FBF),
                                          ),
                                          title: Text(customer.name),
                                          subtitle: Text(
                                            customer.phone ?? 'بدون رقم',
                                          ),
                                          onTap: () {
                                            Navigator.pop(context);
                                            // إغلاق الديلوج أولاً ثم الانتقال
                                            Future.delayed(
                                              const Duration(milliseconds: 100),
                                              () {
                                                _finalizeSaleWithCustomer(
                                                  customer,
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (isLoading && customers.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                              ],
                            ),
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
      },
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
              } catch (e) {
                if (mounted) {
                  showAppToast(
                    // ignore: use_build_context_synchronously
                    context,
                    'خطأ في إضافة العميل: $e',
                    ToastType.error,
                  );
                }
              }
            },
          ),
    );
  }

  Future<void> _finalizeSaleWithCustomer(Customer customer) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final productProvider = context.read<ProductProvider>();
    final debtProvider = context.read<DebtProvider>();
    final settings = context.read<SettingsProvider>();
    try {
      // تحقق من أن جميع المنتجات لديها كمية كافية (باستثناء الخدمات)
      for (final item in _cartItems) {
        if (!item.isService && item.product != null) {
          final product = item.product!;
          final double requiredQty =
              item.selectedUnit != null
                  ? item.quantity * item.selectedUnit!.containQty
                  : item.quantity;
          if (product.quantity < requiredQty) {
            showAppToast(
              context,
              'الكمية غير كافية لـ ${product.name}',
              ToastType.error,
            );
            return;
          }
        }
      }

      final double customerBalance = await debtProvider
          .getTotalDebtByCustomerId(customer.id!);
      final double availableCredit =
          customerBalance < 0 ? customerBalance.abs() : 0.0;
      final double appliedFromBalance =
          availableCredit > _finalAmount ? _finalAmount : availableCredit;
      final double remainingDebt = _finalAmount - appliedFromBalance;

      await productProvider.addSale(
        cartItems: _cartItems,
        totalAmount: _finalAmount,
        paymentType: remainingDebt > 0 ? 'credit' : 'cash',
        customerId: customer.id,
        paidAmount: appliedFromBalance > 0 ? appliedFromBalance : 0.0,
        remainingAmount: remainingDebt,
        userRole: auth.role ?? 'user',
        userId: user?["id"],
      );

      if (appliedFromBalance > 0) {
        await debtProvider.addWithdrawal(
          customerId: customer.id!,
          amount: appliedFromBalance,
          note:
              remainingDebt > 0
                  ? 'استخدام رصيد للفاتورة، والمتبقي دين بقيمة ${remainingDebt.toStringAsFixed(2)} ${settings.currencyName}'
                  : 'استخدام رصيد لتسديد كامل الفاتورة',
        );
      }

      if (mounted) {
        context.read<SalesProvider>().invalidateAndRefresh();

        showAppToast(
          context,
          'تم تسجيل بيع مؤجل للعميل ${customer.name} بنجاح',
          ToastType.success,
        );

        _clearCart();
      }
    } catch (e) {
      final errorMessage =
          e
              .toString()
              .replaceAll("Exception: ", "")
              .replaceAll("Bad state: ", "")
              .trim();

      if (mounted) {
        showAppToast(context, 'خطأ: $errorMessage', ToastType.error);
      }
    }
  }

  // دالة لإضافة خدمة جديدة
  void _addService() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.design_services, color: Colors.blue),
                SizedBox(width: 8),
                Text('إضافة خدمة جديدة'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخدمة',
                    hintText: 'أدخل اسم الخدمة',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'المبلغ',
                    hintText: '0.00',
                    suffixText: settings.currencyName,
                    border: const OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final String name = nameController.text.trim();
                  final String priceText = priceController.text.trim();

                  if (name.isEmpty) {
                    showAppToast(
                      context,
                      'الرجاء إدخال اسم الخدمة',
                      ToastType.error,
                    );
                    return;
                  }

                  if (priceText.isEmpty) {
                    showAppToast(
                      context,
                      'الرجاء إدخال المبلغ',
                      ToastType.error,
                    );
                    return;
                  }

                  double? price = double.tryParse(priceText);
                  if (price == null || price < 0) {
                    showAppToast(
                      context,
                      'الرجاء إدخال مبلغ صحيح',
                      ToastType.error,
                    );
                    return;
                  }

                  // إضافة الخدمة إلى السلة
                  final newServiceItem = CartItem.service(
                    serviceName: name,
                    price: price,
                  );

                  setState(() {
                    _cartItems.add(newServiceItem);
                    _calculateTotal();
                  });

                  Navigator.pop(context);
                  showAppToast(
                    context,
                    'تم إضافة الخدمة بنجاح',
                    ToastType.success,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                ),
                child: const Text(
                  'إضافة',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}
