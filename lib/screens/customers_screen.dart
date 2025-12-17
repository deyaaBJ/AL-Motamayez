import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/helpers/helpers.dart';
import 'package:shopmate/models/customer.dart';
import 'package:shopmate/providers/DebtProvider.dart';
import 'package:shopmate/providers/customer_provider.dart';
import 'package:shopmate/screens/CustomerDetailsScreen.dart';
import 'package:shopmate/widgets/customer_form_dialog.dart';
import 'package:shopmate/widgets/payment_dialog.dart';
import 'package:shopmate/widgets/quick_payment_dialog.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({Key? key}) : super(key: key);

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showScrollToTop = false;
  final Map<int, double> _customerDebts = {};
  bool _debtsLoaded = false;
  bool _isProcessingAction = false;
  List<Customer> _displayedCustomers = [];

  // للترتيب في الجدول
  String _sortColumn = 'name';
  bool _sortAscending = true;

  // لتتبع الصف المحدد
  int? _selectedRowIndex;

  @override
  void initState() {
    super.initState();
    _loadDataSilently();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDataSilently() async {
    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      await provider.refreshCustomers();

      _updateDisplayedCustomers(provider);

      // تحميل الديون في الخلفية
      _loadCustomerDebtsInBackground();
    } catch (e) {
      print('خطأ في تحميل البيانات: $e');
    }
  }

  Future<void> _loadCustomerDebtsInBackground() async {
    if (_debtsLoaded) return;

    final customers =
        Provider.of<CustomerProvider>(context, listen: false).customers;
    if (customers.isEmpty) return;

    final debtProvider = Provider.of<DebtProvider>(context, listen: false);

    // تحميل الديون بشكل متوازي لتحسين الأداء
    final futures = <Future>[];
    for (final customer in customers) {
      if (customer.id != null && !_customerDebts.containsKey(customer.id)) {
        futures.add(_loadSingleCustomerDebt(customer.id!, debtProvider));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
      _debtsLoaded = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadSingleCustomerDebt(
    int customerId,
    DebtProvider debtProvider,
  ) async {
    try {
      await debtProvider.loadCustomerBalance(customerId);
      _customerDebts[customerId] = debtProvider.totalDebt;
    } catch (e) {
      _customerDebts[customerId] = 0.0;
    }
  }

  void _refreshAllData() {
    _searchController.clear();
    _selectedRowIndex = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataSilently();
    });

    showAppToast(context, 'جاري تحديث البيانات...', ToastType.warning);
  }

  void _updateDisplayedCustomers(CustomerProvider provider) {
    _displayedCustomers = List.from(provider.filteredCustomers);
    _sortCustomers();
  }

  void _sortCustomers() {
    _displayedCustomers.sort((a, b) {
      int compareResult;

      switch (_sortColumn) {
        case 'name':
          compareResult = a.name.compareTo(b.name);
          break;
        case 'phone':
          compareResult = (a.phone ?? '').compareTo(b.phone ?? '');
          break;
        case 'debt':
          final debtA = _customerDebts[a.id!] ?? 0;
          final debtB = _customerDebts[b.id!] ?? 0;
          compareResult = debtA.compareTo(debtB);
          break;
        default:
          compareResult = a.name.compareTo(b.name);
      }

      return _sortAscending ? compareResult : -compareResult;
    });
  }

  void _onSort(String column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }

    _sortCustomers();
    if (mounted) setState(() {});
  }

  void _scrollListener() {
    if (_scrollController.offset >= 400) {
      if (!_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      }
    } else {
      if (_showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      Provider.of<CustomerProvider>(context, listen: false).loadMoreCustomers();
    }
  }

  void _onSearchChanged() {
    Provider.of<CustomerProvider>(
      context,
      listen: false,
    ).searchCustomers(_searchController.text);

    final provider = Provider.of<CustomerProvider>(context, listen: false);
    _updateDisplayedCustomers(provider);
    if (mounted) setState(() {});
  }

  void _addNewCustomer() {
    if (_isProcessingAction) return;
    _isProcessingAction = true;

    showDialog(
      context: context,
      builder:
          (context) => CustomerFormDialog(
            onSave: (customer) async {
              _isProcessingAction = false;
              try {
                await Provider.of<CustomerProvider>(
                  context,
                  listen: false,
                ).addCustomer(customer);

                if (customer.id != null) {
                  final debtProvider = Provider.of<DebtProvider>(
                    context,
                    listen: false,
                  );
                  await debtProvider.loadCustomerBalance(customer.id!);
                  _customerDebts[customer.id!] = debtProvider.totalDebt;
                }

                if (!mounted) return;
                showAppToast(
                  context,
                  'تم إضافة العميل ${customer.name}',
                  ToastType.success,
                );

                _updateDisplayedCustomers(
                  Provider.of<CustomerProvider>(context, listen: false),
                );
                if (mounted) setState(() {});
              } catch (e) {
                if (mounted) {
                  showAppToast(
                    context,
                    'خطأ: ${e.toString()}',
                    ToastType.error,
                  );
                }
              }
            },
          ),
    ).then((_) {
      _isProcessingAction = false;
    });
  }

  void _editCustomer(Customer customer) {
    if (_isProcessingAction) return;
    _isProcessingAction = true;

    showDialog(
      context: context,
      builder:
          (context) => CustomerFormDialog(
            customer: customer,
            onSave: (updatedCustomer) async {
              _isProcessingAction = false;
              try {
                final provider = Provider.of<CustomerProvider>(
                  context,
                  listen: false,
                );
                await provider.updateCustomer(updatedCustomer);

                if (!mounted) return;
                showAppToast(
                  context,
                  'تم تحديث العميل ${updatedCustomer.name}',
                  ToastType.success,
                );

                _updateDisplayedCustomers(provider);
                if (mounted) setState(() {});
              } catch (e) {
                if (mounted) {
                  showAppToast(
                    context,
                    'خطأ: ${e.toString()}',
                    ToastType.error,
                  );
                }
              }
            },
          ),
    ).then((_) {
      _isProcessingAction = false;
    });
  }

  Future<void> _deleteCustomer(Customer customer) async {
    if (_isProcessingAction) return;
    _isProcessingAction = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف العميل ${customer.name}؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await Provider.of<CustomerProvider>(
          context,
          listen: false,
        ).deleteCustomer(customer.id!);

        _customerDebts.remove(customer.id!);

        if (mounted) {
          showAppToast(context, 'تم حذف العميل', ToastType.success);
          _updateDisplayedCustomers(
            Provider.of<CustomerProvider>(context, listen: false),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          showAppToast(context, e.toString(), ToastType.error);
        }
      }
    }

    _isProcessingAction = false;
  }

  void _showPaymentDialog(Customer customer, double currentDebt) {
    QuickPaymentDialog.show(
      context: context,
      customer: customer,
      currentDebt: currentDebt,
      onPayment: (customer, amount, note) async {
        // هنا عملية الدفع الفعلية
        final debtProvider = Provider.of<DebtProvider>(context, listen: false);
        await debtProvider.addPayment(
          customerId: customer.id!,
          amount: amount,
          note: note,
        );
      },
    );
  }

  void _viewCustomerDetails(Customer customer) {
    if (_isProcessingAction) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => CustomerDetailsScreen(
                customer: customer,
                initialBalance: _customerDebts[customer.id!] ?? 0.0,
              ),
        ),
      );
    });
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF6A3093)),
              const SizedBox(width: 8),
              Text(
                'بحث سريع عن العملاء',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو رقم الهاتف...',
              prefixIcon: const Icon(Icons.person_search),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF6A3093),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final totalCustomers = _displayedCustomers.length;
    final totalDebt = _customerDebts.values.fold(
      0.0,
      (sum, debt) => sum + debt,
    );
    final customersWithDebt =
        _customerDebts.values.where((debt) => debt > 0).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.group,
            color: const Color(0xFF6A3093),
            label: 'إجمالي العملاء',
            value: totalCustomers.toString(),
          ),
          _buildStatItem(
            icon: Icons.money,
            color: Colors.red,
            label: 'إجمالي الدين',
            value: '${totalDebt.toStringAsFixed(2)} دينار',
          ),
          _buildStatItem(
            icon: Icons.money_off,
            color: Colors.orange,
            label: 'مدينون',
            value: '$customersWithDebt عميل',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildCustomersTable() {
    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
        if (_displayedCustomers.isEmpty && !provider.isLoading) {
          return _buildEmptyState();
        }

        if (provider.isLoading && _displayedCustomers.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A3093)),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // رأس الجدول
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A3093),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTableHeader(
                      label: 'العميل',
                      column: 'name',
                      width: 3,
                    ),
                    _buildTableHeader(
                      label: 'رقم الهاتف',
                      column: 'phone',
                      width: 2,
                    ),
                    _buildTableHeader(
                      label: 'الدين الإجمالي',
                      column: 'debt',
                      width: 2,
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'الإجراءات',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              // محتوى الجدول
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount:
                      _displayedCustomers.length + (provider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _displayedCustomers.length) {
                      return _buildLoadingIndicator();
                    }

                    final customer = _displayedCustomers[index];
                    return _buildTableRow(customer, index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader({
    required String label,
    required String column,
    required int width,
  }) {
    return Expanded(
      flex: width,
      child: InkWell(
        onTap: () => _onSort(column),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            if (_sortColumn == column)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A3093)),
        ),
      ),
    );
  }

  Widget _buildTableRow(Customer customer, int index) {
    final debt = _customerDebts[customer.id!] ?? 0.0;
    final hasDebt = debt > 0;
    final isEven = index.isEven;
    final isSelected = _selectedRowIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRowIndex = _selectedRowIndex == index ? null : index;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF6A3093).withOpacity(0.05)
                  : isEven
                  ? Colors.white
                  : Colors.grey[50],
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
            left:
                isSelected
                    ? const BorderSide(color: Color(0xFF6A3093), width: 3)
                    : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // العميل
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6A3093), Color(0xFFA044FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          customer.name.substring(0, 1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // رقم الهاتف
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        customer.phone ?? '---',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              customer.phone != null
                                  ? Colors.black
                                  : Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // الدين الإجمالي
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      hasDebt ? Icons.money_off : Icons.check_circle,
                      size: 16,
                      color: hasDebt ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${debt.toStringAsFixed(2)} دينار',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: hasDebt ? Colors.red : Colors.green,
                            ),
                          ),
                          if (hasDebt)
                            Text(
                              'مدين',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.withOpacity(0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // الإجراءات
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // عرض التفاصيل
                    _buildActionButton(
                      icon: Icons.visibility,
                      color: Colors.blue,
                      tooltip: 'عرض التفاصيل',
                      onPressed: () => _viewCustomerDetails(customer),
                    ),
                    const SizedBox(width: 4),
                    // تعديل
                    _buildActionButton(
                      icon: Icons.edit,
                      color: Colors.orange,
                      tooltip: 'تعديل العميل',
                      onPressed: () => _editCustomer(customer),
                    ),
                    const SizedBox(width: 4),
                    // دفعة سريعة
                    if (hasDebt)
                      _buildActionButton(
                        icon: Icons.payment,
                        color: Colors.green,
                        tooltip: 'دفعة سريعة',
                        onPressed: () => _showPaymentDialog(customer, debt),
                      ),
                    if (hasDebt) const SizedBox(width: 4),
                    // حذف
                    _buildActionButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      tooltip: 'حذف العميل',
                      onPressed: () => _deleteCustomer(customer),
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 16, color: color),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا يوجد عملاء',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف عميلاً جديداً بالضغط على زر (+)',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'العملاء',
        showAppBar: true,
        title: 'إدارة العملاء',
        actions: [
          IconButton(
            onPressed: _refreshAllData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث العملاء',
          ),
        ],
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_showScrollToTop)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF6A3093),
                  mini: true,
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Icon(Icons.arrow_upward, color: Colors.white),
                ),
              ),
            FloatingActionButton(
              onPressed: _addNewCustomer,
              backgroundColor: const Color(0xFF6A3093),
              child: const Icon(
                Icons.person_add_alt_1,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeaderSection(),
            _buildStatsSection(),
            const SizedBox(height: 8),
            Text(
              'قائمة العملاء',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildCustomersTable()),
          ],
        ),
      ),
    );
  }
}
