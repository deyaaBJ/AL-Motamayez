import 'dart:async' show Timer;

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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _initialLoad = true;
  final Map<int, double> _localBalanceCache = {};

  @override
  void initState() {
    super.initState();
    // تأجيل تحميل البيانات حتى اكتمال بناء الويدجت
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
      print('خطأ في تحميل الموردين: $e');
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

  Widget _buildSupplierCard(Map<String, dynamic> supplier) {
    final supplierId = supplier['id'] as int;
    final supplierName = supplier['name'] as String;
    final phone = supplier['phone'] as String?;
    final address = supplier['address'] as String?;
    final notes = supplier['notes'] as String?;

    final balance =
        supplier['balance'] != null
            ? (supplier['balance'] as num).toDouble()
            : _localBalanceCache[supplierId] ?? 0.0;

    final isWeOweSupplier = balance > 0;
    final isSupplierOwesUs = balance < 0;
    final isNoDebt = balance == 0;

    String getStatusText() {
      if (isWeOweSupplier) {
        return 'مستحق للمورد';
      } else if (isSupplierOwesUs) {
        return 'مستحق من المورد';
      } else {
        return 'صافي الرصيد';
      }
    }

    String getExplanationText() {
      if (isWeOweSupplier) {
        return 'دين علينا';
      } else if (isSupplierOwesUs) {
        return 'دين لنا';
      } else {
        return 'الحسابات متساوية';
      }
    }

    Color getStatusColor() {
      if (isWeOweSupplier) {
        return Colors.red.shade700;
      } else if (isSupplierOwesUs) {
        return Colors.green.shade700;
      } else {
        return Colors.blue.shade700;
      }
    }

    Color getBackgroundColor() {
      if (isWeOweSupplier) {
        return Colors.red.shade50;
      } else if (isSupplierOwesUs) {
        return Colors.green.shade50;
      } else {
        return Colors.blue.shade50;
      }
    }

    Color getBorderColor() {
      if (isWeOweSupplier) {
        return Colors.red.shade300;
      } else if (isSupplierOwesUs) {
        return Colors.green.shade300;
      } else {
        return Colors.blue.shade300;
      }
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shadowColor: Colors.grey.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صف العنوان والرصيد
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: Colors.black,
                        ),
                      ),
                      if (phone != null && phone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                phone,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: getBackgroundColor(),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: getBorderColor(), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        getStatusText(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: getStatusColor(),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // المبلغ
                      Text(
                        Formatters.formatCurrency(balance.abs()),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: getStatusColor(),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // التوضيح
                      Text(
                        getExplanationText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: getStatusColor().withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // العنوان
            if (address != null && address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),

            // الملاحظات
            if (notes != null && notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        notes,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // الأزرار
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
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
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('كشف الحساب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.blue.shade200, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
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
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('تسجيل دفعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
                        builder: (context) => const AddSupplierPage(),
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
                  hintText: 'ابحث عن مورد بالاسم...',
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
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: provider.suppliers.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < provider.suppliers.length) {
                  return _buildSupplierCard(provider.suppliers[index]);
                } else {
                  return _buildLoadingMoreIndicator(provider.isLoading);
                }
              },
            ),
          );
        },
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
                    builder: (context) => const AddSupplierPage(),
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
