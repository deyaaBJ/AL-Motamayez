import 'package:flutter/material.dart';
import '../../../../widgets/existing_product_message.dart';
import 'product_name_field.dart';
import 'product_barcode_field.dart';
import 'price_field.dart';
import 'cost_price_field.dart';
import 'unit_dropdown.dart';
import 'offer_section.dart';
import 'switches_section.dart';
import 'low_stock_threshold_section.dart';
import 'units_section.dart';

class ProductInfoSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final Map<String, dynamic> formData;
  final String screenType;

  const ProductInfoSection({
    super.key,
    required this.formKey,
    required this.formData,
    required this.screenType,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = screenType == 'desktop';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (formData['existingProduct'] != null) ...[
                ExistingProductMessage(
                  existingProduct: formData['existingProduct'],
                ),
                const SizedBox(height: 20),
              ],
              if (isDesktop) _buildDesktopForm() else _buildTabletForm(),
              const SizedBox(height: 24),
              SwitchesSection(
                isProductActive: formData['isProductActive'],
                hasExpiryDate: formData['hasExpiryDate'],
                onActiveChanged: formData['onActiveChanged'],
                onExpiryChanged: formData['onExpiryChanged'],
              ),
              const SizedBox(height: 16),
              LowStockThresholdSection(
                useCustomLowStockThreshold:
                    formData['useCustomLowStockThreshold'],
                lowStockThresholdController:
                    formData['lowStockThresholdController'],
                onCheckboxChanged: formData['onLowStockCheckboxChanged'],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopForm() {
    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 200,
              child: ProductBarcodeField(
                controller: formData['barcodeController'],
                readOnly: false,
                onChanged: formData['onBarcodeChanged'],
              ),
            ),
            SizedBox(
              width: 300,
              child: ProductNameField(controller: formData['nameController']),
            ),
            SizedBox(
              width: 200,
              child: UnitDropdown(
                selectedUnit: formData['selectedUnit'],
                onChanged: formData['onUnitChanged'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 250,
              child: PriceField(
                controller: formData['priceController'],
                label: 'سعر بيع الوحدة المرجعية',
              ),
            ),
            SizedBox(
              width: 250,
              child: CostPriceField(
                controller: formData['costPriceController'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OfferSection(
          offerEnabled: formData['offerEnabled'],
          offerPriceController: formData['offerPriceController'],
          offerStartDate: formData['offerStartDate'],
          offerEndDate: formData['offerEndDate'],
          onEnabledChanged: formData['onOfferEnabledChanged'],
          onStartDateChanged: formData['onOfferStartDateChanged'],
          onEndDateChanged: formData['onOfferEndDateChanged'],
          onClear: formData['onOfferClear'],
        ),
        const SizedBox(height: 16),
        _buildOpeningBalanceHint(),
        const SizedBox(height: 16),
        UnitsSection(
          showUnitsSection: formData['showUnitsSection'],
          unitControllers: formData['unitControllers'],
          unitIds: formData['unitIds'],
          onToggleShow: formData['onToggleUnits'],
          onAddUnit: formData['onAddUnit'],
          onRemoveUnit: formData['onRemoveUnit'],
          totalQuantity: (formData['existingQuantity'] ?? 0.0),
          baseUnit: formData['selectedUnit'],
        ),
      ],
    );
  }

  Widget _buildTabletForm() {
    return Column(
      children: [
        ProductBarcodeField(
          controller: formData['barcodeController'],
          readOnly: false,
          onChanged: formData['onBarcodeChanged'],
        ),
        const SizedBox(height: 16),
        ProductNameField(controller: formData['nameController']),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: UnitDropdown(
                selectedUnit: formData['selectedUnit'],
                onChanged: formData['onUnitChanged'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PriceField(
                controller: formData['priceController'],
                label: 'سعر بيع الوحدة المرجعية',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CostPriceField(
                controller: formData['costPriceController'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OfferSection(
          offerEnabled: formData['offerEnabled'],
          offerPriceController: formData['offerPriceController'],
          offerStartDate: formData['offerStartDate'],
          offerEndDate: formData['offerEndDate'],
          onEnabledChanged: formData['onOfferEnabledChanged'],
          onStartDateChanged: formData['onOfferStartDateChanged'],
          onEndDateChanged: formData['onOfferEndDateChanged'],
          onClear: formData['onOfferClear'],
        ),
        const SizedBox(height: 16),
        _buildOpeningBalanceHint(),
        const SizedBox(height: 16),
        UnitsSection(
          showUnitsSection: formData['showUnitsSection'],
          unitControllers: formData['unitControllers'],
          unitIds: formData['unitIds'],
          onToggleShow: formData['onToggleUnits'],
          onAddUnit: formData['onAddUnit'],
          onRemoveUnit: formData['onRemoveUnit'],
          totalQuantity: (formData['existingQuantity'] ?? 0.0),
          baseUnit: formData['selectedUnit'],
        ),
      ],
    );
  }

  Widget _buildOpeningBalanceHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD79A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFB7791F)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'إضافة الكمية لم تعد من شاشة المنتج. استخدم شاشة الرصيد الافتتاحي لتسجيل أي مخزون حالي بشكل رسمي.',
              style: TextStyle(
                color: Color(0xFF8A5A12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
