import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/models/cart_item.dart';
import 'package:motamayez/models/product_unit.dart';
import 'package:motamayez/providers/settings_provider.dart';

class CartItemWidget extends StatefulWidget {
  final CartItem item;
  final Function(CartItem, double) onQuantityChange;
  final Function(CartItem) onRemove;
  final Function(CartItem, ProductUnit?) onUnitChange;
  final Function(CartItem, double?) onPriceChange;

  const CartItemWidget({
    super.key,
    required this.item,
    required this.onQuantityChange,
    required this.onRemove,
    required this.onUnitChange,
    required this.onPriceChange,
  });

  @override
  State<CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<CartItemWidget> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // اسم العنصر (منتج أو خدمة)
          Expanded(
            flex: 1,
            child: Text(
              widget.item.itemName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),

          // عرض نوع الوحدة (منتج أو خدمة)
          Expanded(flex: 2, child: _buildUnitOrServiceDisplay()),

          // السعر (قابل للنقر لتعديله)
          Expanded(flex: 1, child: _buildPriceDisplay(context, settings)),

          // الكمية (للمنتجات فقط - للخدمات ثابتة = 1)
          Expanded(
            flex: widget.item.isService ? 1 : 2,
            child:
                widget.item.isService
                    ? _buildServiceQuantityDisplay()
                    : _buildQuantityControls(),
          ),

          // المجموع
          Expanded(flex: 1, child: _buildTotalDisplay(settings)),

          // زر الحذف
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => widget.onRemove(widget.item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // دالة لعرض نوع الوحدة أو الخدمة
  Widget _buildUnitOrServiceDisplay() {
    if (widget.item.isService) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2196F3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.design_services,
              size: 16,
              color: Color(0xFF2196F3),
            ),
            const SizedBox(width: 6),
            Text(
              'خدمة',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2196F3),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // للمنتجات: عرض قائمة الوحدات
    return _buildUnitDropdown();
  }

  // دالة لعرض السعر
  Widget _buildPriceDisplay(BuildContext context, SettingsProvider settings) {
    final bool isPriceModified = _isPriceModified();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showPriceEditor(context, settings),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${settings.currencyName} ${widget.item.unitPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color:
                      widget.item.isService
                          ? const Color(0xFF2196F3)
                          : (isPriceModified
                              ? Colors.orange[800]
                              : const Color(0xFF8B5FBF)),
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.item.isService)
                const Text(
                  'سعر الخدمة',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة لعرض المجموع
  Widget _buildTotalDisplay(SettingsProvider settings) {
    final bool isPriceModified = _isPriceModified();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${settings.currencyName} ${widget.item.totalPrice.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color:
                widget.item.isService
                    ? const Color(0xFF2196F3)
                    : (isPriceModified
                        ? Colors.orange[800]
                        : const Color(0xFF6A3093)),
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.item.isService)
          const Text(
            'المجموع',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
      ],
    );
  }

  // دالة لعرض كمية الخدمة (ثابتة = 1)
  Widget _buildServiceQuantityDisplay() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2196F3)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.onetwothree, size: 20, color: Color(0xFF2196F3)),
          const SizedBox(height: 4),
          const Text(
            '1',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
          ),
          const Text(
            'كمية الخدمة',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // دالة للتحقق إذا كان السعر معدلاً (للمنتجات فقط)
  bool _isPriceModified() {
    if (widget.item.isService) {
      return false; // الخدمات لا يوجد لها سعر أصلي للتعديل
    }
    if (widget.item.selectedUnit != null) {
      return widget.item.unitPrice != widget.item.selectedUnit!.sellPrice;
    }
    return widget.item.unitPrice != widget.item.product!.price;
  }

  // دالة للحصول على السعر الأصلي (للمنتجات فقط)
  double _getOriginalPrice() {
    if (widget.item.isService) {
      return widget.item.unitPrice; // للخدمات، السعر الحالي هو السعر الوحيد
    }
    if (widget.item.selectedUnit != null) {
      return widget.item.selectedUnit!.sellPrice;
    }
    return widget.item.product!.price;
  }

  // دالة لعرض محرر السعر
  void _showPriceEditor(BuildContext context, SettingsProvider settings) {
    final originalPrice = _getOriginalPrice();
    final TextEditingController controller = TextEditingController(
      text: widget.item.unitPrice.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  widget.item.isService
                      ? 'تعديل سعر الخدمة'
                      : 'تعديل سعر المنتج',
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.item.itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (!widget.item.isService)
                  Text(
                    'السعر الأصلي: ${settings.currencyName} ${originalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                if (widget.item.isService)
                  const Text(
                    'الخدمة: يمكن تعديل سعرها فقط',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  autofocus: true,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText:
                        widget.item.isService ? 'سعر الخدمة' : 'السعر الجديد',
                    hintText: '0.00',
                    suffixText: settings.currencyName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!widget.item.isService)
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.restore, size: 16),
                          label: const Text('السعر الأصلي'),
                          onPressed: () {
                            controller.text = originalPrice.toStringAsFixed(2);
                          },
                        ),
                      ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.money_off, size: 16),
                        label: const Text('مجاني'),
                        onPressed: () {
                          controller.text = '0';
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
                  final String value = controller.text.trim();
                  if (value.isNotEmpty) {
                    double? newPrice = double.tryParse(value);
                    if (newPrice != null && newPrice >= 0) {
                      widget.onPriceChange(widget.item, newPrice);
                      Navigator.pop(context);

                      if (newPrice == 0) {
                        showAppToast(
                          context,
                          'تم تعيين السعر إلى 0 (مجاني)',
                          ToastType.warning,
                        );
                      } else if (!widget.item.isService &&
                          newPrice != originalPrice) {
                        showAppToast(
                          context,
                          'تم تعديل السعر بنجاح',
                          ToastType.success,
                        );
                      } else if (widget.item.isService) {
                        showAppToast(
                          context,
                          'تم تعديل سعر الخدمة بنجاح',
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
                  backgroundColor:
                      widget.item.isService
                          ? const Color(0xFF2196F3)
                          : const Color(0xFF6A3093),
                ),
                child: Text(
                  widget.item.isService ? 'حفظ سعر الخدمة' : 'حفظ التغيير',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildUnitDropdown() {
    final List<DropdownMenuItem<ProductUnit?>> items = [];

    // الخيار الأساسي (الوحدة الأساسية)
    items.add(
      DropdownMenuItem<ProductUnit?>(
        value: null,
        child: Row(
          children: [
            const Icon(Icons.barcode_reader, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _getBaseUnitDisplayName(widget.item.product!.baseUnit),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    // الوحدات الإضافية
    final addedUnitIds = <int>{};
    for (final unit in widget.item.availableUnits) {
      if (unit.id != null && !addedUnitIds.contains(unit.id)) {
        items.add(
          DropdownMenuItem<ProductUnit?>(
            value: unit,
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2,
                  size: 16,
                  color: Color(0xFF2196F3),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${unit.unitName} (${unit.containQty.toStringAsFixed(2)} ${_getBaseUnitDisplayName(widget.item.product!.baseUnit)})',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
        addedUnitIds.add(unit.id!);
      }
    }

    // إذا لم يكن هناك وحدات إضافية
    if (items.length == 1) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1D4F7)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.barcode_reader, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              _getBaseUnitDisplayName(widget.item.product!.baseUnit),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1D4F7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductUnit?>(
          value: widget.item.selectedUnit,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6A3093)),
          items: items,
          onChanged: (ProductUnit? newUnit) {
            widget.onUnitChange(widget.item, newUnit);
          },
          selectedItemBuilder: (context) {
            return items.map<Widget>((item) {
              final isBaseUnit = item.value == null;
              final unit = item.value;
              return Container(
                alignment: Alignment.centerRight,
                child: Row(
                  children: [
                    Icon(
                      isBaseUnit ? Icons.barcode_reader : Icons.inventory_2,
                      size: 16,
                      color: isBaseUnit ? Colors.grey : const Color(0xFF2196F3),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isBaseUnit
                            ? _getBaseUnitDisplayName(
                              widget.item.product!.baseUnit,
                            )
                            : '${unit!.unitName} (${unit.containQty.toStringAsFixed(2)} ${_getBaseUnitDisplayName(widget.item.product!.baseUnit)})',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildQuantityControls() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE1D4F7), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // زر الناقص
              IconButton(
                icon: const Icon(Icons.remove, size: 28),
                onPressed: () => widget.onQuantityChange(widget.item, -1),
                padding: const EdgeInsets.all(6),
                color: const Color(0xFF6A3093),
                iconSize: 28,
              ),

              // عرض الكمية
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      _formatQuantityForDisplay(widget.item.quantity),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: _getQuantityColor(widget.item.quantity),
                      ),
                    ),
                    Text(
                      _getQuantitySuffix(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // زر الزائد
              IconButton(
                icon: const Icon(Icons.add, size: 28),
                onPressed: () => widget.onQuantityChange(widget.item, 1),
                padding: const EdgeInsets.all(6),
                color: const Color(0xFF6A3093),
                iconSize: 28,
              ),
            ],
          ),
        ),

        // زر لإدخال كمية مخصصة
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _showCustomQuantityInput,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit, size: 16, color: Colors.black),
                SizedBox(width: 4),
                Text(
                  'إدخال كمية',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCustomQuantityInput() {
    final TextEditingController controller = TextEditingController(
      text: _formatQuantityForInput(widget.item.quantity),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('إدخال الكمية'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  autofocus: true,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'أدخل الكمية',
                    suffixText: _getQuantitySuffix(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'الوحدة: ${_getQuantitySuffix()}',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 19, 18, 18),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () {
                  final String value = controller.text.trim();
                  if (value.isNotEmpty) {
                    double? newQuantity = double.tryParse(value);

                    if (newQuantity != null && newQuantity > 0) {
                      final double difference =
                          newQuantity - widget.item.quantity;

                      if (difference != 0) {
                        widget.onQuantityChange(widget.item, difference);
                      }
                      Navigator.pop(context);
                    } else {
                      showAppToast(
                        context,
                        'الرجاء إدخال رقم موجب صالح',
                        ToastType.error,
                      );
                    }
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
    );
  }

  // دالة للحصول على اسم الوحدة المعروض
  String _getBaseUnitDisplayName(String baseUnit) {
    switch (baseUnit.toLowerCase()) {
      case 'piece':
      case 'قطعة':
        return 'قطعة';
      case 'kg':
      case 'كيلو':
        return 'كيلو';
      default:
        return baseUnit;
    }
  }

  // دالة للحصول على اللاحقة المناسبة للكمية
  String _getQuantitySuffix() {
    if (widget.item.isService) {
      return 'خدمة';
    }
    if (widget.item.selectedUnit != null) {
      return widget.item.selectedUnit!.unitName;
    } else {
      return _getBaseUnitDisplayName(widget.item.product!.baseUnit);
    }
  }

  // دالة لتنسيق الكمية للعرض
  String _formatQuantityForDisplay(double quantity) {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    } else {
      final String formatted = quantity.toStringAsFixed(2);
      if (formatted.endsWith('.00')) {
        return quantity.toInt().toString();
      } else if (formatted.endsWith('0')) {
        return quantity.toStringAsFixed(1);
      }
      return formatted;
    }
  }

  // دالة لتنسيق الكمية للإدخال
  String _formatQuantityForInput(double quantity) {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    } else {
      return quantity.toString();
    }
  }

  // دالة لتحديد لون الكمية
  Color _getQuantityColor(double quantity) {
    if (quantity == 0) {
      return Colors.red;
    } else if (quantity < 1) {
      return Colors.orange;
    } else if (quantity < 5) {
      if (quantity % 1 != 0) {
        return Colors.orange;
      }
      return Colors.amber[700]!;
    } else {
      if (quantity % 1 != 0) {
        return Colors.orange;
      }
      return const Color(0xFF6A3093);
    }
  }
}
