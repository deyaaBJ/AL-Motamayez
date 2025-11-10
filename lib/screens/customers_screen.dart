import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/models/customer.dart';
import 'package:shopmate/providers/customer_provider.dart';
import 'package:shopmate/widgets/customer_form_dialog.dart';
import 'package:shopmate/widgets/customer_item.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final List<Customer> _customers = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Customer> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;

    return _customers.where((customer) {
      return customer.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          customer.phone.contains(_searchQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<CustomerProvider>(context, listen: false).fetchCustomers();
    });
  }

  final CustomerProvider _customer = CustomerProvider();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // شريط البحث
          _buildSearchBar(),

          // قائمة العملاء
          Expanded(child: _buildCustomersList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewCustomer,
        backgroundColor: const Color(0xFF8B5FBF),
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
        'العملاء',
        style: TextStyle(
          color: Color(0xFF6A3093),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.transparent,
      child: TextField(
        onChanged: (value) {
          final provider = Provider.of<CustomerProvider>(
            context,
            listen: false,
          );
          provider.searchCustomers(value);
        },
        decoration: InputDecoration(
          hintText: '🔍 ابحث عن عميل...',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomersList() {
    return Consumer<CustomerProvider>(
      builder: (context, provider, _) {
        final customers = provider.customers;

        if (customers.isEmpty) {
          return _buildEmptyState();
        }

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return CustomerItem(
                customer: customer,
                onEdit: () => _editCustomer(customer),
                onDelete: () => _deleteCustomer(customer),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'لا توجد عملاء',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'انقر على + لإضافة عميل جديد'
                : 'لم يتم العثور على عملاء مطابقين',
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

              updatedCustomer.id = customer.id;

              await provider.updateCustomer(updatedCustomer);

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

                  await provider.deleteCustomer(customer.id!);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم حذف العميل ${customer.name}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف'),
              ),
            ],
          ),
    );
  }
}
