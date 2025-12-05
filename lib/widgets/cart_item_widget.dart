import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/helpers/helpers.dart';
import 'package:shopmate/models/cart_item.dart';
import 'package:shopmate/models/product_unit.dart';
import 'package:shopmate/providers/settings_provider.dart';

class CartItemWidget extends StatefulWidget {
  final CartItem item;
  final Function(CartItem, double) onQuantityChange;
  final Function(CartItem) onRemove;
  final Function(CartItem, ProductUnit?) onUnitChange;

  const CartItemWidget({
    super.key,
    required this.item,
    required this.onQuantityChange,
    required this.onRemove,
    required this.onUnitChange,
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
          // اسم المنتج
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.product.barcode,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // اختيار الوحدة
          Expanded(flex: 2, child: _buildUnitDropdown()),

          // السعر
          Expanded(
            flex: 1,
            child: Text(
              '${settings.currencyName} ${widget.item.unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B5FBF),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // الكمية
          Expanded(flex: 2, child: _buildQuantityControls()),

          // المجموع
          Expanded(
            flex: 1,
            child: Text(
              '${settings.currencyName} ${widget.item.totalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A3093),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // زر الحذف
          Expanded(
            flex: 1,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => widget.onRemove(widget.item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown() {
    final List<DropdownMenuItem<ProductUnit?>> items = [];

    // إضافة الخيار الأساسي (الوحدة الأساسية)
    items.add(
      DropdownMenuItem<ProductUnit?>(
        value: null,
        child: Text(
          _getBaseUnitDisplayName(widget.item.product.baseUnit),
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    // إضافة الوحدات الإضافية
    final addedUnitIds = <int>{};
    for (final unit in widget.item.availableUnits) {
      if (unit.id != null && !addedUnitIds.contains(unit.id)) {
        items.add(
          DropdownMenuItem<ProductUnit?>(
            value: unit,
            child: Text(
              unit.unitName,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
        addedUnitIds.add(unit.id!);
      }
    }

    if (items.length == 1) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1D4F7)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          _getBaseUnitDisplayName(widget.item.product.baseUnit),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
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
                    // تغيير الـ formatter ليسمح بالأرقام والنقطة بشكل صحيح
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9.]'), // السماح بالأرقام والنقطة فقط
                    ),
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
                    // تحقق من صيغة الرقم العشري
                    double? newQuantity = double.tryParse(value);

                    if (newQuantity != null && newQuantity > 0) {
                      // حساب الفرق بين الكمية الجديدة والقديمة
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
    if (widget.item.selectedUnit != null) {
      return widget.item.selectedUnit!.unitName;
    } else {
      return _getBaseUnitDisplayName(widget.item.product.baseUnit);
    }
  }

  // دالة لتنسيق الكمية للعرض
  String _formatQuantityForDisplay(double quantity) {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    } else {
      // عرض منزلتين عشريتين كحد أقصى
      final String formatted = quantity.toStringAsFixed(2);
      // إزالة الأصفار غير الضرورية
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

  // دالة لتحديد لون الكمية - معدلة لدعم الكسور العشرية
  Color _getQuantityColor(double quantity) {
    if (quantity == 0) {
      return Colors.red;
    } else if (quantity < 1) {
      return Colors.orange;
    } else if (quantity < 5) {
      // إذا كانت الكمية أقل من 5 ولكنها تحتوي على كسر عشري
      if (quantity % 1 != 0) {
        return Colors.orange; // برتقالي للكميات العشرية أقل من 5
      }
      return Colors.amber[700]!; // كهرماني للكميات الصحيحة أقل من 5
    } else {
      // إذا كانت الكمية 5 أو أكثر ولكنها تحتوي على كسر عشري
      if (quantity % 1 != 0) {
        return Colors.orange; // برتقالي للكميات العشرية 5 أو أكثر
      }
      return const Color(0xFF6A3093); // بنفسجي للكميات الصحيحة 5 أو أكثر
    }
  }
}
