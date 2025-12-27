import 'package:flutter/material.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/helpers/helpers.dart';
import 'package:shopmate/models/product.dart';
import 'package:shopmate/models/product_unit.dart';
import 'package:shopmate/providers/product_provider.dart';
import 'package:shopmate/widgets/TextField.dart';
import 'package:shopmate/widgets/existing_product_message.dart';
import 'package:shopmate/widgets/qr_scan_section.dart';

class AddProductScreen extends StatefulWidget {
  final int? productId; // تغيير من productBarcode إلى productId

  const AddProductScreen({super.key, this.productId}); // تحديث البارامتر

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final TextEditingController _qrController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _originalQuantityController =
      TextEditingController();

  // وحدات التحكم للوحدات الإضافية
  final List<UnitController> _unitControllers = [];
  final List<int> _unitIds = []; // لتخزين IDs للوحدات الموجودة

  Product? _existingProduct;
  bool _isLoading = false;
  bool _isNewProduct = true;
  String _selectedUnit = 'piece';
  bool _showUnitsSection = false;

  final ProductProvider _provider = ProductProvider();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    // تحميل المنتج إذا كان productId موجوداً
    if (widget.productId != null) {
      _loadProductById(widget.productId!);
    }
  }

  // دالة جديدة لتحميل المنتج بواسطة ID
  Future<void> _loadProductById(int productId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final product = await _provider.getProductById(productId);

      setState(() {
        _isLoading = false;

        if (product != null) {
          _existingProduct = product;
          _isNewProduct = false;

          // تعبئة البيانات الأساسية
          _nameController.text = _existingProduct!.name;
          _priceController.text = _existingProduct!.price.toString();
          _costPriceController.text = _existingProduct!.costPrice.toString();
          _quantityController.text = '0'; // الكمية الجديدة التي ستضاف

          // ⬅️ التعديل هنا: استخدام كمية المنتج الفعلية بدلاً من 0
          _originalQuantityController.text =
              _existingProduct!.quantity.toString();

          _barcodeController.text = _existingProduct!.barcode ?? '';
          _selectedUnit = _existingProduct!.baseUnit;

          // تحميل الوحدات الإضافية للمنتج الموجود
          _loadExistingUnits();
        } else {
          _existingProduct = null;
          _isNewProduct = true;
          _resetForm();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading product by ID: $e');
      showAppToast(context, 'خطأ في تحميل المنتج: $e', ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    return Directionality(
      textDirection: TextDirection.rtl, // واجهة عربية كاملة
      child: BaseLayout(
        currentPage: 'المنتجات', // الصفحة الحالية
        showAppBar: true,
        title: _isNewProduct ? 'إضافة منتج جديد' : 'تحديث المنتج',
        actions: [
          IconButton(
            onPressed: () {
              // أي إجراء تريده هنا
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        child: Padding(
          padding:
              isDesktop
                  ? const EdgeInsets.fromLTRB(40, 70, 40, 0)
                  : const EdgeInsets.all(20),
          child: _buildBody(isDesktop),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDesktop) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (isDesktop) _buildDesktopLayout() else _buildMobileLayout(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        QRScanSection(
          qrController: _qrController,
          onQRCodeChanged: (value) {
            if (value.isNotEmpty) {
              _checkProduct(value);
            }
          },
        ),
        const SizedBox(height: 30),
        _buildProductInfoSection(false),
        const SizedBox(height: 30),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // QR Section - جانب واحد
        Expanded(
          flex: 1,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'مسح الباركود',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A3093),
                    ),
                  ),
                  SizedBox(height: 20),
                  QRScanSection(
                    qrController: _qrController,
                    onQRCodeChanged: (value) {
                      if (value.isNotEmpty) {
                        _checkProduct(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 20),
        // Product Info - الجانب الآخر
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildProductInfoSection(true),
              SizedBox(height: 30),
              _buildSaveButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductInfoSection(bool isDesktop) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_existingProduct != null) ...[
                ExistingProductMessage(existingProduct: _existingProduct!),
                const SizedBox(height: 20),
              ],

              if (isDesktop) _buildDesktopForm() else _buildMobileForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileForm() {
    return Column(
      children: [
        _buildNameField(),
        SizedBox(height: 16),
        _buildUnitDropdown(),
        SizedBox(height: 16),
        _buildPriceFields(),
        SizedBox(height: 16),
        _buildQuantitySection(),
        SizedBox(height: 16),
        _buildBarcodeField(),
        SizedBox(height: 16),
        _buildUnitsSection(),
      ],
    );
  }

  Widget _buildDesktopForm() {
    return Column(
      children: [
        _buildNameField(),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildUnitDropdown()),
            SizedBox(width: 16),
            Expanded(child: _buildBarcodeField()),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildPriceField()),
            SizedBox(width: 16),
            Expanded(child: _buildCostPriceField()),
          ],
        ),
        SizedBox(height: 16),
        _buildQuantitySection(),
        SizedBox(height: 16),
        _buildUnitsSection(),
      ],
    );
  }

  Widget _buildNameField() {
    return CustomTextField(
      controller: _nameController,
      label: 'اسم المنتج',
      prefixIcon: Icons.shopping_bag,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يرجى إدخال اسم المنتج';
        }
        return null;
      },
    );
  }

  Widget _buildBarcodeField() {
    return CustomTextField(
      controller: _barcodeController,
      label: 'الباركود',
      prefixIcon: Icons.qr_code,
    );
  }

  Widget _buildPriceFields() {
    return Column(
      children: [
        _buildPriceField(),
        SizedBox(height: 16),
        _buildCostPriceField(),
      ],
    );
  }

  Widget _buildPriceField() {
    return CustomTextField(
      controller: _priceController,
      label: _selectedUnit == 'piece' ? 'سعر القطعة' : 'سعر الكيلو',
      prefixIcon: Icons.attach_money,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يرجى إدخال السعر';
        }
        if (double.tryParse(value) == null) {
          return 'يرجى إدخال سعر صحيح';
        }
        return null;
      },
    );
  }

  Widget _buildCostPriceField() {
    return CustomTextField(
      controller: _costPriceController,
      label: _selectedUnit == 'piece' ? 'تكلفة القطعة' : 'تكلفة الكيلو',
      prefixIcon: Icons.money,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يرجى إدخال سعر التكلفة';
        }
        if (double.tryParse(value) == null) {
          return 'يرجى إدخال سعر تكلفة صحيح';
        }
        return null;
      },
    );
  }

  Widget _buildUnitDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedUnit,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6A3093)),
          items: const [
            DropdownMenuItem(value: 'piece', child: Text('قطعة')),
            DropdownMenuItem(value: 'kg', child: Text('كيلو')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedUnit = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildQuantitySection() {
    return Column(
      children: [
        if (!_isNewProduct && _existingProduct != null) ...[
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700], size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الكمية الحالية: ${_existingProduct!.quantity.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _quantityController,
            label:
                _selectedUnit == 'piece'
                    ? 'الكمية المراد إضافتها (قطعة)'
                    : 'الكمية المراد إضافتها (كيلو)',
            prefixIcon: Icons.add,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال الكمية';
              }
              if (double.tryParse(value) == null) {
                return 'يرجى إدخال كمية صحيحة';
              }
              final qty = double.tryParse(value) ?? 0;
              if (qty < 0) {
                return 'الكمية لا يمكن أن تكون سالبة';
              }
              return null;
            },
          ),
        ] else ...[
          CustomTextField(
            controller: _quantityController,
            label: _selectedUnit == 'piece' ? 'الكمية (قطعة)' : 'الكمية (كيلو)',
            prefixIcon: Icons.shopping_cart,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال الكمية';
              }
              if (double.tryParse(value) == null) {
                return 'يرجى إدخال كمية صحيحة';
              }
              final qty = double.tryParse(value) ?? 0;
              if (qty <= 0) {
                return 'الكمية يجب أن تكون أكبر من صفر';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildUnitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // زر إظهار/إخفاء قسم الوحدات
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2, color: Color(0xFF6A3093)),
              SizedBox(width: 8),
              Text(
                'إدارة الوحدات الإضافية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Switch(
                value: _showUnitsSection,
                activeColor: const Color(0xFF6A3093),
                onChanged: (value) {
                  setState(() {
                    _showUnitsSection = value;
                    if (value && _unitControllers.isEmpty) {
                      _addNewUnit();
                    }
                  });
                },
              ),
            ],
          ),
        ),

        if (_showUnitsSection) ...[
          const SizedBox(height: 16),
          if (_unitControllers.isEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.amber[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا توجد وحدات مضافة. اضغط على زر "إضافة وحدة" لبدء إدارة الوحدات.',
                      style: TextStyle(color: Colors.amber[700]),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._buildUnitForms(),
          const SizedBox(height: 16),
          _buildAddUnitButton(),
        ],
      ],
    );
  }

  List<Widget> _buildUnitForms() {
    return _unitControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final controller = entry.value;

      return Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'الوحدة ${index + 1}${_unitIds.length > index && _unitIds[index] != -1 ? ' (موجودة)' : ' (جديدة)'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A3093),
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeUnit(index),
                ),
              ],
            ),
            SizedBox(height: 12),
            CustomTextField(
              controller: controller.unitNameController,
              label: 'اسم الوحدة (مثال: كرتونة، علبة، باكيت)',
              prefixIcon: Icons.category,
              validator: (value) {
                if (_showUnitsSection && (value == null || value.isEmpty)) {
                  return 'يرجى إدخال اسم الوحدة';
                }
                return null;
              },
            ),
            SizedBox(height: 12),

            CustomTextField(
              controller: controller.containQtyController,
              label: 'كم تحتوي من الوحدة الأساسية',
              prefixIcon: Icons.format_list_numbered,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (_showUnitsSection && (value == null || value.isEmpty)) {
                  return 'يرجى إدخال الكمية';
                }
                if (_showUnitsSection && double.tryParse(value!) == null) {
                  return 'يرجى إدخال كمية صحيحة';
                }
                return null;
              },
            ),
            SizedBox(height: 12),
            CustomTextField(
              controller: controller.sellPriceController,
              label: 'سعر بيع هذه الوحدة',
              prefixIcon: Icons.attach_money,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (_showUnitsSection && (value == null || value.isEmpty)) {
                  return 'يرجى إدخال السعر';
                }
                if (_showUnitsSection && double.tryParse(value!) == null) {
                  return 'يرجى إدخال سعر صحيح';
                }
                return null;
              },
            ),

            SizedBox(height: 12),
            CustomTextField(
              controller: controller.barcodeController,
              label: 'باركود الوحدة (اختياري)',
              prefixIcon: Icons.qr_code,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildAddUnitButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(Icons.add, color: Color(0xFF6A3093)),
        label: Text(
          'إضافة وحدة جديدة',
          style: TextStyle(color: Color(0xFF6A3093)),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: Color(0xFF6A3093)),
        ),
        onPressed: _addNewUnit,
      ),
    );
  }

  void _addNewUnit() {
    setState(() {
      _unitControllers.add(UnitController());
      _unitIds.add(-1); // -1 يعني وحدة جديدة
    });
  }

  void _removeUnit(int index) {
    setState(() {
      _unitControllers.removeAt(index);
      _unitIds.removeAt(index);
    });
  }

  Widget _buildSaveButton() {
    return Column(
      children: [
        SizedBox(
          width: 300,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5FBF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      _isNewProduct ? 'إضافة المنتج' : 'تحديث المنتج',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkProduct(String qrCode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _provider.searchProductsByBarcode(qrCode);

      setState(() {
        _isLoading = false;

        if (results.isNotEmpty) {
          _existingProduct = results.first;
          _isNewProduct = false;

          // تعبئة البيانات الأساسية
          _nameController.text = _existingProduct!.name;
          _priceController.text = _existingProduct!.price.toString();
          _costPriceController.text = _existingProduct!.costPrice.toString();
          _originalQuantityController.text =
              _existingProduct!.quantity.toString();
          _quantityController.text = '0';
          _barcodeController.text = _existingProduct!.barcode ?? '';

          // تعبئة البيانات الجديدة - استخدام baseUnit بدلاً من unit
          _selectedUnit = _existingProduct!.baseUnit;

          // تحميل الوحدات الإضافية للمنتج الموجود
          _loadExistingUnits();
        } else {
          _existingProduct = null;
          _isNewProduct = true;

          // إعادة تعيين الحقول
          _resetForm();
          _barcodeController.text = qrCode;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error searching product: $e');
    }
  }

  // دالة _loadExistingUnits تبقى كما هي
  Future<void> _loadExistingUnits() async {
    if (_existingProduct?.id == null) return;

    try {
      final units = await _provider.getProductUnits(_existingProduct!.id!);

      setState(() {
        _unitControllers.clear();
        _unitIds.clear();

        for (final unit in units) {
          _unitControllers.add(
            UnitController()
              ..unitNameController.text = unit.unitName
              ..barcodeController.text = unit.barcode ?? ''
              ..containQtyController.text = unit.containQty.toString()
              ..sellPriceController.text = unit.sellPrice.toString(),
          );
          _unitIds.add(unit.id!);
        }

        // إذا كان هناك وحدات موجودة، نظهر قسم الوحدات تلقائياً
        if (units.isNotEmpty) {
          _showUnitsSection = true;
        }
      });
    } catch (e) {
      print('Error loading product units: $e');
    }
  }

  void _resetForm() {
    _nameController.text = '';
    _priceController.text = '';
    _costPriceController.text = '';
    _quantityController.text = '1';
    _selectedUnit = 'piece';
    _showUnitsSection = false;
    _unitControllers.clear();
    _unitIds.clear();
    _barcodeController.text = '';
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      showAppToast(context, 'يرجى تصحيح الأخطاء في النموذج', ToastType.error);
      return;
    }

    // حساب الكمية النهائية
    double finalQuantity;
    if (_isNewProduct) {
      finalQuantity = double.tryParse(_quantityController.text) ?? 0.0;
    } else {
      final originalQty =
          double.tryParse(_originalQuantityController.text) ?? 0.0;
      final addedQty = double.tryParse(_quantityController.text) ?? 0.0;
      finalQuantity = originalQty + addedQty;
    }

    // التحقق من البيانات الأساسية
    if (_nameController.text.isEmpty) {
      showAppToast(context, 'يرجى إدخال اسم المنتج', ToastType.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isNewProduct) {
        // إنشاء كائن المنتج الجديد
        final product = Product(
          name: _nameController.text,
          barcode: _barcodeController.text,
          baseUnit: _selectedUnit,
          price: double.tryParse(_priceController.text) ?? 0.0,
          quantity: finalQuantity,
          costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
        );

        await _provider.addProduct(product);

        // محاولة الحصول على الـ ID من خلال البحث بالباركود
        try {
          final results = await _provider.searchProductsByBarcode(
            product.barcode,
          );
          if (results.isNotEmpty) {
            final newProductId = results.first.id;

            // حفظ الوحدات الإضافية
            if (_showUnitsSection && newProductId != null) {
              await _saveProductUnits(newProductId);
            }
          }
        } catch (e) {
          print('Warning: Could not get product ID: $e');
        }
      } else {
        // ✅ تحديث المنتج الموجود - مع إضافة ID
        if (_existingProduct?.id == null) {
          throw Exception('لا يمكن تحديث منتج بدون ID');
        }

        final product = Product(
          id: _existingProduct!.id, // ⬅️ هذا هو الحل! إضافة الـ ID
          name: _nameController.text,
          barcode: _barcodeController.text,
          baseUnit: _selectedUnit,
          price: double.tryParse(_priceController.text) ?? 0.0,
          quantity: finalQuantity,
          costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
          addedDate: _existingProduct?.addedDate, // الحفاظ على تاريخ الإضافة
        );

        await _provider.updateProduct(product);

        // حفظ الوحدات الإضافية
        if (_showUnitsSection && _existingProduct!.id != null) {
          await _saveProductUnits(_existingProduct!.id!);
        }
      }

      setState(() => _isLoading = false);

      // إظهار رسالة نجاح
      showAppToast(
        context,
        _isNewProduct ? 'تم إضافة المنتج بنجاح' : 'تم تحديث المنتج بنجاح',
        ToastType.success,
      );

      // الانتظار قليلاً ثم العودة
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      showAppToast(context, 'حدث خطأ: $e', ToastType.error);
      print('Error saving product: $e');
    }
  }

  Future<void> _saveProductUnits(int productId) async {
    try {
      // جلب الوحدات الحالية من قاعدة البيانات
      List<ProductUnit> existingUnits = [];
      try {
        existingUnits = await _provider.getProductUnits(productId);
      } catch (e) {
        print('خطأ في جلب الوحدات الحالية: $e');
      }

      // معالجة كل وحدة في الواجهة
      for (int i = 0; i < _unitControllers.length; i++) {
        final controller = _unitControllers[i];
        final unitId = _unitIds[i];

        final unitName = controller.unitNameController.text.trim();
        final barcode = controller.barcodeController.text.trim();
        final containQty =
            double.tryParse(controller.containQtyController.text) ?? 0.0;
        final sellPrice =
            double.tryParse(controller.sellPriceController.text) ?? 0.0;

        print('معالجة الوحدة: $unitName, ID: $unitId');

        // التحقق من صحة البيانات
        if (unitName.isEmpty) {
          print('تحذير: اسم الوحدة فارغ، تخطي');
          continue;
        }

        if (containQty <= 0) {
          print('تحذير: كمية الوحدة غير صحيحة: $containQty');
          continue;
        }

        if (sellPrice <= 0) {
          print('تحذير: سعر الوحدة غير صحيح: $sellPrice');
          continue;
        }

        // إنشاء كائن الوحدة
        final unit = ProductUnit(
          id: unitId != -1 ? unitId : null, // إذا كان -1 يعني وحدة جديدة
          productId: productId,
          unitName: unitName,
          barcode: barcode.isNotEmpty ? barcode : null,
          containQty: containQty,
          sellPrice: sellPrice,
        );

        try {
          if (unitId == -1) {
            // وحدة جديدة
            print('إضافة وحدة جديدة: $unitName');
            await _provider.addProductUnit(unit);
          } else {
            // تحديث وحدة موجودة
            print('تحديث وحدة موجودة: $unitName (ID: $unitId)');
            await _provider.updateProductUnit(unit);
          }
        } catch (e) {
          print('خطأ في حفظ الوحدة $unitName: $e');
        }
      }

      // حذف الوحدات التي تم إزالتها من الواجهة
      await _deleteRemovedUnits(productId, existingUnits);

      print('تم حفظ الوحدات بنجاح للمنتج: $productId');
    } catch (e) {
      print('خطأ كبير في حفظ الوحدات: $e');
      rethrow;
    }
  }

  Future<void> _deleteRemovedUnits(
    int productId,
    List<ProductUnit> existingUnits,
  ) async {
    try {
      // إنشاء قائمة بأسماء الوحدات الحالية في الواجهة
      final currentUnitNames =
          _unitControllers
              .map((controller) => controller.unitNameController.text.trim())
              .where((name) => name.isNotEmpty)
              .toList();

      print('أسماء الوحدات في الواجهة: $currentUnitNames');
      print(
        'الوحدات الموجودة في قاعدة البيانات: ${existingUnits.map((u) => u.unitName).toList()}',
      );

      // البحث عن الوحدات التي يجب حذفها
      for (final existingUnit in existingUnits) {
        if (!currentUnitNames.contains(existingUnit.unitName)) {
          print(
            'حذف الوحدة: ${existingUnit.unitName} (ID: ${existingUnit.id})',
          );
          await _provider.deleteProductUnit(existingUnit.id!);
        }
      }
    } catch (e) {
      print('خطأ في حذف الوحدات: $e');
    }
  }

  @override
  void dispose() {
    _qrController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    _originalQuantityController.dispose();

    // التخلص من وحدات التحكم للوحدات
    for (final controller in _unitControllers) {
      controller.dispose();
    }

    super.dispose();
  }
}

// كلاس مساعد لإدارة وحدات التحكم للوحدات الإضافية
class UnitController {
  final TextEditingController unitNameController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController containQtyController = TextEditingController();
  final TextEditingController sellPriceController = TextEditingController();

  void dispose() {
    unitNameController.dispose();
    barcodeController.dispose();
    containQtyController.dispose();
    sellPriceController.dispose();
  }
}
