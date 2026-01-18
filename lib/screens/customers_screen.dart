import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/models/customer.dart';
import 'package:motamayez/providers/DebtProvider.dart';
import 'package:motamayez/providers/customer_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/screens/CustomerDetailsScreen.dart';
import 'package:motamayez/widgets/customer_form_dialog.dart';
import 'package:motamayez/widgets/quick_payment_dialog.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showScrollToTop = false;
  final Map<int, double> _customerDebts = {};
  bool _isProcessingAction = false;

  // للترتيب في الجدول
  String _sortColumn = 'name';
  bool _sortAscending = true;

  // لتتبع الصف المحدد
  int? _selectedRowIndex;

  Timer? _searchDebounceTimer;

  bool _initialDataLoaded = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);

    // تحميل البيانات بعد تأخير قصير
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _loadInitialData();
      }
    });
  }

  Future<void> _loadInitialData() async {
    if (_initialDataLoaded || _isDisposed) return;

    try {
      final provider = context.read<CustomerProvider>();

      // تحميل البيانات الأولية
      await provider.fetchCustomers(reset: true);
      _initialDataLoaded = true;

      // تحميل الديون فوراً
      if (mounted) {
        await _loadAllCustomerDebts();
      }
    } catch (e) {
      log('خطأ في تحميل البيانات الأولية: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCustomerDebts() async {
    final provider = context.read<CustomerProvider>();
    final customers = provider.displayedCustomers;

    if (customers.isEmpty) return;

    final debtProvider = context.read<DebtProvider>();

    // مسح الديون القديمة
    _customerDebts.clear();

    // تحميل ديون جميع العملاء
    for (final customer in customers) {
      if (customer.id != null) {
        await _loadSingleCustomerDebt(customer.id!, debtProvider);
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadSingleCustomerDebt(
    int customerId,
    DebtProvider debtProvider,
  ) async {
    try {
      final debt = await debtProvider.getTotalDebtByCustomerId(customerId);
      _customerDebts[customerId] = debt;
    } catch (e) {
      log('خطأ في تحميل دين العميل $customerId: $e');
      _customerDebts[customerId] = 0.0;
    }
  }

  // تحديث جميع البيانات
  void _refreshAllData() {
    final provider = context.read<CustomerProvider>();

    // إلغاء البحث
    provider.cancelSearch();
    _searchController.clear();

    // إعادة تحميل البيانات
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        _initialDataLoaded = false;
        await _loadInitialData();

        if (mounted) {
          showAppToast(context, 'تم تحديث البيانات بنجاح', ToastType.success);
        }
      } catch (e) {
        if (mounted) {
          showAppToast(context, 'خطأ في تحديث البيانات: $e', ToastType.error);
        }
      }
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  void _scrollListener() {
    // التحكم في زر التمرير للأعلى
    if (_scrollController.offset >= 400) {
      if (!_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      }
    } else {
      if (_showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    }

    // تحميل المزيد عند الوصول للأسفل
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreCustomers();
    }
  }

  Future<void> _loadMoreCustomers() async {
    final provider = context.read<CustomerProvider>();

    if (!provider.isLoading && provider.hasMore) {
      log('تحميل المزيد من العملاء...');

      await provider.loadMoreCustomers();

      // تحميل ديون العملاء الجدد
      final customers = provider.displayedCustomers;
      final newCustomers =
          customers
              .where((c) => c.id != null && !_customerDebts.containsKey(c.id))
              .toList();

      if (newCustomers.isNotEmpty) {
        final debtProvider = context.read<DebtProvider>();
        for (final customer in newCustomers) {
          await _loadSingleCustomerDebt(customer.id!, debtProvider);
        }

        if (mounted) setState(() {});
      }
    }
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    final provider = context.read<CustomerProvider>();

    if (query.isEmpty) {
      provider.cancelSearch();
      await _loadAllCustomerDebts();
      return;
    }

    try {
      log('بدء البحث في الواجهة عن: "$query"');
      await provider.searchCustomers(query);
      await _loadAllCustomerDebts();

      if (mounted) setState(() {});

      if (provider.displayedCustomers.isEmpty && mounted) {
        showAppToast(
          context,
          'لم يتم العثور على نتائج لـ "$query"',
          ToastType.warning,
        );
      }
    } catch (e) {
      log('خطأ في البحث: $e');
      if (mounted) {
        showAppToast(context, 'خطأ في البحث: ${e.toString()}', ToastType.error);
      }
    }
  }

  void _addNewCustomer() {
    if (_isProcessingAction) return;
    _isProcessingAction = true;

    showDialog(
      context: context,
      builder:
          (context) => CustomerFormDialog(
            onSave: (customer) async {
              try {
                final provider = context.read<CustomerProvider>();
                final newCustomer = await provider.addCustomer(customer);

                if (mounted) {
                  setState(() {
                    if (newCustomer.id != null) {
                      _customerDebts[newCustomer.id!] = 0.0;
                    }
                  });

                  showAppToast(
                    context,
                    'تم إضافة العميل ${newCustomer.name}',
                    ToastType.success,
                  );
                }
              } catch (e) {
                if (mounted) {
                  showAppToast(
                    context,
                    'خطأ: ${e.toString()}',
                    ToastType.error,
                  );
                }
              } finally {
                _isProcessingAction = false;
              }
            },
          ),
    ).then((_) {
      if (!_isDisposed) {
        _isProcessingAction = false;
      }
    });
  }

  // دالة لترتيب العملاء
  List<Customer> _getSortedCustomers(List<Customer> customers) {
    List<Customer> sorted = List.from(customers);

    sorted.sort((a, b) {
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

    return sorted;
  }

  Widget _buildHeaderSection() {
    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
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
                  const Spacer(),
                  if (provider.isSearching && provider.isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 14,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'جارٍ البحث...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم...',
                        prefixIcon: const Icon(Icons.person_search),
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
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'إعادة تحميل',
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A3093).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF6A3093).withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        onPressed: _refreshAllData,
                        icon: const Icon(
                          Icons.refresh,
                          color: Color(0xFF6A3093),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (provider.isSearching && _searchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'جاري البحث عن "${_searchController.text}"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
        final customers = provider.displayedCustomers;
        final totalCustomers = customers.length;
        final totalDebt = customers.fold(
          0.0,
          (sum, customer) =>
              sum +
              (_customerDebts[customer.id!] ?? 0).clamp(0, double.infinity),
        );
        final totalCredit = customers.fold(
          0.0,
          (sum, customer) =>
              sum +
              (_customerDebts[customer.id!] ?? 0)
                  .clamp(double.negativeInfinity, 0)
                  .abs(),
        );
        final customersWithDebt =
            customers
                .where((customer) => (_customerDebts[customer.id!] ?? 0) > 0)
                .length;

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
                label: provider.isSearching ? 'النتائج' : 'إجمالي العملاء',
                value: totalCustomers.toString(),
              ),
              _buildStatItem(
                icon: Icons.money_off,
                color: Colors.red,
                label: 'إجمالي الدين',
                value: '${totalDebt.toStringAsFixed(2)} د',
              ),
              _buildStatItem(
                icon: Icons.credit_card,
                color: Colors.green,
                label: 'إجمالي الرصيد',
                value: '${totalCredit.toStringAsFixed(2)} د',
              ),
              _buildStatItem(
                icon: Icons.person,
                color: Colors.orange,
                label: 'مدينون',
                value: '$customersWithDebt',
              ),
            ],
          ),
        );
      },
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
        final customers = provider.displayedCustomers;
        final sortedCustomers = _getSortedCustomers(customers);

        final shouldShowLoadMore = provider.hasMore && !provider.isLoading;

        if (sortedCustomers.isEmpty && !provider.isLoading) {
          return _buildEmptyState(provider.isSearching);
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
                      label: 'الرصيد',
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
                  key: const ValueKey('customers_screen_list'),
                  controller: _scrollController,
                  itemCount:
                      sortedCustomers.length +
                      (provider.isLoading ? 1 : 0) +
                      (shouldShowLoadMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == sortedCustomers.length) {
                      if (provider.isLoading) {
                        return _buildLoadingIndicator();
                      } else if (shouldShowLoadMore) {
                        return _buildLoadMoreButton();
                      } else {
                        return const SizedBox.shrink();
                      }
                    }

                    final customer = sortedCustomers[index];
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

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _loadMoreCustomers,
          icon: const Icon(Icons.keyboard_arrow_down),
          label: const Text('تحميل المزيد'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A3093).withOpacity(0.1),
            foregroundColor: const Color(0xFF6A3093),
          ),
        ),
      ),
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

  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد عملاء',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'لم يتم العثور على نتائج للبحث'
                : 'ابدأ بإضافة عميل جديد',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Customer customer, int index) {
    final settings = context.read<SettingsProvider>();
    final currencyName = settings.currencyName;

    double debt = _customerDebts[customer.id!] ?? 0.0;
    final hasDebt = debt > 0;
    final hasCredit = debt < 0;
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
                      hasDebt
                          ? Icons.arrow_upward
                          : hasCredit
                          ? Icons.arrow_downward
                          : Icons.check_circle,
                      size: 16,
                      color:
                          hasDebt
                              ? Colors.red
                              : hasCredit
                              ? Colors.green
                              : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${debt.abs().toStringAsFixed(2)} $currencyName',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  hasDebt
                                      ? Colors.red
                                      : hasCredit
                                      ? Colors.green
                                      : Colors.grey,
                            ),
                          ),
                          Text(
                            hasDebt
                                ? 'دين'
                                : hasCredit
                                ? 'رصيد'
                                : 'متوازن',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  hasDebt
                                      ? Colors.red.withOpacity(0.8)
                                      : hasCredit
                                      ? Colors.green.withOpacity(0.8)
                                      : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      icon: Icons.visibility,
                      color: Colors.blue,
                      tooltip: 'عرض التفاصيل',
                      onPressed: () => _viewCustomerDetails(customer),
                    ),
                    const SizedBox(width: 4),
                    _buildActionButton(
                      icon: Icons.edit,
                      color: Colors.orange,
                      tooltip: 'تعديل العميل',
                      onPressed: () => _editCustomer(customer),
                    ),
                    const SizedBox(width: 4),
                    if (hasDebt) ...[
                      _buildActionButton(
                        icon: Icons.payment,
                        color: Colors.green,
                        tooltip: 'دفعة سريعة',
                        onPressed: () => _showPaymentDialog(customer, debt),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (hasCredit) ...[
                      _buildActionButton(
                        icon: Icons.credit_score,
                        color: Colors.purple,
                        tooltip: 'سداد رصيد',
                        onPressed:
                            () => _showCreditPaymentDialog(customer, debt),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (debt == 0)
                      _buildActionButton(
                        icon: Icons.delete,
                        color: Colors.red,
                        tooltip: 'حذف العميل',
                        onPressed: () => _deleteCustomer(customer),
                      )
                    else
                      Tooltip(
                        message:
                            debt > 0
                                ? 'لا يمكن الحذف - العميل مدين'
                                : 'لا يمكن الحذف - العميل لديه رصيد',
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.block,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
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

  void _viewCustomerDetails(Customer customer) {
    if (_isProcessingAction) return;

    final currentDebt = _customerDebts[customer.id!] ?? 0.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CustomerDetailsScreen(
              customer: customer,
              initialBalance: currentDebt,
            ),
      ),
    ).then((value) {
      _refreshCustomerDebt(customer.id!);
    });
  }

  Future<void> _refreshCustomerDebt(int customerId) async {
    try {
      final debtProvider = context.read<DebtProvider>();
      final updatedDebt = await debtProvider.getTotalDebtByCustomerId(
        customerId,
      );
      _customerDebts[customerId] = updatedDebt;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      log('خطأ في تحديث دين العميل $customerId: $e');
    }
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
                final provider = context.read<CustomerProvider>();
                await provider.updateCustomer(updatedCustomer);

                if (mounted) {
                  showAppToast(
                    context,
                    'تم تحديث العميل ${updatedCustomer.name}',
                    ToastType.success,
                  );
                  setState(() {});
                }
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
    final settings = context.read<SettingsProvider>();
    final currencyName = settings.currencyName;
    if (_isProcessingAction) return;
    _isProcessingAction = true;

    try {
      final debtProvider = context.read<DebtProvider>();
      final customerBalance = await debtProvider.getTotalDebtByCustomerId(
        customer.id!,
      );

      if (customerBalance != 0) {
        final balanceType = customerBalance > 0 ? 'دين' : 'رصيد';
        final balanceText = customerBalance.abs().toStringAsFixed(2);

        if (mounted) {
          showAppToast(
            context,
            '❌ لا يمكن حذف العميل ${customer.name}\nلأنه لديه $balanceType بقيمة $balanceText $currencyName',
            ToastType.error,
          );
        }

        _isProcessingAction = false;
        return;
      }

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
        await context.read<CustomerProvider>().deleteCustomer(customer.id!);

        _customerDebts.remove(customer.id!);

        if (mounted) {
          showAppToast(
            context,
            '✅ تم حذف العميل ${customer.name}',
            ToastType.success,
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          '❌ خطأ في الحذف: ${e.toString()}',
          ToastType.error,
        );
      }
    } finally {
      _isProcessingAction = false;
    }
  }

  void _showCreditPaymentDialog(Customer customer, double currentBalance) {
    QuickPaymentDialog.showWithdrawal(
      context: context,
      customer: customer,
      currentBalance: currentBalance,
      onWithdrawal: (customer, amount, note) async {
        final debtProvider = context.read<DebtProvider>();

        try {
          await debtProvider.addWithdrawal(
            customerId: customer.id!,
            amount: amount,
            note: note,
          );

          final updatedDebt = await debtProvider.getTotalDebtByCustomerId(
            customer.id!,
          );
          _customerDebts[customer.id!] = updatedDebt;

          if (mounted) {
            setState(() {});
            showAppToast(context, 'تم صرف الرصيد بنجاح', ToastType.success);
          }
        } catch (e) {
          if (mounted) {
            showAppToast(context, 'خطأ في صرف الرصيد: $e', ToastType.error);
          }
        }
      },
    );
  }

  void _showPaymentDialog(Customer customer, double currentDebt) {
    QuickPaymentDialog.showPayment(
      context: context,
      customer: customer,
      currentDebt: currentDebt,
      onPayment: (customer, amount, note) async {
        final debtProvider = context.read<DebtProvider>();

        try {
          await debtProvider.addPayment(
            customerId: customer.id!,
            amount: amount,
            note: note,
          );

          final updatedDebt = await debtProvider.getTotalDebtByCustomerId(
            customer.id!,
          );
          _customerDebts[customer.id!] = updatedDebt;

          if (mounted) {
            setState(() {});
            showAppToast(context, 'تم تسديد الدفعة بنجاح', ToastType.success);
          }
        } catch (e) {
          if (mounted) {
            showAppToast(context, 'خطأ في التسديد: $e', ToastType.error);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'العملاء',
        showAppBar: false,
        floatingActionButton: FloatingActionButton(
          heroTag: 'add_customer_fab', // علامة فريدة للزر العائم
          onPressed: _addNewCustomer,
          backgroundColor: const Color(0xFF6A3093),
          child: const Icon(
            Icons.person_add_alt_1,
            color: Colors.white,
            size: 28,
          ),
        ),
        child: Column(
          children: [
            _buildHeaderSection(),
            _buildStatsSection(),
            const SizedBox(height: 8),
            Consumer<CustomerProvider>(
              builder: (context, provider, child) {
                return Text(
                  provider.isSearching ? 'نتائج البحث' : 'قائمة العملاء',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildCustomersTable()),
          ],
        ),
      ),
    );
  }
}
