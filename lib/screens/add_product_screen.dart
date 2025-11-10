import 'package:flutter/material.dart';
import 'package:shopmate/models/product.dart';
import 'package:shopmate/providers/product_provider.dart';
import 'package:shopmate/widgets/TextField.dart';
import 'package:shopmate/widgets/existing_product_message.dart';
import 'package:shopmate/widgets/product_service.dart';
import 'package:shopmate/widgets/qr_scan_section.dart';

class AddProductScreen extends StatefulWidget {
  final String? productBarcode; // ✅ باركود اختياري

  const AddProductScreen({super.key, this.productBarcode}); // ✅ ممرر اختياري

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

  // إضافة controller جديد للكمية الأصلية في بداية الكلاس مع المتغيرات الأخرى
  final TextEditingController _originalQuantityController =
      TextEditingController();

  Product? _existingProduct;
  bool _isLoading = false;
  bool _isNewProduct = true;

  @override
  void initState() {
    super.initState();

    // ✅ إذا تم تمرير barcode نحطه مباشرة في الحقل
    if (widget.productBarcode != null && widget.productBarcode!.isNotEmpty) {
      _qrController.text = widget.productBarcode!;
      _barcodeController.text = widget.productBarcode!;
      _checkProduct(widget.productBarcode!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  final ProductProvider _provider = ProductProvider();

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF6A3093)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _isNewProduct ? 'إضافة منتج جديد' : 'تحديث المنتج',
        style: const TextStyle(
          color: Color(0xFF6A3093),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // مسح QR Code
          QRScanSection(
            qrController: _qrController,
            onQRCodeChanged: (value) {
              if (value.isNotEmpty) {
                _checkProduct(value);
              }
            },
          ),

          const SizedBox(height: 30),

          // معلومات المنتج
          _buildProductInfoSection(),

          const SizedBox(height: 30),

          // زر الحفظ
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildProductInfoSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_existingProduct != null) ...[
              ExistingProductMessage(existingProduct: _existingProduct!),
              const SizedBox(height: 20),
            ],

            CustomTextField(
              controller: _nameController,
              label: 'اسم المنتج',
              prefixIcon: Icons.shopping_bag,
            ),

            const SizedBox(height: 16),

            CustomTextField(
              controller: _priceController,
              label: 'السعر',
              prefixIcon: Icons.attach_money,
            ),

            const SizedBox(height: 16),

            CustomTextField(
              controller: _costPriceController,
              label: 'سعر التكلفة',
              prefixIcon: Icons.money,
            ),

            const SizedBox(height: 16),

            // تعديل قسم الكمية
            if (!_isNewProduct) ...[
              // الكمية الحالية - للقراءة فقط
              CustomTextField(
                controller: _originalQuantityController,
                label: 'الكمية الحالية',
                prefixIcon: Icons.inventory,
                readOnly: true,
              ),

              const SizedBox(height: 16),

              // الكمية المراد إضافتها
              CustomTextField(
                controller: _quantityController,
                label: 'الكمية المراد إضافتها',
                prefixIcon: Icons.add_shopping_cart,
              ),
            ] else ...[
              CustomTextField(
                controller: _quantityController,
                label: 'الكمية',
                prefixIcon: Icons.shopping_cart,
              ),
            ],

            const SizedBox(height: 16),

            CustomTextField(
              controller: _barcodeController,
              label: 'الباركود',
              prefixIcon: Icons.qr_code,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
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
          // المنتج موجود
          _existingProduct = results.first;
          _isNewProduct = false;

          _nameController.text = _existingProduct!.name;
          _priceController.text = _existingProduct!.price.toString();
          _costPriceController.text = _existingProduct!.costPrice.toString();
          _originalQuantityController.text =
              _existingProduct!.quantity.toString(); // الكمية الأصلية
          _quantityController.text = '0'; // تصفير الكمية المراد إضافتها
          _barcodeController.text = _existingProduct!.barcode;
        } else {
          // المنتج غير موجود
          _existingProduct = null;
          _isNewProduct = true;

          _nameController.text = '';
          _priceController.text = '';
          _costPriceController.text = '';
          _quantityController.text = '1';
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

  // تعديل دالة saveProduct لجمع الكميتين
  _saveProduct() async {
    final newQuantity = int.tryParse(_quantityController.text) ?? 0;

    final product = Product(
      name: _nameController.text,
      barcode: _barcodeController.text,
      price: double.tryParse(_priceController.text) ?? 0.0,
      costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
      quantity: newQuantity,
    );

    setState(() => _isLoading = true);

    try {
      if (_isNewProduct) {
        await ProductProvider().addProduct(product);
      } else {
        await ProductProvider().updateProduct(product);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = false);

    // ارجع true بعد ما يخلص كل شيء
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _originalQuantityController.dispose(); // إضافة dispose للcontroller الجديد
    _qrController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }
}
