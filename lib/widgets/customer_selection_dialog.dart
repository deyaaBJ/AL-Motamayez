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

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    final provider = Provider.of<CustomerProvider>(context, listen: false);
    await provider
        .fetchCustomers(); // استخدم fetchCustomers بدلاً من loadCustomers
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'اختر الزبون',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: Consumer<CustomerProvider>(
        builder: (context, provider, _) {
          if (_isLoading) {
            return _buildLoadingIndicator();
          }
          return _buildDialogContent(provider);
        },
      ),
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

  Widget _buildDialogContent(CustomerProvider provider) {
    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCustomerDropdown(provider),
          const SizedBox(height: 16),
          _buildAddCustomerButton(provider),
        ],
      ),
    );
  }

  Widget _buildCustomerDropdown(CustomerProvider provider) {
    if (provider.customers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'لا يوجد عملاء مسجلين',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return DropdownButtonFormField<Customer>(
      value: _selectedCustomer,
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
          provider.customers.map((customer) {
            return DropdownMenuItem(
              value: customer,
              child: Text(customer.name, style: const TextStyle(fontSize: 16)),
            );
          }).toList(),
      onChanged: (value) => setState(() => _selectedCustomer = value),
    );
  }

  Widget _buildAddCustomerButton(CustomerProvider provider) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.add, size: 20),
      label: const Text('إضافة زبون جديد', style: TextStyle(fontSize: 14)),
      onPressed: () => _handleAddNewCustomer(provider),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: const BorderSide(color: Colors.blue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _handleAddNewCustomer(CustomerProvider provider) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (context) => CustomerFormDialog(
            onSave: (customer) async {
              await provider.addCustomer(customer);
              _showSuccessSnackBar(customer.name);
              // إعادة فتح dialog اختيار الزبون بعد الإضافة مع تحديث البيانات
              _reopenCustomerSelectionDialog();
            },
          ),
    );
  }

  void _reopenCustomerSelectionDialog() {
    // استخدام Future.delayed لضمان إغلاق الـ Dialog الحالي أولاً
    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        builder:
            (context) => CustomerSelectionDialog(
              onSaleCompleted: widget.onSaleCompleted,
            ),
      );
    });
  }

  void _showSuccessSnackBar(String customerName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إضافة العميل $customerName'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        onPressed: _selectedCustomer == null ? null : () => _completeSale(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: const Text(
          'إتمام البيع',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    ];
  }

  void _completeSale() {
    Navigator.pop(context);
    widget.onSaleCompleted(_selectedCustomer!);
  }
}
