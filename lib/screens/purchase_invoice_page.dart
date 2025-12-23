import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/models/product.dart';
import 'package:shopmate/screens/add_supplier_page.dart';
import '../providers/supplier_provider.dart';
import '../providers/purchase_invoice_provider.dart';
import '../providers/purchase_item_provider.dart';
import '../providers/product_provider.dart';
import '../utils/formatters.dart';

// صفحة إضافة منتج جديد
class AddProductPage extends StatelessWidget {
  const AddProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة منتج جديد'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'اسم المنتج',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.shopping_bag),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('حفظ المنتج'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PurchaseInvoicePage extends StatefulWidget {
  const PurchaseInvoicePage({super.key});

  @override
  State<PurchaseInvoicePage> createState() => _PurchaseInvoicePageState();
}

class _PurchaseInvoicePageState extends State<PurchaseInvoicePage> {
  // التحكم في الحقول
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _searchProductController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // المتغيرات
  int? _selectedSupplierId;
  int? _selectedProductId;
  String? _selectedPaymentType = 'cash';
  String? _invoiceNote;
  int? _invoiceId;
  List<Map<String, dynamic>> _invoiceItems = [];
  double _invoiceTotal = 0.0;
  
  // حالات التحميل
  bool _isLoading = false;
  bool _isCreatingInvoice = false;
  bool _isInitialLoading = true;
  bool _isSearching = false;
  List<Product> _searchResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
    
    // إضافة Listener للبحث
    _searchProductController.addListener(_performSearch);
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isInitialLoading = true);

      await Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
      await Provider.of<ProductProvider>(context, listen: false).loadProducts(reset: true);

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

    // البحث في المنتجات المحملة
    final productProvider = context.read<ProductProvider>();
    final products = productProvider.products;
    
    final results = products.where((p) {
      return p.name.toLowerCase().contains(query) ||
             (p.barcode ?? '').toLowerCase().contains(query);
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
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'فاتورة شراء',
        showAppBar: false,
        child: _buildMainContent(),
      ),
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
      child: isWideScreen ? _buildDesktopLayout(suppliers) : _buildMobileLayout(suppliers),
    );
  }

  Widget _buildDesktopLayout(List<Map<String, dynamic>> suppliers) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الجانب الأيسر: إنشاء الفاتورة
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
        
        // الجانب الأيمن: عرض الفاتورة
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildInvoicePreview(),
              const SizedBox(height: 20),
              if (_invoiceItems.isNotEmpty) _buildInvoiceActions(),
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
        if (_invoiceItems.isNotEmpty) _buildInvoiceActions(),
      ],
    );
  }

  Widget _buildInvoiceHeader() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                  _invoiceId == null ? 'مسودة' : 'فاتورة #${_invoiceId}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.receipt_long,
              size: 48,
              color: Colors.blue.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSection(List<Map<String, dynamic>> suppliers) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddSupplierPage(),
                      ),
                    ).then((_) {
                      Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
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
                            builder: (context) => const AddSupplierPage(),
                          ),
                        ).then((_) {
                          Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
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
                    value: _selectedSupplierId,
                    items: suppliers.map((supplier) {
                      return DropdownMenuItem<int>(
                        value: supplier['id'],
                        child: Text(supplier['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSupplierId = value;
                      });
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
                    value: _selectedPaymentType,
                    items: const [
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('نقدي'),
                      ),
                      DropdownMenuItem(
                        value: 'credit',
                        child: Text('آجل'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentType = value;
                      });
                    },
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 2,
              onChanged: (value) => _invoiceNote = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProductsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddProductPage(),
                      ),
                    ).then((_) {
                      Provider.of<ProductProvider>(context, listen: false).loadProducts(reset: true);
                    });
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
                suffixIcon: _isSearching
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
                    keyboardType: TextInputType.number,
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
                    keyboardType: TextInputType.number,
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
                child: _isLoading
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

  Widget _buildProductSearchResults() {
    final query = _searchProductController.text.trim();
    
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
                    builder: (context) => const AddProductPage(),
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
              backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
              child: Icon(
                Icons.inventory,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
            title: Text(product.name),
            subtitle: Text('المخزون: ${product.quantity} ${product.baseUnit}'),
            trailing: Icon(
              isSelected ? Icons.check_circle : Icons.add_circle,
              color: isSelected ? Colors.green : Colors.blue,
            ),
            onTap: () {
              setState(() {
                _selectedProductId = product.id;
                _costController.text = product.costPrice?.toStringAsFixed(2) ?? '0.00';
                _qtyController.text = '1';
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildInvoicePreview() {
    final products = context.read<ProductProvider>().products;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text('${_invoiceItems.length} منتج'),
                  backgroundColor: Colors.blue.shade50,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (_invoiceItems.isEmpty)
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
                      Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
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
                  ..._invoiceItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final productId = item['product_id'] as int;
                    
                    Product? product;
                    try {
                      product = products.firstWhere((p) => p.id == productId);
                    } catch (e) {
                      product = null;
                    }
                    
                    final quantity = (item['quantity'] as num).toDouble();
                    final costPrice = (item['cost_price'] as num).toDouble();
                    final subtotal = quantity * costPrice;
                    
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
                              child: Text(product?.name ?? 'غير معروف'),
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
                            onPressed: _isLoading ? null : () => _removeItem(index),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  
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
                            Text(_invoiceItems.length.toString()),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('طريقة الدفع:'),
                            Text(_selectedPaymentType == 'cash' ? 'نقدي' : 'آجل'),
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
                              Formatters.formatCurrency(_invoiceTotal),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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

  Future<void> _createInvoice() async {
    if (_selectedSupplierId == null) {
      _showError('يرجى اختيار المورد أولاً');
      return;
    }

    setState(() => _isCreatingInvoice = true);

    try {
      final purchaseInvoiceProvider = context.read<PurchaseInvoiceProvider>();
      _invoiceId = await purchaseInvoiceProvider.addPurchaseInvoice(
        supplierId: _selectedSupplierId!,
        totalCost: 0,
        paymentType: _selectedPaymentType ?? 'cash',
        note: _noteController.text,
      );

      _showSuccess('تم إنشاء الفاتورة بنجاح');
    } catch (e) {
      _showError('خطأ في إنشاء الفاتورة: $e');
    } finally {
      setState(() => _isCreatingInvoice = false);
    }
  }

  Future<void> _addItem() async {
    if (_invoiceId == null) {
      await _createInvoice();
      if (_invoiceId == null) return;
    }

    if (_selectedProductId == null || 
        _qtyController.text.isEmpty || 
        _costController.text.isEmpty) {
      _showError('يرجى ملء جميع الحقول');
      return;
    }

    final qty = double.tryParse(_qtyController.text);
    final cost = double.tryParse(_costController.text);

    if (qty == null || cost == null || qty <= 0 || cost <= 0) {
      _showError('يرجى إدخال قيم صحيحة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final purchaseItemProvider = context.read<PurchaseItemProvider>();

      await purchaseItemProvider.addPurchaseItem(
        purchaseId: _invoiceId!,
        productId: _selectedProductId!,
        quantity: qty,
        costPrice: cost,
      );

      await _loadInvoiceItems();

      _qtyController.clear();
      _costController.clear();
      _selectedProductId = null;

      _showSuccess('تم إضافة المنتج بنجاح');
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInvoiceItems() async {
    try {
      final purchaseItemProvider = context.read<PurchaseItemProvider>();
      _invoiceItems = await purchaseItemProvider.getPurchaseItems(_invoiceId!);

      _invoiceTotal = _invoiceItems.fold(0.0, (sum, item) {
        final quantity = (item['quantity'] as num).toDouble();
        final costPrice = (item['cost_price'] as num).toDouble();
        return sum + (quantity * costPrice);
      });

      setState(() {});
    } catch (e) {
      _showError('خطأ في تحميل العناصر: $e');
    }
  }

  Future<void> _removeItem(int index) async {
    if (index >= 0 && index < _invoiceItems.length) {
      setState(() => _isLoading = true);

      try {
        final itemId = _invoiceItems[index]['id'] as int;
        final purchaseItemProvider = context.read<PurchaseItemProvider>();

        await purchaseItemProvider.deletePurchaseItem(itemId);

        await _loadInvoiceItems();
        _showSuccess('تم حذف المنتج بنجاح');
      } catch (e) {
        _showError('حدث خطأ أثناء الحذف: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveInvoice() async {
    if (_invoiceItems.isEmpty) {
      _showError('لا يمكن حفظ فاتورة فارغة');
      return;
    }

    setState(() => _isLoading = true);

    _showSuccess('تم حفظ الفاتورة بنجاح رقم #$_invoiceId');

    await Future.delayed(const Duration(seconds: 1));
    _clearInvoice();

    setState(() => _isLoading = false);
  }

  void _clearInvoice() {
    setState(() {
      _invoiceId = null;
      _invoiceItems.clear();
      _invoiceTotal = 0.0;
      _selectedProductId = null;
      _selectedSupplierId = null;
      _noteController.clear();
      _qtyController.clear();
      _costController.clear();
      _searchProductController.clear();
      _searchResults.clear();
    });
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
}