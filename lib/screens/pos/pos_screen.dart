import 'package:flutter/material.dart';
import 'package:motamayez/components/posPageCompoments/search_section.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/components/posPageComponents/search_section.dart';
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
import 'package:motamayez/providers/sales_provider.dart';
import 'package:motamayez/services/thermal_receipt_printer.dart';
import 'package:motamayez/screens/pos/components/pos_mode_banner.dart';
import 'package:motamayez/screens/pos/components/pos_search_results.dart';
import 'package:motamayez/screens/pos/components/pos_cart_table.dart';
import 'package:motamayez/screens/pos/components/pos_total_and_buttons.dart';
import 'package:motamayez/screens/pos/components/pos_payment_dialog.dart';
import 'package:motamayez/screens/pos/components/pos_customer_selection_dialog.dart';
import 'package:motamayez/screens/pos/components/pos_add_service_dialog.dart';
import 'package:motamayez/screens/pos/pos_helpers.dart';
import 'dart:developer';

// Extension to add firstWhereOrNull to Iterable
extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

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

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _totalEditorController = TextEditingController();

  // Data
  final List<CartItem> _cartItems = [];
  double _totalAmount = 0.0;
  double _finalAmount = 0.0;
  bool _isTotalModified = false;

  // Search state
  List<dynamic> _searchResults = [];
  bool _showSearchResults = false;
  final FocusNode _searchFocusNode = FocusNode();
  String _searchType = 'product';
  bool _isSearching = false;

  // Sale edit mode
  Sale? _originalSale;
  bool _isSaleLoaded = false;
  bool _isLoading = false;

  final ProductProvider _productProvider = ProductProvider();

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

  // ==================== تحميل فاتورة للتعديل ====================
  Future<void> _loadExistingSale(Sale sale) async {
    if (_isLoading || _isSaleLoaded) return;
    _isLoading = true;
    try {
      _originalSale = sale;
      final saleItems = await _productProvider.getSaleItems(sale.id);
      _cartItems.clear();
      for (final saleItem in saleItems) {
        if (saleItem.itemType == 'service' || saleItem.productId == null) {
          final serviceItem = CartItem.service(
            serviceName: saleItem.itemName,
            price: saleItem.price,
          );
          serviceItem.quantity = saleItem.quantity;
          serviceItem.setCustomPrice(saleItem.price);
          _cartItems.add(serviceItem);
        } else {
          final product = await _productProvider.getProductById(
            saleItem.productId!,
          );
          if (product != null) {
            final unitsRaw = await _productProvider.getProductUnits(
              product.id!,
            );
            final List<ProductUnit> units = unitsRaw.cast<ProductUnit>();
            final uniqueUnits = removeDuplicateUnits(units);
            ProductUnit? selectedUnit;
            if (saleItem.unitId != null) {
              selectedUnit = uniqueUnits.firstWhereOrNull(
                (u) => u.id == saleItem.unitId,
              );
            }
            final defaultPrice =
                selectedUnit?.effectivePrice ?? product.effectivePrice;
            final hasCustomPrice =
                (saleItem.price - defaultPrice).abs() > 0.0001;
            _cartItems.add(
              CartItem.product(
                product: product,
                quantity: saleItem.quantity,
                availableUnits: uniqueUnits,
                selectedUnit: selectedUnit,
                customPrice: hasCustomPrice ? saleItem.price : null,
              ),
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          _totalAmount = _cartItems.fold(
            0.0,
            (s, i) => s + (i.unitPrice * i.quantity),
          );
          _finalAmount = sale.totalAmount;
          _isTotalModified = (_finalAmount != _totalAmount);
          _isSaleLoaded = true;
        });
      }
    } catch (e) {
      log('خطأ بالتحميل: $e');
    } finally {
      _isLoading = false;
    }
  }

  // ==================== دوال البحث ====================
  Future<void> _performSearch(String query) async {
    if (_isSearching || query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final results = <dynamic>[];
      final trimmed = query.trim();
      final isBarcode = double.tryParse(trimmed) != null;
      if (isBarcode) {
        final unitsByBarcode = await _productProvider
            .searchProductUnitsByBarcode(trimmed);
        for (final unit in unitsByBarcode) {
          final product = await _productProvider.getProductById(unit.productId);
          if (product != null) results.add(unit);
        }
        final productsByBarcode = await _productProvider
            .searchProductsByBarcode(trimmed);
        for (final p in productsByBarcode) {
          if (!results.any((e) => e is ProductUnit && e.productId == p.id))
            results.add(p);
        }
      }
      if ((!isBarcode || results.isEmpty) && _searchType == 'product') {
        final productsByName = await _productProvider.searchProductsByName(
          trimmed,
        );
        for (final p in productsByName) {
          if (!results.any(
            (e) =>
                (e is Product && e.id == p.id) ||
                (e is ProductUnit && e.productId == p.id),
          )) {
            results.add(p);
          }
        }
      }
      if (mounted)
        setState(() {
          _searchResults = results;
          _showSearchResults = results.isNotEmpty;
          _isSearching = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _handleEnterPressed(String query) async {
    if (_isSearching) return;
    await _performSearch(query);
    if (_searchResults.isNotEmpty) {
      final first = _searchResults.first;
      if (first is ProductUnit) {
        final product = await _productProvider.getProductById(first.productId);
        if (product != null) _addUnitFromSearch(first, product);
      } else if (first is Product) {
        _addProductFromSearch(first);
      }
      _clearSearchAfterAction();
    }
  }

  void _clearSearch() => setState(() {
    _searchController.clear();
    _showSearchResults = false;
    _searchResults.clear();
    _searchFocusNode.requestFocus();
  });

  void _clearSearchAfterAction() => setState(() {
    _showSearchResults = false;
    _searchController.clear();
    _searchFocusNode.requestFocus();
  });

  // ==================== دوال إضافة المنتجات / الوحدات / الخدمات ====================
  Future<void> _addProductFromSearch(Product product) async {
    if (product.quantity <= 0) {
      _showOutOfStockDialog(product.name);
      return;
    }
    try {
      final unitsRaw =
          (product.id != null)
              ? await _productProvider.getProductUnits(product.id!)
              : [];
      final List<ProductUnit> units = unitsRaw.cast<ProductUnit>();
      final uniqueUnits = removeDuplicateUnits(units);

      if (widget.isEditMode && _originalSale != null) {
        final saleItems = await _productProvider.getSaleItems(
          _originalSale!.id,
        );
        final existingSaleItem = saleItems.firstWhereOrNull(
          (i) => i.productId == product.id,
        );
        ProductUnit? selectedUnit;
        if (existingSaleItem?.unitId != null) {
          selectedUnit = uniqueUnits.firstWhereOrNull(
            (u) => u.id == existingSaleItem!.unitId,
          );
        }
        final index = _cartItems.indexWhere(
          (i) =>
              i.product?.id == product.id &&
              i.selectedUnit?.id == selectedUnit?.id,
        );
        setState(() {
          if (index != -1) {
            _cartItems[index].quantity += 1;
          } else {
            _cartItems.add(
              CartItem.product(
                product: product,
                quantity: 1,
                availableUnits: uniqueUnits,
                selectedUnit: selectedUnit,
              ),
            );
          }
          _calculateTotal();
        });
      } else {
        final index = _cartItems.indexWhere(
          (i) => i.product?.id == product.id && i.selectedUnit == null,
        );
        setState(() {
          if (index != -1) {
            _cartItems[index].quantity += 1;
          } else {
            _cartItems.add(
              CartItem.product(
                product: product,
                quantity: 1,
                availableUnits: uniqueUnits,
                selectedUnit: null,
              ),
            );
          }
          _calculateTotal();
        });
      }
      showAppToast(context, 'تم إضافة ${product.name}', ToastType.success);
    } catch (e) {
      showAppToast(context, 'خطأ: $e', ToastType.error);
    }
  }

  Future<void> _addUnitFromSearch(ProductUnit unit, Product product) async {
    if (product.quantity <= 0) {
      _showOutOfStockDialog('${product.name} - ${unit.unitName}');
      return;
    }
    final unitsRaw =
        (product.id != null)
            ? await _productProvider.getProductUnits(product.id!)
            : [];
    final List<ProductUnit> allUnits = unitsRaw.cast<ProductUnit>();
    final uniqueUnits = removeDuplicateUnits(allUnits);

    final existingIndex = _cartItems.indexWhere(
      (i) => i.product?.id == product.id && i.selectedUnit?.id == unit.id,
    );
    setState(() {
      if (existingIndex != -1) {
        _cartItems[existingIndex].quantity += 1;
      } else {
        final matchingUnit =
            uniqueUnits.firstWhereOrNull((u) => u.id == unit.id) ?? unit;
        _cartItems.add(
          CartItem.product(
            product: product,
            quantity: 1,
            availableUnits: uniqueUnits,
            selectedUnit: matchingUnit,
          ),
        );
      }
      _calculateTotal();
    });
    showAppToast(
      context,
      'تم إضافة ${product.name} (${unit.unitName})',
      ToastType.success,
    );
  }

  void _addService() => showDialog(
    context: context,
    builder:
        (_) => PosAddServiceDialog(
          onAdd: (name, price) {
            setState(() {
              _cartItems.add(CartItem.service(serviceName: name, price: price));
              _calculateTotal();
            });
            showAppToast(context, 'تم إضافة الخدمة', ToastType.success);
          },
        ),
  );

  // ==================== دوال السلة والمجاميع ====================
  void _calculateTotal() {
    _totalAmount = _cartItems.fold(
      0.0,
      (s, i) => s + (i.unitPrice * i.quantity),
    );
    if (!_isTotalModified) _finalAmount = _totalAmount;
    if (mounted) setState(() {});
  }

  void _updateQuantity(CartItem item, double change) {
    setState(() {
      item.quantity += change;
      if (item.quantity <= 0) _cartItems.remove(item);
      _calculateTotal();
    });
  }

  void _updateItemPrice(CartItem item, double? newPrice) {
    setState(() {
      item.setCustomPrice(newPrice);
      _calculateTotal();
    });
  }

  void _updateSelectedUnit(CartItem item, ProductUnit? unit) {
    setState(() {
      item.selectedUnit = unit;
      item.setCustomPrice(null);
      _calculateTotal();
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() {
      _cartItems.remove(item);
      _calculateTotal();
    });
  }

  void _clearCart() => setState(() {
    _cartItems.clear();
    _totalAmount = 0.0;
    _finalAmount = 0.0;
    _isTotalModified = false;
    _totalEditorController.clear();
  });

  void _showOutOfStockDialog(String productName) => showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          title: const Text('الكمية نفدت'),
          content: Text('$productName غير متوفر.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسنًا'),
            ),
          ],
        ),
  );

  // ==================== البيع والطباعة والديون ====================
  Future<void> _openReceiptPreview() async {
    if (_cartItems.isEmpty) {
      showAppToast(context, 'السلة فارغة', ToastType.warning);
      return;
    }
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final logerIp = settings.logerIp;
    if (logerIp == null || logerIp.isEmpty) {
      showAppToast(context, 'يرجى إعداد الطابعة', ToastType.warning);
      return;
    }

    final payment = await showPaymentDialog(context, _finalAmount);
    if (payment == null) return;

    final cashierName = auth.currentUser?['name'] ?? 'غير معروف';
    final admins = await auth.getUsersByRole('admin');
    final phone = admins.isNotEmpty ? admins.first['phone'] : null;

    try {
      await ThermalReceiptloger.logReceipt(
        cartItems: _cartItems,
        marketName: settings.marketName ?? 'متجري',
        adminPhone: phone,
        totalAmount: _totalAmount,
        finalAmount: _finalAmount,
        paidAmount: payment['paid']!,
        changeAmount: payment['change']!,
        dueAmount: payment['due']!,
        cashierName: cashierName,
        isTotalModified: _isTotalModified,
        dateTime: DateTime.now(),
        receiptNumber: widget.isEditMode ? _originalSale?.id : null,
        currency: settings.currencyName,
        paperSize: settings.paperSize ?? '58mm',
        logerIp: logerIp,
        logerPort: settings.logerPort ?? 9100,
      );
      showAppToast(context, 'تم إرسال الفاتورة', ToastType.success);
    } catch (e) {
      showAppToast(context, 'فشلت الطباعة', ToastType.warning);
    }
    await Future.delayed(const Duration(seconds: 2));
    _completeSale();
  }

  Future<void> _completeSale() async {
    if (_cartItems.isEmpty) {
      showAppToast(context, 'السلة فارغة', ToastType.warning);
      return;
    }
    final auth = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();
    try {
      for (final item in _cartItems) {
        if (!item.isService && item.product != null) {
          final reqQty =
              item.selectedUnit != null
                  ? item.quantity * item.selectedUnit!.containQty
                  : item.quantity;
          if (item.product!.quantity < reqQty) {
            showAppToast(
              context,
              'كمية غير كافية لـ ${item.product!.name}',
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
        userId: auth.currentUser?["id"],
      );
      context.read<SalesProvider>().invalidateAndRefresh();
      showAppToast(context, 'تم إتمام البيع', ToastType.success);
      _clearCart();
    } catch (e) {
      showAppToast(context, 'خطأ: ${_cleanErrorMessage(e)}', ToastType.error);
    }
  }

  // ==================== البيع الآجل مع تأكيد ====================
  Future<void> _recordDebtSale() async {
    if (_cartItems.isEmpty) {
      showAppToast(context, 'السلة فارغة', ToastType.warning);
      return;
    }
    final customerProvider = context.read<CustomerProvider>();
    await customerProvider.fetchCustomers(reset: true);
    if (!mounted) return;
    final selectedCustomer = await showCustomerSelectionDialog(context);
    if (selectedCustomer == null) return; // المستخدم ألغى اختيار الزبون

    // نافذة تأكيد
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تأكيد البيع الآجل'),
            content: Text(
              'هل أنت متأكد من إتمام عملية البيع للزبون "${selectedCustomer.name}"؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('نعم، أكمل'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _finalizeSaleWithCustomer(selectedCustomer);
    }
  }

  Future<void> _finalizeSaleWithCustomer(Customer customer) async {
    final auth = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();
    final debtProvider = context.read<DebtProvider>();
    final settings = context.read<SettingsProvider>();
    try {
      for (final item in _cartItems) {
        if (!item.isService && item.product != null) {
          final reqQty =
              item.selectedUnit != null
                  ? item.quantity * item.selectedUnit!.containQty
                  : item.quantity;
          if (item.product!.quantity < reqQty) {
            showAppToast(
              context,
              'كمية غير كافية لـ ${item.product!.name}',
              ToastType.error,
            );
            return;
          }
        }
      }
      final balance = await debtProvider.getTotalDebtByCustomerId(customer.id!);
      final available = balance < 0 ? balance.abs() : 0.0;
      final applied = available > _finalAmount ? _finalAmount : available;
      final remaining = _finalAmount - applied;
      await productProvider.addSale(
        cartItems: _cartItems,
        totalAmount: _finalAmount,
        paymentType: remaining > 0 ? 'credit' : 'cash',
        customerId: customer.id,
        paidAmount: applied,
        remainingAmount: remaining,
        debtAddedInPeriod: remaining,
        userRole: auth.role ?? 'user',
        userId: auth.currentUser?["id"],
      );
      if (applied > 0) {
        await debtProvider.addWithdrawal(
          customerId: customer.id!,
          amount: applied,
          note:
              remaining > 0
                  ? 'استخدام رصيد للفاتورة، والمتبقي دين بقيمة $remaining'
                  : 'استخدام رصيد لتسديد كامل الفاتورة',
        );
      }
      context.read<SalesProvider>().invalidateAndRefresh();
      showAppToast(
        context,
        'تم تسجيل بيع مؤجل للزبون ${customer.name}',
        ToastType.success,
      );
      _clearCart();
    } catch (e) {
      showAppToast(context, 'خطأ: ${_cleanErrorMessage(e)}', ToastType.error);
    }
  }

  Future<void> _completeReturnOrEdit() async {
    if (_cartItems.isEmpty) {
      showAppToast(context, 'السلة فارغة', ToastType.warning);
      return;
    }
    final auth = context.read<AuthProvider>();
    final productProvider = context.read<ProductProvider>();
    try {
      for (final item in _cartItems) {
        if (!item.isService && item.product != null) {
          final reqQty =
              item.selectedUnit != null
                  ? item.quantity * item.selectedUnit!.containQty
                  : item.quantity;
          if (item.product!.quantity < reqQty) {
            showAppToast(
              context,
              'كمية غير كافية لـ ${item.product!.name}',
              ToastType.error,
            );
            return;
          }
        }
      }
      await productProvider.updateSale(
        originalSale: _originalSale!,
        cartItems: _cartItems,
        totalAmount: _finalAmount,
        userRole: auth.role ?? 'user',
      );
      context.read<SalesProvider>().invalidateAndRefresh();
      showAppToast(context, 'تم تحديث الفاتورة', ToastType.success);
      Navigator.pop(context);
    } catch (e) {
      showAppToast(context, 'خطأ: ${_cleanErrorMessage(e)}', ToastType.warning);
    }
  }

  String _cleanErrorMessage(dynamic e) =>
      e
          .toString()
          .replaceAll("Exception: ", "")
          .replaceAll("Bad state: ", "")
          .trim();

  void _showTotalEditor(BuildContext context) {
    _totalEditorController.text = _finalAmount.toStringAsFixed(2);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('تعديل مجموع الفاتورة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'مجموع العناصر: ${Provider.of<SettingsProvider>(context, listen: false).currencyName} $_totalAmount',
                ),
                TextField(
                  controller: _totalEditorController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المجموع الجديد',
                  ),
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
                  final newTotal = double.tryParse(_totalEditorController.text);
                  if (newTotal != null && newTotal >= 0) {
                    setState(() {
                      _finalAmount = newTotal;
                      _isTotalModified = (newTotal != _totalAmount);
                    });
                    Navigator.pop(context);
                  } else {
                    showAppToast(context, 'رقم غير صالح', ToastType.error);
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: '',
        floatingActionButton: null,
        child: Column(
          children: [
            if (widget.isEditMode) PosModeBanner(saleId: _originalSale?.id),
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
                    onChangeSearchType:
                        (type) => setState(() {
                          _searchType = type;
                          _searchController.clear();
                          _showSearchResults = false;
                          _searchResults.clear();
                        }),
                    addService: _addService,
                  ),
                ),
              ],
            ),
            if (_showSearchResults)
              PosSearchResults(
                results: _searchResults,
                onClear:
                    () => setState(() {
                      _showSearchResults = false;
                      _searchController.clear();
                    }),
                onProductTap: _addProductFromSearch,
                onUnitTap: _addUnitFromSearch,
              ),
            Expanded(
              child: PosCartTable(
                cartItems: _cartItems,
                onQuantityChange: _updateQuantity,
                onRemove: _removeFromCart,
                onUnitChange: _updateSelectedUnit,
                onPriceChange: _updateItemPrice,
              ),
            ),
            PosTotalAndButtons(
              totalAmount: _totalAmount,
              finalAmount: _finalAmount,
              isTotalModified: _isTotalModified,
              onEditTotal: () => _showTotalEditor(context),
              isEditMode: widget.isEditMode,
              onEditSave: _completeReturnOrEdit,
              onSaleAndPrint: _openReceiptPreview,
              onCompleteSale: _completeSale,
              onDeferredSale: _recordDebtSale,
              onClearCart: _clearCart,
              cartIsEmpty: _cartItems.isEmpty,
            ),
          ],
        ),
      ),
    );
  }
}
