import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/models/cart_item.dart';
import 'package:shopmate/models/customer.dart';
import 'package:shopmate/models/product.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/providers/customer_provider.dart';
import 'package:shopmate/providers/product_provider.dart';
import 'package:shopmate/widgets/cart_item_widget.dart';
import 'package:shopmate/widgets/customer_form_dialog.dart';
import 'package:shopmate/widgets/customer_selection_dialog.dart';
import 'package:shopmate/widgets/sale_confirmation_dialog.dart';
import 'package:shopmate/widgets/table_header_widget.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

final ProductProvider _provider = ProductProvider();

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final List<CartItem> _cartItems = [];
  double _totalAmount = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // حقل إدخال الباركود
          _buildBarcodeInput(),

          // جدول العناصر
          Expanded(child: _buildCartTable()),

          // المجموع والأزرار
          _buildTotalAndButtons(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 3,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF6A3093)),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'نقطة البيع',
        style: TextStyle(
          color: Color(0xFF6A3093),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [const Icon(Icons.qr_code_scanner, color: Color(0xFF6A3093))],
    );
  }

  Widget _buildBarcodeInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _barcodeController,
              focusNode: FocusNode()..requestFocus(), // يخلي الفوكس دايمًا عليه
              decoration: InputDecoration(
                hintText: '🔍 امسح الباركود أو أدخل الرمز',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF8B5FBF),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFFF8F5FF),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _addProductToCart(value);
                  _barcodeController.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5FBF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCartTable() {
    if (_cartItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد عناصر في السلة',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'ابدأ بمسح الباركود لإضافة المنتجات',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // رأس الجدول
              const TableHeaderWidget(),

              // عناصر الجدول
              ..._cartItems
                  .map(
                    (item) => CartItemWidget(
                      item: item,
                      onQuantityChange: _updateQuantity,
                      onRemove: _removeFromCart,
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAndButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // المجموع
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE1D4F7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المجموع الكلي:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A3093),
                  ),
                ),
                Text(
                  '₪${_totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5FBF),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // الأزرار
          Row(
            children: [
              // زر طباعة الفاتورة
              Expanded(
                child: _buildActionButton(
                  'طباعة الفاتورة',
                  Icons.receipt,
                  const Color(0xFF8B5FBF),
                  _printInvoice,
                ),
              ),

              const SizedBox(width: 12),

              // زر إتمام البيع
              Expanded(
                child: _buildActionButton(
                  'إتمام البيع',
                  Icons.check_circle,
                  const Color(0xFF4CAF50),
                  _completeSale,
                ),
              ),

              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'بيع مؤجل',
                  Icons.check_circle,
                  const Color.fromARGB(255, 240, 236, 35),
                  _recordDebtSale,
                ),
              ),

              const SizedBox(width: 12),
              // زر حذف السلة
              Expanded(
                child: _buildActionButton(
                  'حذف السلة',
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
      height: 50,
      child: ElevatedButton(
        onPressed: _cartItems.isEmpty ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProductToCart(String barcode) async {
    final products = await _provider.searchProductsByBarcode(barcode);

    if (products.isNotEmpty) {
      final product = products.first;

      // 🔹 تحقق من الكمية قبل الإضافة
      if (product.quantity < 1) {
        _showOutOfStockDialog(product.name);
        return;
      }

      final existingItemIndex = _cartItems.indexWhere(
        (item) => item.product.barcode == product.barcode,
      );

      setState(() {
        if (existingItemIndex != -1) {
          _cartItems[existingItemIndex].quantity++;
        } else {
          _cartItems.add(CartItem(product: product, quantity: 1));
        }
        _calculateTotal();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة ${product.name} إلى السلة'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المنتج غير موجود'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOutOfStockDialog(String productName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.red, size: 30),
                SizedBox(width: 8),
                Text(
                  'الكمية نفدت',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            content: Text(
              'المنتج "$productName" غير متوفر حاليًا في المخزون.',
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text(
                  'حسنًا',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  void _updateQuantity(CartItem item, int change) {
    setState(() {
      item.quantity += change;
      if (item.quantity <= 0) {
        _cartItems.remove(item);
      }
      _calculateTotal();
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() {
      _cartItems.remove(item);
      _calculateTotal();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حذف ${item.product.name} من السلة'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      return sum + (item.product.price * item.quantity);
    });
  }

  Future<void> _printInvoice() async {
    if (_cartItems.isEmpty) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('طباعة الفاتورة'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.print, size: 60, color: Color(0xFF6A3093)),
                SizedBox(height: 16),
                Text('سيتم طباعة الفاتورة وإتمام البيع'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _processSaleWithValidation(printInvoice: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5FBF),
                ),
                child: const Text('طباعة وإتمام'),
              ),
            ],
          ),
    );
  }

  Future<void> _completeSale() async {
    if (_cartItems.isEmpty) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('إتمام البيع'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 60, color: Colors.green),
                SizedBox(height: 16),
                Text('هل تريد إتمام عملية البيع؟'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _processSaleWithValidation(printInvoice: false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('نعم، إتمام البيع'),
              ),
            ],
          ),
    );
  }

  Future<void> _processSaleWithValidation({bool printInvoice = false}) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = auth.role ?? '';
      // محاولة إتمام البيع مع التحقق من الكميات
      await _provider.addSale(
        cartItems: _cartItems,
        totalAmount: _totalAmount,
        userRole: role,
      );

      // إذا نجحت العملية بدون أخطاء، نكمل
      if (printInvoice) {
        // كود الطباعة هنا
      }

      setState(() {
        _cartItems.clear();
        _totalAmount = 0.0;
      });

      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت عملية البيع بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // في حالة وجود خطأ في الكمية، نعرض popup ولا نكمل العملية
      _showQuantityErrorDialog(e.toString());
    }
  }

  void _showQuantityErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // المستخدم لا يمكنه إغلاق الـ dialog بالنقر خارجها
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('خطأ في الكمية', style: TextStyle(color: Colors.red)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                const SizedBox(height: 16),
                const Text(
                  'عملية البيع لم تكتمل. الرجاء تعديل الكميات والمحاولة مرة أخرى.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('موافق'),
              ),
            ],
          ),
    );
  }

  Future<void> _recordDebtSale() async {
    if (_cartItems.isEmpty) return;

    await _showCustomerSelectionDialog();
  }

  Future<void> _showCustomerSelectionDialog() async {
    final Customer? selectedCustomer = await showDialog<Customer>(
      context: context,
      builder:
          (context) => CustomerSelectionDialog(
            onSaleCompleted: (customer) {
              Navigator.pop(context, customer); // إرجاع الزبون المختار
            },
          ),
    );

    if (selectedCustomer != null) {
      await _handleSaleCompletion(selectedCustomer);
    }
  }

  Future<void> _handleSaleCompletion(Customer customer) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = auth.role ?? '';
      await _provider.addSale(
        cartItems: _cartItems,
        totalAmount: _totalAmount,
        paymentType: 'credit',
        customerId: customer.id,
        userRole: role,
      );

      await _showSaleConfirmationDialog();

      setState(() {
        _cartItems.clear();
        _totalAmount = 0.0;
      });
    } catch (e) {
      // في حالة وجود خطأ في الكمية، نعرض popup ولا نكمل العملية
      _showQuantityErrorDialog(e.toString());
    }
  }

  Future<void> _showSaleConfirmationDialog() async {
    return showDialog(
      context: context,
      builder: (context) => const SaleConfirmationDialog(),
    );
  }

  void _clearCart() {
    if (_cartItems.isEmpty) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('حذف السلة'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, size: 60, color: Colors.orange),
                SizedBox(height: 16),
                Text('هل أنت متأكد من حذف جميع العناصر من السلة؟'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _cartItems.clear();
                    _totalAmount = 0.0;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف جميع العناصر من السلة'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('نعم، حذف الكل'),
              ),
            ],
          ),
    );
  }

  void _processSale({required bool printInvoice}) {
    final action = printInvoice ? 'طباعة فاتورة' : 'إتمام بيع';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم $action بنجاح - المجموع: ₪${_totalAmount.toStringAsFixed(2)}',
        ),
        backgroundColor: Colors.green,
      ),
    );

    // إعادة تعيين السلة بعد إتمام البيع
    setState(() {
      _cartItems.clear();
      _totalAmount = 0.0;
    });
  }
}
