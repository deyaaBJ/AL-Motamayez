import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/models/product_unit.dart';
import 'package:motamayez/providers/opening_balance_provider.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:provider/provider.dart';

class OpeningBalanceScreen extends StatefulWidget {
  const OpeningBalanceScreen({super.key});

  @override
  State<OpeningBalanceScreen> createState() => _OpeningBalanceScreenState();
}

class _OpeningBalanceScreenState extends State<OpeningBalanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedExpiryDate;
  Product? _selectedProduct;
  ProductUnit? _selectedUnit;
  double _selectedUnitContainQty = 1.0;
  bool _isSaving = false;
  List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _items = [];

  // خريطة لترجمة الوحدات والكلمات الإنجليزية إلى العربية
  static const Map<String, String> _arabicTranslations = {
    'kg': 'كجم',
    'g': 'جرام',
    'mg': 'مجم',
    'l': 'لتر',
    'ml': 'مل',
    'piece': 'قطعة',
    'pieces': 'قطع',
    'box': 'صندوق',
    'boxes': 'صناديق',
    'pack': 'باكيت',
    'packs': 'باكيتات',
    'bottle': 'زجاجة',
    'bottles': 'زجاجات',
    'price': 'السعر',
    'cost': 'التكلفة',
    'unit': 'وحدة',
  };

  String _translateUnit(String? unitName) {
    if (unitName == null) return '';
    final lower = unitName.toLowerCase();
    return _arabicTranslations[lower] ?? unitName;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_performSearch);
    _searchController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedProduct = null;
        _selectedUnit = null;
        _selectedUnitContainQty = 1.0;
      });
      return;
    }

    final productProvider = context.read<ProductProvider>();
    final List<Map<String, dynamic>> results = [];

    if (RegExp(r'^\d+$').hasMatch(query)) {
      final units = await productProvider.searchProductUnitsByBarcode(query);
      for (final unit in units) {
        final product = await productProvider.getProductById(unit.productId);
        if (product == null) continue;

        results.add({
          'product': product,
          'unit': unit,
          'display_name': '${product.name} [${_translateUnit(unit.unitName)}]',
          'display_cost': product.costPrice * unit.containQty,
        });
      }
    }

    final products = await productProvider.searchProducts(query);
    for (final product in products) {
      results.add({
        'product': product,
        'unit': null,
        'display_name': product.name,
        'display_cost': product.costPrice,
      });

      // جلب جميع الوحدات المرتبطة بالمنتج
      try {
        final units = await productProvider.getProductUnits(product.id!);
        for (final unit in units) {
          final alreadyAdded = results.any(
            (item) =>
                (item['product'] as Product).id == product.id &&
                (item['unit'] as ProductUnit?)?.id == unit.id,
          );
          if (alreadyAdded) continue;

          results.add({
            'product': product,
            'unit': unit,
            'display_name':
                '${product.name} [${_translateUnit(unit.unitName)}]',
            'display_cost': product.costPrice * unit.containQty,
          });
        }
      } catch (e) {
        // تجاهل الأخطاء في جلب الوحدات
      }
    }

    final unitsByName = await productProvider.searchProductUnitsByName(query);
    for (final unit in unitsByName) {
      final product = await productProvider.getProductById(unit.productId);
      if (product == null) continue;

      final alreadyAdded = results.any(
        (item) =>
            (item['product'] as Product).id == product.id &&
            (item['unit'] as ProductUnit?)?.id == unit.id,
      );
      if (alreadyAdded) continue;

      results.add({
        'product': product,
        'unit': unit,
        'display_name': '${product.name} [${_translateUnit(unit.unitName)}]',
        'display_cost': product.costPrice * unit.containQty,
      });
    }

    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final product = result['product'] as Product;
    final unit = result['unit'] as ProductUnit?;

    setState(() {
      _selectedProduct = product;
      _selectedUnit = unit;
      _selectedUnitContainQty = unit?.containQty ?? 1.0;
      _selectedExpiryDate = null;
      _searchController.text = result['display_name'] as String;
      _searchResults = [];
      _costController.text = (result['display_cost'] as num)
          .toDouble()
          .toStringAsFixed(2);
      _qtyController.text = '1';
    });
  }

  // دالة لاختيار أول نتيجة تلقائياً عند الضغط على Enter
  Future<void> _onSearchSubmitted(String value) async {
    // تأكيد البحث أولاً للتأكد من تحميل النتائج
    await _performSearch();
    if (_searchResults.isNotEmpty) {
      _selectSearchResult(_searchResults.first);
    } else if (value.isNotEmpty) {
      _showMessage('لم يتم العثور على منتج مطابق', isError: true);
    }
  }

  void _addItem() {
    if (_selectedProduct?.id == null) {
      _showMessage('يرجى اختيار المنتج أو الوحدة', isError: true);
      return;
    }

    final quantity = double.tryParse(_qtyController.text.trim());
    final enteredCostPrice = double.tryParse(_costController.text.trim());

    if (quantity == null ||
        quantity <= 0 ||
        enteredCostPrice == null ||
        enteredCostPrice <= 0) {
      _showMessage('يرجى إدخال كمية وتكلفة صحيحتين', isError: true);
      return;
    }

    final isUnit = _selectedUnit != null;
    final requiresExpiry = _selectedProduct!.hasExpiryDate;

    if (requiresExpiry && _selectedExpiryDate == null) {
      _showMessage('يرجى تحديد تاريخ الانتهاء لهذا المنتج', isError: true);
      return;
    }

    final actualQuantity = quantity * _selectedUnitContainQty;
    final costPerBaseUnit = enteredCostPrice / actualQuantity;
    final displayName =
        isUnit
            ? '${_selectedProduct!.name} [${_translateUnit(_selectedUnit!.unitName)}]'
            : _selectedProduct!.name;

    final existingIndex = _items.indexWhere(
      (item) =>
          item['product_id'] == _selectedProduct!.id &&
          item['unit_id'] == _selectedUnit?.id,
    );

    final newItem = {
      'product_id': _selectedProduct!.id!,
      'product_name': displayName,
      'display_quantity': quantity,
      'quantity': actualQuantity,
      'cost_price': costPerBaseUnit,
      'entered_cost_price': enteredCostPrice,
      'subtotal': enteredCostPrice,
      'unit_id': _selectedUnit?.id,
      'unit_name': _selectedUnit?.unitName,
      'unit_contain_qty': _selectedUnitContainQty,
      'is_unit': isUnit,
      'expiry_date':
          requiresExpiry
              ? DateFormat('yyyy-MM-dd').format(_selectedExpiryDate!)
              : null,
      'expiry_date_formatted':
          requiresExpiry
              ? DateFormat('yyyy-MM-dd').format(_selectedExpiryDate!)
              : null,
      'has_expiry': requiresExpiry,
    };

    setState(() {
      if (existingIndex != -1) {
        _items[existingIndex] = newItem;
      } else {
        _items.add(newItem);
      }

      _selectedProduct = null;
      _selectedUnit = null;
      _selectedUnitContainQty = 1.0;
      _selectedExpiryDate = null;
      _searchController.clear();
      _qtyController.clear();
      _costController.clear();
      _searchResults = [];
    });
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      _showMessage('لا يمكن حفظ رصيد افتتاحي فارغ', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<OpeningBalanceProvider>().addOpeningBalance(
        date: _selectedDate,
        note: _noteController.text,
        items: _items,
      );

      if (!mounted) return;
      // الانتقال إلى صفحة المنتجات بعد الحفظ بنجاح
      Navigator.of(context).pushReplacementNamed('/products');
    } catch (e) {
      _showMessage('حدث خطأ أثناء الحفظ: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(
      0,
      (sum, item) => sum + ((item['subtotal'] as num).toDouble()),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'الرصيد الافتتاحي',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // بطاقة التاريخ والملاحظة
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.date_range,
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(_selectedDate),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: 'ملاحظة',
                            hintText: 'اختياري ...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(
                              Icons.note_alt_outlined,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // بطاقة إضافة المنتج
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إضافة منتج أو وحدة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onSubmitted: _onSearchSubmitted,
                        decoration: InputDecoration(
                          labelText: 'البحث بالاسم أو الباركود',
                          hintText: 'اكتب اسم المنتج أو الباركود ثم اضغط Enter',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.teal,
                          ),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _performSearch();
                                    },
                                  )
                                  : null,
                        ),
                      ),
                      if (_searchResults.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 240),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder:
                                (_, __) => Divider(
                                  height: 0,
                                  color: Colors.grey.shade200,
                                ),
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              final product = result['product'] as Product;
                              final unit = result['unit'] as ProductUnit?;
                              final translatedBaseUnit = _translateUnit(
                                product.baseUnit,
                              );

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal.shade50,
                                  child: const Icon(
                                    Icons.production_quantity_limits,
                                    color: Colors.teal,
                                  ),
                                ),
                                title: Text(
                                  result['display_name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  unit == null
                                      ? 'المخزون الحالي: ${product.quantity.toStringAsFixed(2)} $translatedBaseUnit'
                                      : 'الوحدة: ${_translateUnit(unit.unitName)} | تحتوي ${unit.containQty.toStringAsFixed(unit.containQty % 1 == 0 ? 0 : 2)} $translatedBaseUnit',
                                ),
                                onTap: () => _selectSearchResult(result),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _qtyController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    _selectedUnit == null
                                        ? 'الكمية'
                                        : 'الكمية (${_translateUnit(_selectedUnit!.unitName)})',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(
                                  Icons.production_quantity_limits,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _costController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    _selectedUnit == null
                                        ? 'إجمالي سعر الشراء'
                                        : 'إجمالي سعر الشراء (${_translateUnit(_selectedUnit!.unitName)})',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(
                                  Icons.attach_money,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedProduct?.hasExpiryDate == true) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _selectedExpiryDate ??
                                  DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                              ),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _selectedExpiryDate = picked);
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_available,
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedExpiryDate == null
                                      ? 'اختيار تاريخ الانتهاء'
                                      : 'تاريخ الانتهاء: ${DateFormat('yyyy-MM-dd').format(_selectedExpiryDate!)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        _selectedExpiryDate == null
                                            ? Colors.grey.shade700
                                            : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // بطاقة قائمة العناصر المضافة
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المنتجات المضافة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 60,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'لم تتم إضافة أي منتجات بعد',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final isUnit = item['is_unit'] as bool? ?? false;
                            final unitName =
                                item['unit_name'] != null
                                    ? _translateUnit(
                                      item['unit_name'] as String,
                                    )
                                    : '';
                            final displayQty =
                                item['display_quantity'] as double;
                            final enteredCost =
                                item['entered_cost_price'] as double;
                            final actualQty = item['quantity'] as double;
                            final costPerBase = item['cost_price'] as double;
                            final subtotal = item['subtotal'] as double;
                            final expiryDate =
                                item['expiry_date_formatted'] as String?;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['product_name'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isUnit
                                              ? 'الكمية: $displayQty $unitName | إجمالي الشراء: ${enteredCost.toStringAsFixed(2)} | سعر القطعة: ${costPerBase.toStringAsFixed(2)} | الفعلي: ${actualQty.toStringAsFixed(2)}'
                                              : 'الكمية: ${actualQty.toStringAsFixed(2)} | إجمالي الشراء: ${enteredCost.toStringAsFixed(2)} | سعر القطعة: ${costPerBase.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        if (expiryDate != null)
                                          Text(
                                            'تاريخ الانتهاء: $expiryDate',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    subtotal.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => _items.removeAt(index));
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'حذف',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي الكلي:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            total.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // زر الحفظ
              Center(
                child: SizedBox(
                  width: 280,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'جارٍ الحفظ...' : 'حفظ الرصيد الافتتاحي',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
