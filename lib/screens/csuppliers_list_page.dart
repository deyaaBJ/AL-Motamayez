import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import '../providers/supplier_provider.dart';
import 'add_supplier_page.dart';
import 'supplier_account_statement_page.dart';
import 'add_supplier_payment_page.dart';
import '../utils/formatters.dart';

class SuppliersListPage extends StatefulWidget {
  const SuppliersListPage({super.key});

  @override
  State<SuppliersListPage> createState() => _SuppliersListPageState();
}

class _SuppliersListPageState extends State<SuppliersListPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      await Provider.of<SupplierProvider>(
        context,
        listen: false,
      ).loadSuppliers();
    } catch (e) {
      print('خطأ في تحميل الموردين: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(currentPage: 'الموردين', child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final suppliers = context.watch<SupplierProvider>().suppliers;

    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : suppliers.isEmpty
            ? _buildEmptyState()
            : _buildSuppliersList(suppliers),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'قائمة الموردين',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSupplierPage(),
                  ),
                ).then((_) => _loadSuppliers());
              },
              icon: const Icon(Icons.add),
              label: const Text('إضافة مورد'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد موردين',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'قم بإضافة موردين لإدارة المشتريات',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSupplierPage(),
                  ),
                ).then((_) => _loadSuppliers());
              },
              child: const Text('إضافة أول مورد'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuppliersList(List<Map<String, dynamic>> suppliers) {
    return Expanded(
      child: ListView.builder(
        itemCount: suppliers.length,
        itemBuilder: (context, index) {
          final supplier = suppliers[index];
          return _buildSupplierCard(supplier);
        },
      ),
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> supplier) {
    final supplierId = supplier['id'] as int;
    final supplierName = supplier['name'] as String;
    final phone = supplier['phone'] as String?;

    return FutureBuilder<double>(
      future: Provider.of<SupplierProvider>(
        context,
        listen: false,
      ).getSupplierBalance(supplierId),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0.0;
        final isDebt = balance > 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صف المعلومات الرئيسية
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplierName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (phone != null && phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                phone,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // الرصيد
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDebt ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isDebt
                                  ? Colors.red.shade200
                                  : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        Formatters.formatCurrency(balance.abs()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDebt ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // الأزرار
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => SupplierAccountStatementPage(
                                    supplierId: supplierId,
                                    supplierName: supplierName,
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt),
                        label: const Text('كشف الحساب'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => AddSupplierPaymentPage(
                                    supplierId: supplierId,
                                    supplierName: supplierName,
                                    currentBalance: balance,
                                  ),
                            ),
                          ).then((_) {
                            // إعادة تحميل الرصيد بعد الدفعة
                            setState(() {});
                          });
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('إضافة دفعة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
