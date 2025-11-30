// screens/customers_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<CustomerProvider>(context, listen: false).fetchCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // شريط البحث والإحصائيات
          _buildHeaderSection(),

          // جدول العملاء
          Expanded(child: _buildCustomersTable()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewCustomer,
        backgroundColor: const Color(0xFF6A3093),
        child: const Icon(Icons.person_add, color: Colors.white, size: 28),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF6A3093)),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'إدارة العملاء',
        style: TextStyle(
          color: Color(0xFF6A3093),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF6A3093)),
          onPressed: () {
            Provider.of<CustomerProvider>(
              context,
              listen: false,
            ).fetchCustomers();
          },
        ),
      ],
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
              // شريط البحث
              TextField(
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
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              customerProvider.searchCustomers('');
                            },
                          )
                          : null,
                ),
              ),
              const SizedBox(height: 16),

              // الإحصائيات
              Row(
                children: [
                  _buildStatCard(
                    'إجمالي العملاء',
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

        if (customers.isEmpty) {
          return _buildEmptyState(provider.searchQuery.isNotEmpty);
        }

        return Container(
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
                  headingRowColor: MaterialStateProperty.resolveWith<Color?>(
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
                  rows:
                      customers.asMap().entries.map((entry) {
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
                                        customer.totalCash.toStringAsFixed(2),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                          constraints: const BoxConstraints(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // زر الحذف
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFFF6B35,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 18,
                                          ),
                                          color: const Color(0xFFFF6B35),
                                          onPressed:
                                              () => _deleteCustomer(customer),
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
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
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
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
                ),
              ),
            ),
          ),
        );
      },
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
          Text(
            isSearching
                ? 'جرب مصطلحات بحث أخرى'
                : 'انقر على + لإضافة عميل جديد',
            style: const TextStyle(color: Colors.grey),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إضافة العميل ${customer.name}'),
                  backgroundColor: Colors.green,
                ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم تحديث العميل ${updatedCustomer.name}'),
                  backgroundColor: Colors.blue,
                ),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم حذف العميل ${customer.name}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                      ),
                    );
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم تسديد ${amount.toStringAsFixed(2)} $currencyName للعميل ${customer.name}',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('المبلغ غير صالح'),
                        backgroundColor: Colors.red,
                      ),
                    );
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
    _searchController.dispose();
    super.dispose();
  }
}
