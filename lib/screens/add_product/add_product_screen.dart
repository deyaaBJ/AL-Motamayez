import 'package:flutter/material.dart';
import 'package:motamayez/components/base_layout.dart';
import 'add_product_state.dart';
import 'widgets/desktop_layout.dart';
import 'widgets/tablet_layout.dart';

enum ScreenType { tablet, desktop }

class AddProductScreen extends StatefulWidget {
  final int? productId;
  const AddProductScreen({super.key, this.productId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  late AddProductState _state;

  @override
  void initState() {
    super.initState();
    _state = AddProductState(productId: widget.productId);
    // ⬅️ الاستماع إلى تغييرات _state
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    setState(() {
      // تحديث الـ UI عند تغير الـ state
    });
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'المنتجات',
        title: _state.isNewProduct ? 'إضافة منتج جديد' : 'تحديث المنتج',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenType =
                constraints.maxWidth < 1200
                    ? ScreenType.tablet
                    : ScreenType.desktop;
            final formData = {
              'nameController': _state.nameController,
              'priceController': _state.priceController,
              'offerPriceController': _state.offerPriceController,
              'costPriceController': _state.costPriceController,
              'quantityController': _state.quantityController,
              'barcodeController': _state.barcodeController,
              'lowStockThresholdController': _state.lowStockThresholdController,
              'selectedUnit': _state.selectedUnit,
              'isNewProduct': _state.isNewProduct,
              'existingProduct': _state.existingProduct,
              'existingQuantity':
                  (_state.existingProduct?.quantity ??
                      double.tryParse(_state.quantityController.text) ??
                      0.0),
              'offerEnabled': _state.offerEnabled,
              'offerStartDate': _state.offerStartDate,
              'offerEndDate': _state.offerEndDate,
              'isProductActive': _state.isProductActive,
              'hasExpiryDate': _state.hasExpiryDate,
              'useCustomLowStockThreshold': _state.useCustomLowStockThreshold,
              'showUnitsSection': _state.showUnitsSection,
              'unitControllers': _state.unitControllers,
              'unitIds': _state.unitIds,
              'isLoading': _state.isLoading,
              'onSave': () => _state.saveProduct(context),
              'onUnitChanged': _state.updateSelectedUnit,
              'onOfferEnabledChanged': _state.updateOfferEnabled,
              'onOfferStartDateChanged': _state.updateOfferStartDate,
              'onOfferEndDateChanged': _state.updateOfferEndDate,
              'onOfferClear': _state.clearOffer,
              'onActiveChanged': _state.updateProductActive,
              'onExpiryChanged': _state.updateHasExpiryDate,
              'onLowStockCheckboxChanged': _state.updateLowStockCheckbox,
              'onToggleUnits': _state.toggleUnitsSection,
              'onAddUnit': _state.addNewUnit,
              'onRemoveUnit': _state.removeUnit,
            };

            return SingleChildScrollView(
              // ✅ إضافة السكرول هنا
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child:
                  screenType == ScreenType.desktop
                      ? DesktopLayout(
                        qrController: _state.qrController,
                        onQRCodeChanged: _state.checkProduct,
                        formKey: _state.formKey,
                        formData: formData,
                      )
                      : TabletLayout(
                        qrController: _state.qrController,
                        onQRCodeChanged: _state.checkProduct,
                        formKey: _state.formKey,
                        formData: formData,
                      ),
            );
          },
        ),
      ),
    );
  }
}
