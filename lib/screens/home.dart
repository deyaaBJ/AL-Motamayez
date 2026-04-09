// screens/home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/providers/sales_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/providers/batch_provider.dart';
import 'package:motamayez/utils/app_logger.dart';
import 'package:motamayez/widgets/main_screen/loading_screen.dart';
import 'package:motamayez/widgets/main_screen/main_screen_header.dart';
import 'package:motamayez/widgets/main_screen/stats_row.dart';
import 'package:motamayez/widgets/main_screen/chart_section.dart';
import 'package:motamayez/widgets/main_screen/offers_section.dart';
import 'package:motamayez/widgets/main_screen/notifications_section.dart';

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
        salesProvider.refreshHomeDashboardStats(),
        productProvider.loadTotalProducts(),
        productProvider.loadProductsOnOfferCount(),
        settings.loadSettings(),
      ]);

      await productProvider.loadStockCounts(settings.lowStockThreshold);
      await _loadUserName();
      await _loadBatchAlerts();
    } catch (e) {
      appLog('⚠️ خطأ في تحميل البيانات: $e', name: 'MainScreen');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserName() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (mounted) setState(() => _userName = user?['name'] ?? 'المستخدم');
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
    Provider.of<BatchProvider>(
      context,
      listen: false,
    ).loadBatchesWithFilter(filterType);
    Navigator.pushNamed(context, '/batches');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'home',
        child: _isLoading ? const LoadingScreen() : _buildMainContent(context),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // ignore: deprecated_member_use
            const Color(0xFF7C3AED).withOpacity(0.03),
            Colors.white,
            Colors.white,
            // ignore: deprecated_member_use
            const Color(0xFF6D28D9).withOpacity(0.02),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 900;
          final isMediumScreen =
              constraints.maxWidth >= 600 && constraints.maxWidth < 900;
          final isSmallScreen = constraints.maxWidth < 600;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                MainScreenHeader(userName: _userName),
                const SizedBox(height: 16),
                Expanded(
                  child:
                      isLargeScreen
                          ? _buildLargeScreenLayout(
                            salesProvider,
                            productProvider,
                          )
                          : _buildMobileAndTabletLayout(
                            salesProvider,
                            productProvider,
                            isMediumScreen,
                            isSmallScreen,
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLargeScreenLayout(
    SalesProvider salesProvider,
    ProductProvider productProvider,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              StatsRow(
                salesValue: salesProvider.todaySalesAmount.toStringAsFixed(2),
                productsValue: productProvider.totalProducts.toString(),
                lowStockValue: productProvider.lowStockCount.toString(),
              ),
              const SizedBox(height: 16),
              const Expanded(child: ChartSection(useExpanded: true)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              OffersSection(
                productsOnSale: productProvider.productsOnOfferCount,
                totalProducts: productProvider.totalProducts,
                onTap: () => Navigator.pushNamed(context, '/products'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: NotificationsSection(
                  expiredBatches: _expiredBatches,
                  expiringIn7DaysBatches: _expiringIn7DaysBatches,
                  onTapFilter: _goToBatchesWithFilter,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileAndTabletLayout(
    SalesProvider salesProvider,
    ProductProvider productProvider,
    bool isMediumScreen,
    bool isSmallScreen,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          StatsRow(
            salesValue: salesProvider.todaySalesAmount.toStringAsFixed(2),
            productsValue: productProvider.totalProducts.toString(),
            lowStockValue: productProvider.lowStockCount.toString(),
            compact: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: isSmallScreen ? 320 : 380,
            child: const ChartSection(useExpanded: false),
          ),
          const SizedBox(height: 20),
          isMediumScreen
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: OffersSection(
                      productsOnSale: productProvider.productsOnOfferCount,
                      totalProducts: productProvider.totalProducts,
                      onTap: () => Navigator.pushNamed(context, '/products'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: NotificationsSection(
                      expiredBatches: _expiredBatches,
                      expiringIn7DaysBatches: _expiringIn7DaysBatches,
                      onTapFilter: _goToBatchesWithFilter,
                    ),
                  ),
                ],
              )
              : Column(
                children: [
                  OffersSection(
                    productsOnSale: productProvider.productsOnOfferCount,
                    totalProducts: productProvider.totalProducts,
                    onTap: () => Navigator.pushNamed(context, '/products'),
                  ),
                  const SizedBox(height: 20),
                  NotificationsSection(
                    expiredBatches: _expiredBatches,
                    expiringIn7DaysBatches: _expiringIn7DaysBatches,
                    onTapFilter: _goToBatchesWithFilter,
                  ),
                ],
              ),
        ],
      ),
    );
  }
}
