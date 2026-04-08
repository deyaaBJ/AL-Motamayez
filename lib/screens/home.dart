import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/providers/sales_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/providers/batch_provider.dart';
import 'package:motamayez/utils/app_logger.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _expiredBatches = 0;
  int _expiringIn7DaysBatches = 0;
  bool _isLoading = true;
  String _userName = 'المستخدم';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      await Future.wait([
        salesProvider.loadTodaySalesCount(),
        productProvider.loadTotalProducts(),
        settings.loadSettings(),
      ]);

      await productProvider.loadStockCounts(settings.lowStockThreshold);
      await _loadUserName();
      await _loadBatchAlerts();
    } catch (e) {
      appLog('⚠️ خطأ في تحميل البيانات: $e', name: 'MainScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserName() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (mounted) {
        setState(() {
          _userName = user?['name'] ?? 'المستخدم';
        });
      }
    } catch (e) {
      appLog('⚠️ خطأ في تحميل اسم المستخدم: $e', name: 'MainScreen');
    }
  }

  Future<void> _loadBatchAlerts() async {
    try {
      final batchProvider = Provider.of<BatchProvider>(context, listen: false);
      final alerts = await batchProvider.getBatchesAlerts();

      if (mounted) {
        setState(() {
          _expiredBatches = alerts['expired'] ?? 0;
          _expiringIn7DaysBatches = alerts['expiring_7_days'] ?? 0;
        });
      }
    } catch (e) {
      appLog('⚠️ خطأ في تحميل إشعارات الدفعات: $e', name: 'MainScreen');
    }
  }

  void _goToBatchesWithFilter(String filterType) {
    final batchProvider = Provider.of<BatchProvider>(context, listen: false);
    batchProvider.loadBatchesWithFilter(filterType);
    Navigator.pushNamed(context, '/batches');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'home',
        child: _isLoading ? _buildLoadingScreen() : _buildMainContent(context),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            "جاري التحميل...",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: const Color(0xFF7C3AED),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الهيدر
            _buildHeader(),
            const SizedBox(height: 24),

            // بطاقة البيع السريع
            _buildQuickSaleCard(),
            const SizedBox(height: 28),

            // عنوان الإحصائيات
            Text(
              "إحصائيات اليوم",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // إحصائيات اليوم - 4 جنب بعض أو 2 فوق 2 حسب المساحة
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 700) {
                  // 4 جنب بعض
                  return _buildFourStatsRow(salesProvider, productProvider);
                } else {
                  // 2 فوق 2
                  return _buildTwoByTwoStats(salesProvider, productProvider);
                }
              },
            ),

            // إشعارات المنتجات
            if (_expiredBatches > 0 || _expiringIn7DaysBatches > 0) ...[
              const SizedBox(height: 28),
              _buildBatchAlertsSection(),
            ],

            // الإجراءات السريعة
            const SizedBox(height: 28),
            Text(
              "التنقل السريع",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "مرحباً، $_userName",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCurrentDate(),
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF7C3AED),
                child: const Icon(Icons.person, size: 28, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store, size: 16, color: const Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(
                "نظام المتميز لنقاط البيع",
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF7C3AED),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSaleCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/pos'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "بدء عملية بيع جديدة",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "امسح الباركود أو ابحث عن المنتج",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "ابدأ البيع",
                              style: TextStyle(
                                color: Color(0xFF7C3AED),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 4 جنب بعض في صف واحد
  Widget _buildFourStatsRow(
    SalesProvider salesProvider,
    ProductProvider productProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildStatCard(
              title: "المبيعات اليوم",
              value: salesProvider.todaySalesCount.toString(),
              icon: Icons.receipt_long,
              color: const Color(0xFF10B981),
              subtitle: "فاتورة",
            ),
            _buildDivider(),
            _buildStatCard(
              title: "إجمالي المنتجات",
              value: productProvider.totalProducts.toString(),
              icon: Icons.inventory_2,
              color: const Color(0xFF3B82F6),
              subtitle: "منتج",
            ),
            _buildDivider(),
            _buildStatCard(
              title: "منخفضة المخزون",
              value: productProvider.lowStockCount.toString(),
              icon: Icons.warning_amber,
              color: const Color(0xFFF59E0B),
              subtitle: "منتج",
            ),
            _buildDivider(),
            _buildStatCard(
              title: "غير متوفرة",
              value: productProvider.outOfStockCount.toString(),
              icon: Icons.cancel,
              color: const Color(0xFFEF4444),
              subtitle: "منتج",
            ),
          ],
        ),
      ),
    );
  }

  // 2 فوق 2
  Widget _buildTwoByTwoStats(
    SalesProvider salesProvider,
    ProductProvider productProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCardVertical(
                    title: "المبيعات اليوم",
                    value: salesProvider.todaySalesCount.toString(),
                    icon: Icons.receipt_long,
                    color: const Color(0xFF10B981),
                    subtitle: "فاتورة",
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCardVertical(
                    title: "إجمالي المنتجات",
                    value: productProvider.totalProducts.toString(),
                    icon: Icons.inventory_2,
                    color: const Color(0xFF3B82F6),
                    subtitle: "منتج",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatCardVertical(
                    title: "منخفضة المخزون",
                    value: productProvider.lowStockCount.toString(),
                    icon: Icons.warning_amber,
                    color: const Color(0xFFF59E0B),
                    subtitle: "منتج",
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCardVertical(
                    title: "غير متوفرة",
                    value: productProvider.outOfStockCount.toString(),
                    icon: Icons.cancel,
                    color: const Color(0xFFEF4444),
                    subtitle: "منتج",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/products'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCardVertical({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/products'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 80, color: Colors.grey.shade200);
  }

  Widget _buildBatchAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_active,
                size: 18,
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              Text(
                "تنبيهات",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_expiredBatches > 0)
          _buildAlertCard(
            title: "منتجات منتهية الصلاحية",
            count: _expiredBatches,
            description: "يوجد $_expiredBatches منتج منتهي الصلاحية",
            color: Colors.red,
            icon: Icons.error_outline,
            onTap: () => _goToBatchesWithFilter('expired'),
          ),
        if (_expiringIn7DaysBatches > 0) ...[
          const SizedBox(height: 12),
          _buildAlertCard(
            title: "منتجات قريبة من الانتهاء",
            count: _expiringIn7DaysBatches,
            description:
                "سيتم انتهاء $_expiringIn7DaysBatches منتج خلال 7 أيام",
            color: Colors.orange,
            icon: Icons.watch_later_outlined,
            onTap: () => _goToBatchesWithFilter('expiring_7_days'),
          ),
        ],
      ],
    );
  }

  Widget _buildAlertCard({
    required String title,
    required int count,
    required String description,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_ios, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionItem(
              icon: Icons.bar_chart_rounded,
              label: "التقارير",
              color: const Color(0xFF7C3AED),
              onTap: () => Navigator.pushNamed(context, '/report'),
            ),
            _buildActionItem(
              icon: Icons.people_alt,
              label: "العملاء",
              color: const Color(0xFF3B82F6),
              onTap: () => Navigator.pushNamed(context, '/customer'),
            ),
            _buildActionItem(
              icon: Icons.settings,
              label: "الإعدادات",
              color: const Color(0xFFF59E0B),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
            _buildActionItem(
              icon: Icons.inventory,
              label: "الدُفعات",
              color: const Color(0xFF10B981),
              onTap: () => Navigator.pushNamed(context, '/batches'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final arabicMonths = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${now.day} ${arabicMonths[now.month - 1]} ${now.year}';
  }
}
