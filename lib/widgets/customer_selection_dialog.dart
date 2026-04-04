import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import 'customer_form_dialog.dart';

class CustomerSelectionDialog extends StatefulWidget {
  final Function(Customer) onSaleCompleted;

  const CustomerSelectionDialog({super.key, required this.onSaleCompleted});

  @override
  State<CustomerSelectionDialog> createState() =>
      _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<CustomerSelectionDialog> {
  Customer? _selectedCustomer;
  bool _isLoading = true;
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      await provider.fetchCustomers();
      setState(() {
        _customers = provider.customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // يمكن إضافة معالجة الخطأ هنا
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'اختر الزبون للبيع الآجل',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: _isLoading ? _buildLoadingIndicator() : _buildDialogContent(),
      actions: _buildDialogActions(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل العملاء...'),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogContent() {
    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCustomerDropdown(),
          const SizedBox(height: 16),
          _buildAddCustomerButton(),
        ],
      ),
    );
  }

  Widget _buildCustomerDropdown() {
    if (_customers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'لا يوجد عملاء مسجلين',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return DropdownButtonFormField<Customer>(
      initialValue: _selectedCustomer,
      decoration: InputDecoration(
        labelText: 'الزبون',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      hint: const Text('اختر زبون'),
      isExpanded: true,
      items:
          _customers.map((customer) {
            return DropdownMenuItem(
              value: customer,
              child: Text(customer.name, style: const TextStyle(fontSize: 16)),
            );
          }).toList(),
      onChanged: (value) => setState(() => _selectedCustomer = value),
    );
  }

  Widget _buildAddCustomerButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.add, size: 20),
      label: const Text('إضافة زبون جديد', style: TextStyle(fontSize: 14)),
      onPressed: () => _handleAddNewCustomer(),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: const BorderSide(color: Colors.blue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _handleAddNewCustomer() {
    showDialog(
      context: context,
      builder:
          (context) => CustomerFormDialog(
            onSave: (customer) async {
              try {
                final provider = Provider.of<CustomerProvider>(
                  context,
                  listen: false,
                );
                await provider.addCustomer(customer);
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
                await _fetchCustomers();

                setState(() {
                  _selectedCustomer = customer;
                });
              } catch (e) {
                // معالجة الخطأ هنا
              }
            },
          ),
    );
  }

  List<Widget> _buildDialogActions() {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text(
          'إلغاء',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
      ElevatedButton(
        onPressed: _selectedCustomer == null ? null : _completeSelection,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: const Text(
          'اختيار',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    ];
  }

  void _completeSelection() {
    Navigator.pop(context, _selectedCustomer);
  }
}
