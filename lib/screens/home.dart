import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/providers/sales_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/providers/batch_provider.dart';

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
      print('⚠️ خطأ في تحميل البيانات: $e');
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
      print('⚠️ خطأ في تحميل اسم المستخدم: $e');
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
      print('⚠️ خطأ في تحميل إشعارات الدفعات: $e');
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
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // الهيدر
          _buildHeader(),
          const SizedBox(height: 24),

          // بطاقة البيع السريع
          _buildQuickSaleCard(),
          const SizedBox(height: 24),

          // عنوان الإحصائيات
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              "إحصائيات اليوم",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          // إحصائيات اليوم - تصميم مضغوط مع خطوط كبيرة
          _buildCompactStats(salesProvider, productProvider),

          // إشعارات المنتجات
          if (_expiredBatches > 0 || _expiringIn7DaysBatches > 0) ...[
            const SizedBox(height: 24),
            _buildBatchAlertsSection(),
          ],

          // الإجراءات السريعة
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              "التنقل السريع",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          _buildQuickActions(),

          const SizedBox(height: 24),
        ],
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
            Text(
              "مرحباً، $_userName",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
              child: Icon(
                Icons.person,
                size: 24,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _getCurrentDate(),
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          "لوحة تحكم نظام المتميز",
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_shopping_cart,
                color: Colors.white,
                size: 28,
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "أنشئ فاتورة جديدة بسرعة وسهولة",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/pos'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "ابدأ الآن",
                            style: TextStyle(
                              color: Color(0xFF7C3AED),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_back_ios,
                            size: 16,
                            color: Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStats(
    SalesProvider salesProvider,
    ProductProvider productProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // الصف الأول
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactStatItem(
                  title: "المبيعات اليوم",
                  value: salesProvider.todaySalesCount.toString(),
                  icon: Icons.receipt,
                  color: const Color(0xFF10B981),
                ),
                _buildCompactStatItem(
                  title: "إجمالي المنتجات",
                  value: productProvider.totalProducts.toString(),
                  icon: Icons.inventory,
                  color: const Color(0xFF3B82F6),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // الصف الثاني
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactStatItem(
                  title: "منخفضة المخزون",
                  value: productProvider.lowStockCount.toString(),
                  icon: Icons.warning,
                  color: const Color(0xFFF59E0B),
                ),
                _buildCompactStatItem(
                  title: "غير متوفرة",
                  value: productProvider.outOfStockCount.toString(),
                  icon: Icons.close,
                  color: const Color(0xFFEF4444),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/products'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            "إشعارات المنتجات",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        if (_expiredBatches > 0)
          _buildCompactAlertCard(
            title: "منتجات منتهية الصلاحية",
            count: _expiredBatches,
            description: "يوجد $_expiredBatches منتج منتهي الصلاحية",
            color: Colors.red,
            icon: Icons.error,
            onTap: () => _goToBatchesWithFilter('expired'),
          ),
        if (_expiringIn7DaysBatches > 0) ...[
          const SizedBox(height: 12),
          _buildCompactAlertCard(
            title: "منتجات قريبة من الانتهاء",
            count: _expiringIn7DaysBatches,
            description:
                "سيتم انتهاء $_expiringIn7DaysBatches منتج خلال 7 أيام",
            color: Colors.orange,
            icon: Icons.warning,
            onTap: () => _goToBatchesWithFilter('expiring_7_days'),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactAlertCard({
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
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: color,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios, color: color, size: 20),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCompactActionItem(
              icon: Icons.bar_chart,
              label: "التقارير",
              color: const Color(0xFF7C3AED),
              onTap: () => Navigator.pushNamed(context, '/reports'),
            ),
            _buildCompactActionItem(
              icon: Icons.people,
              label: "العملاء",
              color: const Color(0xFF3B82F6),
              onTap: () => Navigator.pushNamed(context, '/customers'),
            ),
            _buildCompactActionItem(
              icon: Icons.settings,
              label: "الإعدادات",
              color: const Color(0xFFF59E0B),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
            _buildCompactActionItem(
              icon: Icons.layers,
              label: "الدُفعات",
              color: const Color(0xFF10B981),
              onTap: () => Navigator.pushNamed(context, '/batches'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActionItem({
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
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
