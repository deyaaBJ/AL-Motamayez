import 'dart:async' show Timer;
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/supplier_model.dart';
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _initialLoad = true;
  final Map<int, double> _localBalanceCache = {};
  int? _hoveredRowIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuppliers();
    });
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMoreSuppliers();
    }
  }

  Future<void> _loadSuppliers() async {
    if (!mounted) return;

    try {
      await Provider.of<SupplierProvider>(
        context,
        listen: false,
      ).loadSuppliers();
    } catch (e) {
      log('خطأ في تحميل الموردين: $e');
    } finally {
      if (mounted) {
        setState(() => _initialLoad = false);
      }
    }
  }

  Future<void> _loadMoreSuppliers() async {
    if (!mounted) return;

    final provider = Provider.of<SupplierProvider>(context, listen: false);
    if (provider.hasMore && !provider.isLoading) {
      await provider.loadMoreSuppliers();
    }
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      await Provider.of<SupplierProvider>(
        context,
        listen: false,
      ).searchSuppliers(value);
    });
  }

  Future<void> _refreshSuppliers() async {
    if (!mounted) return;

    await Provider.of<SupplierProvider>(
      context,
      listen: false,
    ).loadSuppliers(searchQuery: _searchController.text);
  }

  Color _getBalanceColor(double balance) {
    if (balance > 0) return Colors.red.shade700;
    if (balance < 0) return Colors.green.shade700;
    return Colors.blue.shade700;
  }

  Color _getBalanceBgColor(double balance) {
    if (balance > 0) return Colors.red.shade50;
    if (balance < 0) return Colors.green.shade50;
    return Colors.blue.shade50;
  }

  String _getBalanceStatus(double balance) {
    if (balance > 0) return 'مستحق للمورد';
    if (balance < 0) return 'مستحق من المورد';
    return 'متعادل';
  }

  void _showSupplierActions(
    BuildContext context,
    Map<String, dynamic> supplier,
  ) {
    final supplierId = supplier['id'] as int;
    final supplierName = supplier['name'] as String;
    final phone = supplier['phone'] as String?;
    final address = supplier['address'] as String?;
    final notes = supplier['notes'] as String?;
    final balance =
        supplier['balance'] != null
            ? (supplier['balance'] as num).toDouble()
            : _localBalanceCache[supplierId] ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      supplierName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (phone != null && phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              phone,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildActionTile(
                      icon: Icons.edit,
                      title: 'تعديل بيانات المورد',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AddEditSupplierPage(
                                  supplier: SupplierModel(
                                    id: supplierId,
                                    name: supplierName,
                                    phone: phone ?? '',
                                    address: address ?? '',
                                    notes: notes ?? '',
                                    balance: balance,
                                  ),
                                ),
                          ),
                        ).then((_) => _refreshSuppliers());
                      },
                    ),
                    _buildActionTile(
                      icon: Icons.receipt_long,
                      title: 'كشف الحساب',
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pop(context);
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
                    ),
                    _buildActionTile(
                      icon: Icons.payment,
                      title: 'تسجيل دفعة',
                      color: Colors.green,
                      onTap: () async {
                        Navigator.pop(context);
                        final newBalance = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AddSupplierPaymentPage(
                                  supplierId: supplierId,
                                  supplierName: supplierName,
                                  currentBalance: balance,
                                ),
                          ),
                        );
                        if (newBalance != null && mounted) {
                          _localBalanceCache[supplierId] = newBalance as double;
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'الموردين',
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.grey.withOpacity(0.2),
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
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
                  'الموردين',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddEditSupplierPage(),
                      ),
                    ).then((_) => _refreshSuppliers());
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('إضافة مورد جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'ابحث عن مورد بالاسم أو رقم الهاتف...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                          : null,
                ),
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: Consumer<SupplierProvider>(
        builder: (context, provider, child) {
          if (_initialLoad && provider.suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue.shade700),
                  const SizedBox(height: 16),
                  const Text(
                    'جاري تحميل الموردين...',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          if (provider.suppliers.isEmpty) {
            return _buildEmptyState(provider.isLoading);
          }

          return RefreshIndicator(
            color: Colors.blue.shade700,
            backgroundColor: Colors.white,
            onRefresh: _refreshSuppliers,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildDataTable(
                          provider.suppliers,
                          constraints.maxWidth,
                        ),
                        if (provider.hasMore)
                          _buildLoadingMoreIndicator(provider.isLoading),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDataTable(
    List<Map<String, dynamic>> suppliers,
    double maxWidth,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'اسم المورد',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: maxWidth > 600 ? 16 : 14,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'رقم الهاتف',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: maxWidth > 600 ? 16 : 14,
                      ),
                    ),
                  ),
                  if (maxWidth > 800)
                    Expanded(
                      flex: 3,
                      child: Text(
                        'العنوان',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'الرصيد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: maxWidth > 600 ? 16 : 14,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'الحالة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: maxWidth > 600 ? 16 : 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 50), // مساحة لزر القائمة
                ],
              ),
            ),
            // Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suppliers.length,
              separatorBuilder:
                  (context, index) => Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                    indent: 16,
                    endIndent: 16,
                  ),
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                final supplierId = supplier['id'] as int;
                final supplierName = supplier['name'] as String;
                final phone = supplier['phone'] as String?;
                final address = supplier['address'] as String?;
                final balance =
                    supplier['balance'] != null
                        ? (supplier['balance'] as num).toDouble()
                        : _localBalanceCache[supplierId] ?? 0.0;

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoveredRowIndex = index),
                  onExit: (_) => setState(() => _hoveredRowIndex = null),
                  child: GestureDetector(
                    onTap: () => _showSupplierActions(context, supplier),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      color:
                          _hoveredRowIndex == index
                              ? Colors.blue.shade50
                              : (index % 2 == 0
                                  ? Colors.white
                                  : Colors.grey.shade50),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplierName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: maxWidth > 600 ? 15 : 14,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (maxWidth <= 800 &&
                                    address != null &&
                                    address.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      address,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              phone ?? '-',
                              style: TextStyle(
                                fontSize: maxWidth > 600 ? 14 : 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          if (maxWidth > 800)
                            Expanded(
                              flex: 3,
                              child: Text(
                                address ?? '-',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getBalanceBgColor(balance),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                Formatters.formatCurrency(balance.abs()),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: maxWidth > 600 ? 14 : 13,
                                  color: _getBalanceColor(balance),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _getBalanceStatus(balance),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: maxWidth > 600 ? 13 : 12,
                                color: _getBalanceColor(balance),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: IconButton(
                              icon: Icon(
                                Icons.more_vert,
                                color: Colors.grey.shade600,
                              ),
                              onPressed:
                                  () => _showSupplierActions(context, supplier),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child:
            isLoading
                ? CircularProgressIndicator(color: Colors.blue.shade700)
                : Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'تم عرض جميع النتائج',
                    style: TextStyle(
                      color: Colors.black,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLoading) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Colors.blue.shade700),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            _searchController.text.isNotEmpty
                ? 'لا توجد نتائج للبحث'
                : 'لا يوجد موردين',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _searchController.text.isNotEmpty
                ? 'حاول البحث باستخدام كلمات أخرى'
                : 'ابدأ بإضافة موردين لإدارة المشتريات',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          if (_searchController.text.isEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEditSupplierPage(),
                  ),
                ).then((_) => _refreshSuppliers());
              },
              icon: const Icon(Icons.add_circle, size: 20),
              label: const Text('إضافة أول مورد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
