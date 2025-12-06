// screens/customers_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/helpers/helpers.dart';
import 'package:shopmate/providers/settings_provider.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../widgets/customer_form_dialog.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<CustomerProvider>(
        context,
        listen: false,
      ).fetchCustomers(reset: true);
    });

    // إضافة مستمع للتمرير
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(() {
      setState(() {
        _showScrollToTop = _scrollController.offset > 300;
      });
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // تحميل المزيد عند الوصول للنهاية
      Provider.of<CustomerProvider>(context, listen: false).loadMoreCustomers();
    }
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
            onPressed: () {
              // عملية تحديث كاملة
              _searchController.clear();
              Provider.of<CustomerProvider>(
                context,
                listen: false,
              ).refreshCustomers();
            },
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
                Icons.person_add,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeaderSection(),
            Expanded(child: _buildCustomersTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Consumer2<CustomerProvider, SettingsProvider>(
      builder: (context, customerProvider, settingsProvider, _) {
        final currencyName = settingsProvider.currencyName;
        final stats = customerProvider.getCustomerStats();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.all(16),
          child: Column(
            children: [
              // شريط البحث مع معلومات التحميل
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        customerProvider.searchCustomers(value);
                      },
                      decoration: InputDecoration(
                        hintText: '🔍 ابحث عن عميل بالاسم أو الرقم...',
                        filled: true,
                        fillColor: const Color(0xFFF8F5FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    customerProvider.searchCustomers('');
                                  },
                                )
                                : null,
                      ),
                    ),
                  ),
                  if (customerProvider.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // الإحصائيات
              Row(
                children: [
                  _buildStatCard(
                    'العملاء المحملين',
                    '${stats['totalCustomers']}',
                    Icons.people,
                    const Color(0xFF6A3093),
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    'إجمالي الدين',
                    '${stats['totalDebt'].toStringAsFixed(2)} $currencyName',
                    Icons.money_off,
                    const Color(0xFFFF6B35),
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    'إجمالي النقدي',
                    '${stats['totalCash'].toStringAsFixed(2)} $currencyName',
                    Icons.attach_money,
                    const Color(0xFF34C759),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomersTable() {
    return Consumer<CustomerProvider>(
      builder: (context, provider, _) {
        final customers = provider.filteredCustomers;
        final isLoading = provider.isLoading;
        final hasMore = provider.hasMore;

        if (customers.isEmpty && isLoading) {
          return _buildLoadingIndicator();
        }

        if (customers.isEmpty) {
          return _buildEmptyState(provider.searchQuery.isNotEmpty);
        }

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (scrollNotification is ScrollEndNotification &&
                    _scrollController.position.pixels ==
                        _scrollController.position.maxScrollExtent &&
                    hasMore &&
                    !isLoading) {
                  provider.loadMoreCustomers();
                }
                return false;
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Scrollbar(
                  thickness: 6,
                  radius: const Radius.circular(3),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 60,
                        dataRowHeight: 65,
                        horizontalMargin: 20,
                        columnSpacing: 30,
                        dividerThickness: 1.2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        headingRowColor:
                            MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) =>
                                  const Color(0xFF6A3093).withOpacity(0.08),
                            ),
                        columns: const [
                          DataColumn(
                            label: Expanded(
                              child: Text(
                                'اسم العميل',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A1C6D),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text(
                                'رقم الهاتف',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A1C6D),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text(
                                'إجمالي الدين',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A1C6D),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text(
                                'إجمالي النقدي',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A1C6D),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text(
                                'الإجراءات',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A1C6D),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                        rows: [
                          ...customers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final customer = entry.value;
                            final isEven = index % 2 == 0;

                            return DataRow(
                              color: MaterialStateProperty.resolveWith<Color?>((
                                Set<MaterialState> states,
                              ) {
                                return isEven
                                    ? const Color(0xFFF8F5FF).withOpacity(0.5)
                                    : Colors.white;
                              }),
                              cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF6A3093,
                                            ).withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: const Color(0xFF6A3093),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                customer.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: Color(0xFF2D1B42),
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
                                DataCell(
                                  Center(
                                    child: Text(
                                      customer.phone ?? '-',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            customer.phone != null
                                                ? const Color(0xFF4A1C6D)
                                                : Colors.grey,
                                        fontWeight:
                                            customer.phone != null
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            customer.debt > 0
                                                ? const Color(
                                                  0xFFFF6B35,
                                                ).withOpacity(0.1)
                                                : const Color(
                                                  0xFF34C759,
                                                ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              customer.debt > 0
                                                  ? const Color(
                                                    0xFFFF6B35,
                                                  ).withOpacity(0.3)
                                                  : const Color(
                                                    0xFF34C759,
                                                  ).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            customer.debt > 0
                                                ? Icons.money_off
                                                : Icons.check_circle,
                                            size: 16,
                                            color:
                                                customer.debt > 0
                                                    ? const Color(0xFFFF6B35)
                                                    : const Color(0xFF34C759),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            customer.debt.toStringAsFixed(2),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color:
                                                  customer.debt > 0
                                                      ? const Color(0xFFFF6B35)
                                                      : const Color(0xFF34C759),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF4A90E2,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF4A90E2,
                                          ).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(width: 6),
                                          Text(
                                            customer.totalCash.toStringAsFixed(
                                              2,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Color(0xFF4A90E2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // زر التعديل
                                          Container(
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF4A90E2,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 18,
                                              ),
                                              color: const Color(0xFF4A90E2),
                                              onPressed:
                                                  () => _editCustomer(customer),
                                              padding: const EdgeInsets.all(6),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // زر الحذف
                                          Container(
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFFF6B35,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                size: 18,
                                              ),
                                              color: const Color(0xFFFF6B35),
                                              onPressed:
                                                  () =>
                                                      _deleteCustomer(customer),
                                              padding: const EdgeInsets.all(6),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ),

                                          // زر تسديد الدين (يظهر فقط إذا كان هناك دين)
                                          if (customer.debt > 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF34C759,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.payment,
                                                  size: 18,
                                                ),
                                                color: const Color(0xFF34C759),
                                                onPressed:
                                                    () => _showPaymentDialog(
                                                      customer,
                                                      provider,
                                                    ),
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),

                          // صف التحميل الإضافي
                          if (isLoading && hasMore)
                            DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // زر الانتقال للأعلى
            if (_showScrollToTop)
              Positioned(
                bottom: 20,
                left: 20,
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
          ],
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('جاري تحميل العملاء...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'لم يتم العثور على عملاء' : 'لا توجد عملاء',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Consumer<CustomerProvider>(
            builder: (context, provider, _) {
              if (provider.hasMore && !isSearching) {
                return ElevatedButton(
                  onPressed: () => provider.fetchCustomers(reset: true),
                  child: const Text('تحميل العملاء'),
                );
              }
              return Text(
                isSearching
                    ? 'جرب مصطلحات بحث أخرى'
                    : 'انقر على + لإضافة عميل جديد',
                style: const TextStyle(color: Colors.grey),
              );
            },
          ),
        ],
      ),
    );
  }

  void _addNewCustomer() {
    showDialog(
      context: context,
      builder:
          (context) => CustomerFormDialog(
            onSave: (customer) async {
              await Provider.of<CustomerProvider>(
                context,
                listen: false,
              ).addCustomer(customer);

              if (!mounted) return;
              showAppToast(
                context,
                'تم إضافة العميل ${customer.name}',
                ToastType.success,
              );
            },
          ),
    );
  }

  void _editCustomer(Customer customer) {
    showDialog(
      context: context,
      builder:
          (context) => CustomerFormDialog(
            customer: customer,
            onSave: (updatedCustomer) async {
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
            },
          ),
    );
  }

  void _deleteCustomer(Customer customer) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('حذف العميل'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning, size: 60, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'هل أنت متأكد من حذف العميل "${customer.name}"؟',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                if (customer.debt > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ملاحظة: هذا العميل عليه دين بقيمة ${customer.debt.toStringAsFixed(2)} ${settings.currencyName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final provider = Provider.of<CustomerProvider>(
                    context,
                    listen: false,
                  );

                  try {
                    await provider.deleteCustomer(customer.id!);
                    if (!mounted) return;
                    Navigator.pop(context);
                    showAppToast(
                      context,
                      'تم حذف العميل ${customer.name}',
                      ToastType.error,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    showAppToast(context, e.toString(), ToastType.error);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  void _showPaymentDialog(Customer customer, CustomerProvider provider) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currencyName = settings.currencyName;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('تسديد دين'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('العميل: ${customer.name}'),
                Text(
                  'الدين الحالي: ${customer.debt.toStringAsFixed(2)} $currencyName',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المسدد',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (amount > 0 && amount <= customer.debt) {
                    try {
                      await provider.payDebt(customer.id!, amount, 'cash');
                      if (!mounted) return;
                      Navigator.pop(context);
                      showAppToast(
                        context,
                        'تم تسديد ${amount.toStringAsFixed(2)} $currencyName للعميل ${customer.name}',
                        ToastType.success,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      showAppToast(context, e.toString(), ToastType.error);
                    }
                  } else {
                    if (!mounted) return;
                    showAppToast(context, 'المبلغ غير صالح', ToastType.error);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                ),
                child: const Text(
                  'تسديد',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
