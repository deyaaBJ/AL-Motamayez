import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/models/product_unit.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/utils/formatters.dart';
import 'controllers/unit_controller.dart';
import 'helpers/date_helper.dart';
import 'helpers/offer_helper.dart';

class AddProductState extends ChangeNotifier {
  final ProductProvider _provider = ProductProvider();
  bool _disposed = false;
  Timer? _barcodeDebounce;
  bool _isApplyingProductData = false;

  final TextEditingController qrController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController offerPriceController = TextEditingController();
  final TextEditingController costPriceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController originalQuantityController =
      TextEditingController();
  final TextEditingController lowStockThresholdController =
      TextEditingController();

  DateTime? offerStartDate;
  DateTime? offerEndDate;
  bool offerEnabled = false;
  bool isProductActive = true;
  bool hasExpiryDate = false;
  bool useCustomLowStockThreshold = false;
  List<UnitController> unitControllers = [];
  List<int> unitIds = [];
  Product? existingProduct;
  bool isLoading = false;
  bool isNewProduct = true;
  String selectedUnit = 'piece';
  bool showUnitsSection = false;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  AddProductState({int? productId}) {
    if (productId != null) loadProductById(productId);
    qrController.addListener(_onQrChanged);
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _onQrChanged() {
    if (qrController.text.isEmpty && isNewProduct) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (barcodeController.text.isNotEmpty) barcodeController.clear();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _barcodeDebounce?.cancel();
    qrController.dispose();
    nameController.dispose();
    priceController.dispose();
    offerPriceController.dispose();
    costPriceController.dispose();
    quantityController.dispose();
    barcodeController.dispose();
    originalQuantityController.dispose();
    lowStockThresholdController.dispose();
    for (var c in unitControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> loadProductById(int productId) async {
    if (_disposed) return;
    isLoading = true;
    notifyListeners();
    try {
      final product = await _provider.getProductById(productId);
      if (_disposed) return;
      if (product != null) {
        _applyProductData(product);
        await _loadExistingUnits();
      } else {
        resetForm();
      }
    } catch (e) {
      log('Error loading product: $e');
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> checkProduct(String qrCode) async {
    if (_disposed) return;
    if (qrCode.trim().isEmpty) return;
    isLoading = true;
    notifyListeners();
    try {
      final results = await _provider.searchProductsByBarcode(qrCode);
      if (_disposed) return;
      if (results.isNotEmpty) {
        _applyProductData(results.first);
        await _loadExistingUnits();
      } else {
        resetForm();
        _setControllerText(barcodeController, qrCode);
      }
    } catch (e) {
      log('Error searching product: $e');
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void _applyProductData(Product product) {
    _isApplyingProductData = true;
    existingProduct = product;
    isNewProduct = false;
    _setControllerText(nameController, product.name);
    _setControllerText(priceController, product.price.toStringAsFixed(2));
    _setControllerText(
      costPriceController,
      product.costPrice.toStringAsFixed(2),
    );
    _setControllerText(quantityController, '0');
    _setControllerText(
      originalQuantityController,
      Formatters.formatQuantity(product.quantity),
    );
    _setControllerText(barcodeController, product.barcode ?? '');
    selectedUnit = product.baseUnit;
    offerEnabled = product.offerEnabled;
    _setControllerText(offerPriceController, product.offerPrice?.toString() ?? '');
    offerStartDate = parseStoredDate(product.offerStartDate);
    offerEndDate = parseStoredDate(product.offerEndDate);
    isProductActive = product.active;
    hasExpiryDate = product.hasExpiryDate;
    useCustomLowStockThreshold = product.lowStockThreshold != null;
    _setControllerText(
      lowStockThresholdController,
      product.lowStockThreshold?.toString() ?? '',
    );
    _isApplyingProductData = false;
  }

  void onBarcodeChanged(String value) {
    if (_disposed || _isApplyingProductData) return;

    final trimmedValue = value.trim();
    _barcodeDebounce?.cancel();

    if (existingProduct != null &&
        trimmedValue != (existingProduct!.barcode ?? '').trim()) {
      _clearProductState(keepBarcode: true);
      notifyListeners();
    }

    if (trimmedValue.isEmpty) {
      return;
    }

    _barcodeDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (_disposed || _isApplyingProductData) return;
      await checkProduct(trimmedValue);
    });
  }

  Future<void> _loadExistingUnits() async {
    if (_disposed) return;
    if (existingProduct?.id == null) return;
    try {
      final units = await _provider.getProductUnits(existingProduct!.id!);
      if (_disposed) return;
      unitControllers.clear();
      unitIds.clear();
      for (final unit in units) {
        final controller = UnitController();
        _setControllerText(controller.unitNameController, unit.unitName);
        _setControllerText(controller.barcodeController, unit.barcode ?? '');
        _setControllerText(
          controller.containQtyController,
          unit.containQty.toString(),
        );
        _setControllerText(
          controller.sellPriceController,
          unit.sellPrice.toString(),
        );
        _setControllerText(
          controller.offerPriceController,
          unit.offerPrice?.toString() ?? '',
        );
        controller.offerEnabled = unit.offerEnabled;
        controller.offerStartDate = parseStoredDate(unit.offerStartDate);
        controller.offerEndDate = parseStoredDate(unit.offerEndDate);

        unitControllers.add(controller);
        unitIds.add(unit.id!);
      }
      if (units.isNotEmpty) showUnitsSection = true;
      notifyListeners();
    } catch (e) {
      log("");
    }
  }

  void resetForm() {
    if (_disposed) return;
    _clearProductState();
    notifyListeners();
  }

  void _clearProductState({bool keepBarcode = false}) {
    if (_disposed) return;
    nameController.clear();
    priceController.clear();
    offerPriceController.clear();
    costPriceController.clear();
    quantityController.text = '0';
    selectedUnit = 'piece';
    showUnitsSection = false;
    unitControllers.clear();
    unitIds.clear();
    if (!keepBarcode) {
      barcodeController.clear();
    }
    offerStartDate = null;
    offerEndDate = null;
    offerEnabled = false;
    useCustomLowStockThreshold = false;
    lowStockThresholdController.clear();
    isProductActive = true;
    hasExpiryDate = false;
    existingProduct = null;
    isNewProduct = true;
  }

  Future<void> saveProduct(BuildContext context) async {
    if (_disposed) return;
    if (!formKey.currentState!.validate()) {
      showAppToast(context, 'يرجى تصحيح الأخطاء في النموذج', ToastType.error);
      return;
    }

    final double finalQuantity =
        existingProduct?.quantity ??
        double.tryParse(quantityController.text) ??
        0.0;

    if (nameController.text.isEmpty) {
      showAppToast(context, 'يرجى إدخال اسم المنتج', ToastType.error);
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      final offerData = buildOfferData(
        enabled: offerEnabled,
        priceText: offerPriceController.text,
        startDate: offerStartDate,
        endDate: offerEndDate,
        regularPrice: double.tryParse(priceController.text) ?? 0.0,
      );
      final customLowStockThreshold =
          useCustomLowStockThreshold
              ? int.tryParse(lowStockThresholdController.text.trim())
              : null;

      if (isNewProduct) {
        final product = Product(
          name: nameController.text,
          barcode: barcodeController.text,
          baseUnit: selectedUnit,
          price: double.tryParse(priceController.text) ?? 0.0,
          offerPrice: offerData.offerPrice,
          offerStartDate: offerData.offerStartDate,
          offerEndDate: offerData.offerEndDate,
          offerEnabled: offerData.offerEnabled,
          quantity: 0,
          costPrice: double.tryParse(costPriceController.text) ?? 0.0,
          active: isProductActive,
          hasExpiryDate: hasExpiryDate,
          lowStockThreshold: customLowStockThreshold,
        );
        final newProductId = await _provider.addProduct(product);
        try {
          if (showUnitsSection) {
            await _saveProductUnits(newProductId);
          }
        } catch (e) {
          log('Could not save product units: $e');
        }
      } else {
        if (existingProduct?.id == null) {
          throw Exception('لا يمكن تحديث منتج بدون ID');
        }
        final product = Product(
          id: existingProduct!.id,
          name: nameController.text,
          barcode: barcodeController.text,
          baseUnit: selectedUnit,
          price: double.tryParse(priceController.text) ?? 0.0,
          offerPrice: offerData.offerPrice,
          offerStartDate: offerData.offerStartDate,
          offerEndDate: offerData.offerEndDate,
          offerEnabled: offerData.offerEnabled,
          quantity: finalQuantity,
          costPrice: double.tryParse(costPriceController.text) ?? 0.0,
          addedDate: existingProduct?.addedDate,
          active: isProductActive,
          hasExpiryDate: hasExpiryDate,
          lowStockThreshold: customLowStockThreshold,
        );
        await _provider.updateProduct(product);
        if (showUnitsSection && existingProduct!.id != null) {
          await _saveProductUnits(existingProduct!.id!);
        }
      }

      if (!_disposed) {
        isLoading = false;
        notifyListeners();
        showAppToast(
          // ignore: use_build_context_synchronously
          context,
          isNewProduct ? 'تم إضافة المنتج بنجاح' : 'تم تحديث المنتج بنجاح',
          ToastType.success,
        );
        await Future.delayed(const Duration(seconds: 1));
        // ignore: use_build_context_synchronously
        if (!_disposed) Navigator.pop(context, true);
      }
    } catch (e) {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
        // ignore: use_build_context_synchronously
        showAppToast(context, 'حدث خطأ: $e', ToastType.error);
      }
      log('Error saving product: $e');
    }
  }

  Future<void> _saveProductUnits(int productId) async {
    if (_disposed) return;
    try {
      List<ProductUnit> existingUnits = [];
      try {
        existingUnits = await _provider.getProductUnits(productId);
      } catch (e) {
        log('Could not load existing units: $e');
      }
      for (int i = 0; i < unitControllers.length; i++) {
        final controller = unitControllers[i];
        final unitId = unitIds[i];
        final unitName = controller.unitNameController.text.trim();
        final barcode = controller.barcodeController.text.trim();
        final factor = double.tryParse(
          controller.containQtyController.text.trim(),
        );
        final sellPrice =
            double.tryParse(controller.sellPriceController.text.trim()) ?? 0.0;
        if (unitName.isEmpty || factor == null || factor <= 0) {
          continue;
        }
        final offerData = buildOfferData(
          enabled: controller.offerEnabled,
          priceText: controller.offerPriceController.text,
          startDate: controller.offerStartDate,
          endDate: controller.offerEndDate,
          regularPrice: sellPrice,
        );
        final unit = ProductUnit(
          id: unitId != -1 ? unitId : null,
          productId: productId,
          unitName: unitName,
          barcode: barcode.isNotEmpty ? barcode : null,
          containQty: factor,
          sellPrice: sellPrice,
          offerPrice: offerData.offerPrice,
          offerStartDate: offerData.offerStartDate,
          offerEndDate: offerData.offerEndDate,
          offerEnabled: offerData.offerEnabled,
        );
        if (unitId == -1) {
          await _provider.addProductUnit(unit);
        } else {
          await _provider.updateProductUnit(unit);
        }
      }
      final currentUnitIds = unitIds.where((id) => id != -1).toList();
      for (final existingUnit in existingUnits) {
        if (existingUnit.id != null &&
            !currentUnitIds.contains(existingUnit.id)) {
          await _provider.deleteProductUnit(existingUnit.id!);
        }
      }
    } catch (e) {
      log('Error saving units: $e');
      rethrow;
    }
  }

  void addNewUnit() {
    if (_disposed) return;
    unitControllers.add(UnitController());
    unitIds.add(-1);
    notifyListeners();
  }

  void removeUnit(int index) {
    if (_disposed) return;
    unitControllers.removeAt(index);
    unitIds.removeAt(index);
    notifyListeners();
  }

  void toggleUnitsSection() {
    if (_disposed) return;
    showUnitsSection = !showUnitsSection;
    if (showUnitsSection && unitControllers.isEmpty) addNewUnit();
    notifyListeners();
  }

  void updateSelectedUnit(String? value) {
    if (_disposed) return;
    if (value != null) selectedUnit = value;
    notifyListeners();
  }

  void updateOfferEnabled(bool value) {
    if (_disposed) return;
    offerEnabled = value;
    if (value && offerStartDate == null) offerStartDate = today();
    notifyListeners();
  }

  void updateOfferStartDate(DateTime? date) {
    if (_disposed) return;
    offerStartDate = date;
    if (offerEndDate == null && date != null) offerEndDate = date;
    notifyListeners();
  }

  void updateOfferEndDate(DateTime? date) {
    if (_disposed) return;
    offerEndDate = date;
    notifyListeners();
  }

  void clearOffer() {
    if (_disposed) return;
    offerEnabled = false;
    offerPriceController.clear();
    offerStartDate = null;
    offerEndDate = null;
    notifyListeners();
  }

  void updateProductActive(bool value) {
    if (_disposed) return;
    isProductActive = value;
    notifyListeners();
  }

  void updateHasExpiryDate(bool value) {
    if (_disposed) return;
    hasExpiryDate = value;
    notifyListeners();
  }

  void updateLowStockCheckbox(bool? value) {
    if (_disposed) return;
    useCustomLowStockThreshold = value ?? false;
    if (!useCustomLowStockThreshold) lowStockThresholdController.clear();
    notifyListeners();
  }
}
