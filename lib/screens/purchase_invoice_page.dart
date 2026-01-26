import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/screens/add_product_screen.dart';
import 'package:motamayez/screens/add_supplier_page.dart';
import '../providers/supplier_provider.dart';
import '../providers/purchase_invoice_provider.dart';
import '../providers/purchase_item_provider.dart';
import '../providers/product_provider.dart';
import '../providers/product_batch_provider.dart'; // تأكد من إنشاء هذا الـProvider
import '../utils/formatters.dart';

class PurchaseInvoicePage extends StatefulWidget {
  const PurchaseInvoicePage({super.key});

  @override
  State<PurchaseInvoicePage> createState() => _PurchaseInvoicePageState();
}

class _PurchaseInvoicePageState extends State<PurchaseInvoicePage> {
  // التحكم في الحقول
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _searchProductController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  // المتغيرات المحلية فقط
  int? _selectedProductId;
  int? _invoiceId;
  DateTime? _expiryDate; // أضف هذا لتخزين تاريخ الانتهاء
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _isSearching = false;
  List<Product> _searchResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });

    _searchProductController.addListener(_performSearch);
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isInitialLoading = true);

      await Provider.of<SupplierProvider>(
        context,
        listen: false,
      ).loadSuppliers();
      await Provider.of<ProductProvider>(
        context,
        listen: false,
      ).loadProducts(reset: true);

      _showSuccess('تم تحميل البيانات بنجاح');
    } catch (e) {
      _showError('خطأ في تحميل البيانات: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  void _performSearch() {
    final query = _searchProductController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final productProvider = context.read<ProductProvider>();
    final products = productProvider.products;

    final bool isBarcodeSearch = RegExp(r'^\d+$').hasMatch(query);

    final results =
        products.where((p) {
          final name = p.name.toLowerCase();

          // 🔹 بحث بالاسم → كل المنتجات
          if (!isBarcodeSearch) {
            return name.contains(query);
          }

          // 🔹 بحث بالباركود → فقط اللي عنده باركود
          if (p.barcode == null || p.barcode!.isEmpty) {
            return false;
          }

          return p.barcode!.toLowerCase().contains(query);
        }).toList();

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _searchProductController.removeListener(_performSearch);
    _searchProductController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(currentPage: 'فاتورة شراء', child: _buildMainContent()),
    );
  }

  Widget _buildMainContent() {
    if (_isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل البيانات...'),
          ],
        ),
      );
    }

    final suppliers = context.watch<SupplierProvider>().suppliers;
    final isWideScreen = MediaQuery.of(context).size.width > 768;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child:
          isWideScreen
              ? _buildDesktopLayout(suppliers)
              : _buildMobileLayout(suppliers),
    );
  }

  Widget _buildDesktopLayout(List<Map<String, dynamic>> suppliers) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildInvoiceHeader(),
              const SizedBox(height: 20),
              _buildSupplierSection(suppliers),
              const SizedBox(height: 20),
              _buildAddProductsSection(),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildInvoicePreview(),
              const SizedBox(height: 20),
              if (context
                  .watch<PurchaseInvoiceProvider>()
                  .tempInvoiceItems
                  .isNotEmpty)
                _buildInvoiceActions(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<Map<String, dynamic>> suppliers) {
    return Column(
      children: [
        _buildInvoiceHeader(),
        const SizedBox(height: 20),
        _buildSupplierSection(suppliers),
        const SizedBox(height: 20),
        _buildAddProductsSection(),
        const SizedBox(height: 20),
        _buildInvoicePreview(),
        const SizedBox(height: 20),
        if (context
            .watch<PurchaseInvoiceProvider>()
            .tempInvoiceItems
            .isNotEmpty)
          _buildInvoiceActions(),
      ],
    );
  }

  Widget _buildInvoiceHeader() {
    final invoiceProvider = context.watch<PurchaseInvoiceProvider>();
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فاتورة شراء جديدة',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _invoiceId == null ? 'مسودة' : 'فاتورة #$_invoiceId',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                if (invoiceProvider.tempInvoiceItems.isNotEmpty)
                  Text(
                    '${invoiceProvider.tempInvoiceItems.length} منتج | الإجمالي: ${Formatters.formatCurrency(invoiceProvider.tempInvoiceTotal)}',
                    style: const TextStyle(color: Colors.green, fontSize: 14),
                  ),
              ],
            ),
            Icon(Icons.receipt_long, size: 48, color: Colors.blue.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSection(List<Map<String, dynamic>> suppliers) {
    final invoiceProvider = context.watch<PurchaseInvoiceProvider>();
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المورد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddEditSupplierPage(),
                      ),
                    ).then((_) {
                      Provider.of<SupplierProvider>(
                        context,
                        listen: false,
                      ).loadSuppliers();
                    });
                  },
                  tooltip: 'إضافة مورد جديد',
                ),
              ],
            ),

            if (suppliers.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      'لا يوجد موردين، يرجى إضافة مورد أولاً',
                      style: TextStyle(color: Colors.orange),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddEditSupplierPage(),
                          ),
                        ).then((_) {
                          Provider.of<SupplierProvider>(
                            context,
                            listen: false,
                          ).loadSuppliers();
                        });
                      },
                      child: const Text('إضافة مورد'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'اختر المورد',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    value: invoiceProvider.tempSelectedSupplierId,
                    items:
                        suppliers.map((supplier) {
                          return DropdownMenuItem<int>(
                            value: supplier['id'],
                            child: Text(supplier['name']),
                          );
                        }).toList(),
                    onChanged: (value) {
                      invoiceProvider.setTempSupplierId(value);
                    },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'طريقة الدفع',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.payment),
                    ),
                    value: invoiceProvider.tempPaymentType,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                      DropdownMenuItem(value: 'credit', child: Text('آجل')),
                    ],
                    onChanged: (value) {
                      invoiceProvider.setTempPaymentType(value);
                    },
                  ),
                ],
              ),

            const SizedBox(height: 16),

            TextField(
              controller: TextEditingController(
                text: invoiceProvider.tempNote ?? '',
              ),
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 2,
              onChanged: (value) {
                invoiceProvider.setTempNote(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProductsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إضافة منتجات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddProductScreen(),
                      ),
                    );
                  },
                  tooltip: 'إضافة منتج جديد',
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _searchProductController,
              decoration: InputDecoration(
                labelText: 'ابحث عن المنتج',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _isSearching
                        ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : null,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildProductSearchResults(),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'الكمية',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'سعر التكلفة',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // قسم تاريخ الانتهاء - يظهر فقط للمنتجات التي لها صلاحية
            if (_selectedProductId != null) _buildExpiryDateSection(),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addItem,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_shopping_cart),
                            SizedBox(width: 8),
                            Text('إضافة المنتج'),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryDateSection() {
    // البحث عن المنتج المحدد
    final productProvider = context.read<ProductProvider>();
    Product? selectedProduct;

    try {
      selectedProduct = productProvider.products.firstWhere(
        (p) => p.id == _selectedProductId,
      );
    } catch (e) {
      selectedProduct = null;
    }

    // إذا كان المنتج له صلاحية، اعرض خيار تاريخ الانتهاء
    if (selectedProduct != null && selectedProduct.hasExpiry) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تاريخ الانتهاء',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                helpText: 'اختر تاريخ الانتهاء',
                confirmText: 'تأكيد',
                cancelText: 'إلغاء',
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Colors.blue,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.black,
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );

              if (selectedDate != null) {
                setState(() {
                  _expiryDate = selectedDate;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _expiryDate != null
                        ? DateFormat('yyyy-MM-dd').format(_expiryDate!)
                        : 'انقر لتحديد تاريخ الانتهاء',
                    style: TextStyle(
                      color: _expiryDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                  const Icon(Icons.calendar_today, color: Colors.blue),
                ],
              ),
            ),
          ),
          if (_expiryDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'سيتم إضافة المنتج بتاريخ انتهاء: ${DateFormat('yyyy-MM-dd').format(_expiryDate!)}',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProductSearchResults() {
    final query = _searchProductController.text.trim();

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('ابحث عن المنتجات'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text('لا توجد منتجات مطابقة لـ "$query"'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddProductScreen(),
                  ),
                );
              },
              child: const Text('إضافة منتج جديد'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        final isSelected = _selectedProductId == product.id;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected ? Colors.blue.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  product.hasExpiry
                      ? Colors.orange.shade100
                      : (isSelected ? Colors.blue : Colors.grey.shade200),
              child: Icon(
                Icons.inventory,
                color:
                    product.hasExpiry
                        ? Colors.orange
                        : (isSelected ? Colors.white : Colors.grey),
              ),
            ),
            title: Text(product.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المخزون: ${product.quantity} ${getUnitArabic(product.baseUnit)}',
                ),
                if (product.hasExpiry)
                  const Text(
                    '📅 له صلاحية',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
              ],
            ),
            trailing: Icon(
              isSelected ? Icons.check_circle : Icons.add_circle,
              color: isSelected ? Colors.green : Colors.blue,
            ),
            onTap: () {
              setState(() {
                _selectedProductId = product.id;
                _costController.text = product.costPrice.toStringAsFixed(2);
                _qtyController.text = '1';
                // إعادة تعيين تاريخ الانتهاء فقط إذا كان المنتج الجديد له صلاحية
                if (!product.hasExpiry) {
                  _expiryDate = null;
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildInvoicePreview() {
    final invoiceProvider = context.watch<PurchaseInvoiceProvider>();
    final invoiceItems = invoiceProvider.tempInvoiceItems;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'معاينة الفاتورة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text('${invoiceItems.length} منتج'),
                  backgroundColor: Colors.blue.shade50,
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (invoiceItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد منتجات في الفاتورة',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  // رأس الجدول
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'المنتج',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'الكمية',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 16),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'السعر',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 16),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'المجموع',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 16),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            '',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // المنتجات
                  ...invoiceItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    final productName = item['product_name'] ?? 'غير معروف';
                    final quantity = (item['quantity'] as num).toDouble();
                    final costPrice = (item['cost_price'] as num).toDouble();
                    final subtotal = quantity * costPrice;
                    final hasExpiry = item['has_expiry'] as bool? ?? false;
                    final expiryDate = item['expiry_date_formatted'] as String?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(productName),
                                  if (hasExpiry && expiryDate != null)
                                    Text(
                                      'ينتهي: $expiryDate',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(quantity.toStringAsFixed(2)),
                          ),
                          const SizedBox(width: 16),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(Formatters.formatNumber(costPrice)),
                          ),
                          const SizedBox(width: 16),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              Formatters.formatCurrency(subtotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed:
                                _isLoading ? null : () => _removeItem(index),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // الملخص
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('عدد المنتجات:'),
                            Text(invoiceItems.length.toString()),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('طريقة الدفع:'),
                            Text(
                              invoiceProvider.tempPaymentType == 'cash'
                                  ? 'نقدي'
                                  : 'آجل',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الإجمالي قبل الخصم:'),
                            Text(
                              Formatters.formatCurrency(
                                invoiceProvider.tempInvoiceTotal,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('قيمة الخصم:'),
                            SizedBox(
                              width: 150,
                              child: TextFormField(
                                controller: _discountController,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: false,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0.0',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  suffixIcon:
                                      invoiceProvider.tempDiscountValue > 0
                                          ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 16,
                                            ),
                                            onPressed: () {
                                              invoiceProvider
                                                  .setTempDiscountValue(0.0);
                                              _discountController.clear();
                                            },
                                          )
                                          : null,
                                ),
                                onChanged: (value) {
                                  if (value.isEmpty) {
                                    invoiceProvider.setTempDiscountValue(0.0);
                                    return;
                                  }

                                  // السماح فقط بالأرقام والنقطة
                                  String cleanedValue = value.replaceAll(
                                    RegExp(r'[^\d.]'),
                                    '',
                                  );

                                  // منع أكثر من نقطة واحدة
                                  final dotCount =
                                      cleanedValue.split('.').length - 1;
                                  if (dotCount > 1) {
                                    final parts = cleanedValue.split('.');
                                    cleanedValue = '${parts[0]}.${parts[1]}';

                                    if (_discountController.text !=
                                        cleanedValue) {
                                      _discountController.text = cleanedValue;
                                      _discountController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: cleanedValue.length,
                                            ),
                                          );
                                    }
                                  }

                                  if (cleanedValue.isEmpty) {
                                    invoiceProvider.setTempDiscountValue(0.0);
                                    return;
                                  }

                                  final discountValue =
                                      double.tryParse(cleanedValue) ?? 0.0;
                                  invoiceProvider.setTempDiscountValue(
                                    discountValue,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'المجموع الكلي:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              Formatters.formatCurrency(
                                invoiceProvider.tempInvoiceFinalTotal,
                              ),
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
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceActions() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _clearInvoice,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('مسح الفاتورة', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveInvoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, color: Colors.white),
                    SizedBox(width: 8),
                    Text('حفظ الفاتورة', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === الدوال المنطقية ===
  Future<void> _addItem() async {
    final invoiceProvider = context.read<PurchaseInvoiceProvider>();

    if (invoiceProvider.tempSelectedSupplierId == null) {
      _showError('يرجى اختيار المورد أولاً');
      return;
    }

    if (_selectedProductId == null) {
      _showError('يرجى اختيار المنتج');
      return;
    }

    final qtyText = _qtyController.text.trim();
    final costText = _costController.text.trim();

    if (qtyText.isEmpty || costText.isEmpty) {
      _showError('يرجى إدخال الكمية والسعر');
      return;
    }

    final qty = double.tryParse(qtyText);
    final cost = double.tryParse(costText);

    if (qty == null || cost == null || qty <= 0 || cost <= 0) {
      _showError('يرجى إدخال قيم صحيحة للكمية والسعر');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // الحصول على معلومات المنتج
      final productProvider = context.read<ProductProvider>();
      final product = productProvider.products.firstWhere(
        (p) => p.id == _selectedProductId,
        orElse: () => throw Exception('المنتج غير موجود في القائمة'),
      );

      // التحقق إذا كان المنتج له صلاحية
      if (product.hasExpiry) {
        // التحقق من إدخال تاريخ الانتهاء
        if (_expiryDate == null) {
          _showError('يجب تحديد تاريخ الانتهاء لهذا المنتج');
          setState(() => _isLoading = false);
          return;
        }

        // التحقق من أن تاريخ الانتهاء ليس في الماضي
        if (_expiryDate!.isBefore(DateTime.now())) {
          _showError('تاريخ الانتهاء لا يمكن أن يكون في الماضي');
          setState(() => _isLoading = false);
          return;
        }

        // إضافة العنصر مع معلومات تاريخ الانتهاء
        final newItem = {
          'product_id': product.id!,
          'product_name': product.name,
          'quantity': qty,
          'cost_price': cost,
          'subtotal': qty * cost,
          'has_expiry': true,
          'expiry_date': _expiryDate!.toIso8601String(),
          'expiry_date_formatted': DateFormat(
            'yyyy-MM-dd',
          ).format(_expiryDate!),
        };

        invoiceProvider.addTempItem(newItem);

        _showSuccess(
          'تم إضافة "${product.name}" مع تاريخ انتهاء: ${DateFormat('yyyy-MM-dd').format(_expiryDate!)}',
        );
      } else {
        // المنتج بدون صلاحية
        final newItem = {
          'product_id': product.id!,
          'product_name': product.name,
          'quantity': qty,
          'cost_price': cost,
          'subtotal': qty * cost,
          'has_expiry': false,
        };

        invoiceProvider.addTempItem(newItem);
        _showSuccess('تم إضافة "${product.name}" بنجاح');
      }

      // تفريغ الحقول وإعادة التعيين
      _resetFormFields();
    } catch (e) {
      _showError('حدث خطأ أثناء إضافة المنتج: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeItem(int index) async {
    final invoiceProvider = context.read<PurchaseInvoiceProvider>();

    if (index < 0 || index >= invoiceProvider.tempInvoiceItems.length) return;

    setState(() => _isLoading = true);

    try {
      // حذف العنصر من الـProvider
      invoiceProvider.removeTempItem(index);
      _showSuccess('تم حذف المنتج بنجاح');
    } catch (e) {
      _showError('حدث خطأ أثناء الحذف: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveInvoice() async {
    final invoiceProvider = context.read<PurchaseInvoiceProvider>();
    final invoiceItems = invoiceProvider.tempInvoiceItems;

    if (invoiceItems.isEmpty) {
      _showError('لا يمكن حفظ فاتورة فارغة');
      return;
    }

    if (invoiceProvider.tempSelectedSupplierId == null) {
      _showError('يرجى اختيار المورد أولاً');
      return;
    }

    // تحقق من أن الخصم لا يتجاوز الإجمالي
    if (invoiceProvider.tempDiscountValue > invoiceProvider.tempInvoiceTotal) {
      _showError('قيمة الخصم لا يمكن أن تتجاوز الإجمالي');
      return;
    }

    // التحقق من تاريخ الانتهاء للمنتجات التي لها صلاحية (جديد)
    for (final item in invoiceItems) {
      final hasExpiry = item['has_expiry'] as bool;

      if (hasExpiry) {
        final expiryDateStr = item['expiry_date'] as String?;
        final productName = item['product_name'] as String;

        if (expiryDateStr == null || expiryDateStr.isEmpty) {
          _showError('يجب تحديد تاريخ الانتهاء لـ "$productName"');
          return;
        }

        final expiryDate = DateTime.tryParse(expiryDateStr);
        if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
          _showError('تاريخ انتهاء "$productName" في الماضي');
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      final purchaseInvoiceProvider = context.read<PurchaseInvoiceProvider>();
      final purchaseItemProvider = context.read<PurchaseItemProvider>();
      final productBatchProvider = context.read<ProductBatchProvider>();

      // 🔹 1. إنشاء الفاتورة الرئيسية (كما كان)
      _invoiceId = await purchaseInvoiceProvider.addPurchaseInvoice(
        supplierId: invoiceProvider.tempSelectedSupplierId!,
        totalCost: invoiceProvider.tempInvoiceFinalTotal,
        paymentType: invoiceProvider.tempPaymentType ?? 'cash',
        note: invoiceProvider.tempNote,
        paidAmount: 0.0,
      );

      // 🔹 2. حفظ عناصر الفاتورة والدفعات
      int batchCount = 0;

      for (final item in invoiceItems) {
        final productId = item['product_id'] as int;
        final quantity = (item['quantity'] as num).toDouble();
        final costPrice = (item['cost_price'] as num).toDouble();
        final hasExpiry = item['has_expiry'] as bool;

        // 2.1 إضافة عنصر الشراء (كما كان)
        await purchaseItemProvider.addPurchaseItem(
          purchaseId: _invoiceId!,
          productId: productId,
          quantity: quantity,
          costPrice: costPrice,
        );

        // 2.2 إذا كان له صلاحية، إضافة الدفعة (جديد)
        if (hasExpiry) {
          final expiryDateStr = item['expiry_date'] as String;

          await productBatchProvider.addProductBatch(
            productId: productId,
            purchaseItemId: null, // أو purchaseItemId إذا عدلت addPurchaseItem
            quantity: quantity,
            remainingQuantity: quantity,
            costPrice: costPrice,
            expiryDate: expiryDateStr.split('T')[0], // تنسيق YYYY-MM-DD
            productionDate: null,
          );

          batchCount++;
        }
      }

      // 🔹 3. عرض رسالة النجاح
      String successMessage = 'تم حفظ الفاتورة بنجاح رقم #$_invoiceId';
      if (batchCount > 0) {
        successMessage += '\nتم حفظ $batchCount دفعة للمنتجات ذات الصلاحية';
      }

      _showSuccess(successMessage);
      _clearInvoice();
    } catch (e) {
      _showError('خطأ في حفظ الفاتورة: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearInvoice() {
    // مسح الفاتورة من الـProvider
    final invoiceProvider = context.read<PurchaseInvoiceProvider>();
    invoiceProvider.clearTempInvoice();

    // مسح جميع الحقول المحلية
    setState(() {
      _invoiceId = null;
      _selectedProductId = null;
      _expiryDate = null;
      _searchProductController.clear();
      _searchResults.clear();
    });

    // مسح المتحكمات
    _qtyController.clear();
    _costController.clear();
    _discountController.clear();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String getUnitArabic(String unit) {
    switch (unit.toLowerCase()) {
      case 'piece':
        return 'قطعة';
      case 'kg':
        return 'كيلو';
      default:
        return unit;
    }
  }

  // دالة مساعدة لتفريغ الحقول
  void _resetFormFields() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _qtyController.clear();
      _costController.clear();
      _selectedProductId = null;
      _expiryDate = null;
      _searchProductController.clear();
      setState(() {
        _searchResults.clear();
      });
    });
  }
}
