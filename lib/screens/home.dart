import 'package:flutter/material.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/batch.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/batch_provider.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/providers/sales_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/services/activation_service.dart';
import 'package:motamayez/utils/app_logger.dart';
import 'package:motamayez/widgets/main_screen/chart_section.dart';
import 'package:motamayez/widgets/main_screen/main_screen_header.dart';
import 'package:motamayez/widgets/main_screen/notifications_section.dart';
import 'package:motamayez/widgets/main_screen/offers_section.dart';
import 'package:motamayez/widgets/main_screen/stats_row.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _expiredBatches = 0;
  int _expiringSoonBatches = 0;
  int _nearExpiryAlertDays = 7;
  bool _isLoading = true;
  String _userName = 'المستخدم';
  List<Batch> _expiredBatchList = [];
  List<Batch> _expiringBatchList = [];
  String _activationLabel = 'التفعيل الدائم';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

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

      if (mounted) {
        setState(() => _isLoading = false);
      }

      await Future.wait([
        productProvider.loadStockCounts(settings.lowStockThreshold),
        _loadUserName(),
        _loadBatchAlerts(),
        _loadActivationLabel(),
      ]);
    } catch (e) {
      appLog('خطأ في تحميل بيانات الشاشة الرئيسية: $e', name: 'MainScreen');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserName() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (!mounted) return;

      setState(() {
        _userName = user?['name']?.toString() ?? 'المستخدم';
      });
    } catch (e) {
      appLog('خطأ في تحميل اسم المستخدم: $e', name: 'MainScreen');
    }
  }

  Future<void> _loadBatchAlerts() async {
    try {
      final batchProvider = Provider.of<BatchProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final alerts = await batchProvider.getBatchesAlertsWithDetails(
        nearExpiryDays: settings.nearExpiryAlertDays,
      );

      if (!mounted) return;

      setState(() {
        _expiredBatches = alerts['expired'] ?? 0;
        _expiringSoonBatches = alerts['expiring_soon'] ?? 0;
        _nearExpiryAlertDays = settings.nearExpiryAlertDays;
        _expiredBatchList = (alerts['expired_list'] as List<Batch>?) ?? [];
        _expiringBatchList =
            (alerts['expiring_soon_list'] as List<Batch>?) ?? [];
      });
    } catch (e) {
      appLog('خطأ في تحميل تنبيهات الواردات: $e', name: 'MainScreen');
    }
  }

  Future<void> _loadActivationLabel() async {
    try {
      final activationService = ActivationService();
      final info = await activationService.getActivationInfo();
      final type = info['activation_type']?.toString() ?? 'permanent';
      final remainingDays = info['remaining_days'] as int?;

      if (!mounted) return;

      setState(() {
        if (type == 'temporary') {
          _activationLabel = 'متبقي ${remainingDays ?? 0} يوم';
        } else {
          _activationLabel = 'التفعيل الدائم';
        }
      });
    } catch (e) {
      appLog('خطأ في تحميل حالة التفعيل: $e', name: 'MainScreen');
      if (!mounted) return;
      setState(() {
        _activationLabel = 'التفعيل الدائم';
      });
    }
  }

  void _goToBatchesWithFilter(String filterType) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    Provider.of<BatchProvider>(context, listen: false).loadBatchesWithFilter(
      filterType,
      nearExpiryDays: settings.nearExpiryAlertDays,
    );
    Navigator.pushNamed(context, '/batches');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(currentPage: 'home', child: _buildMainContent(context)),
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
            const Color(0xFF7C3AED).withOpacity(0.03),
            Colors.white,
            Colors.white,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                MainScreenHeader(
                  userName: _userName,
                  activationLabel: _activationLabel,
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(minHeight: 4),
                    ),
                  ),
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
                  expiringSoonBatches: _expiringSoonBatches,
                  nearExpiryDays: _nearExpiryAlertDays,
                  onTapFilter: _goToBatchesWithFilter,
                  expandToFill: true,
                  expiredBatchList: _expiredBatchList,
                  expiringBatchList: _expiringBatchList,
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
                      expiringSoonBatches: _expiringSoonBatches,
                      nearExpiryDays: _nearExpiryAlertDays,
                      onTapFilter: _goToBatchesWithFilter,
                      expiredBatchList: _expiredBatchList,
                      expiringBatchList: _expiringBatchList,
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
                    expiringSoonBatches: _expiringSoonBatches,
                    nearExpiryDays: _nearExpiryAlertDays,
                    onTapFilter: _goToBatchesWithFilter,
                    expiredBatchList: _expiredBatchList,
                    expiringBatchList: _expiringBatchList,
                  ),
                ],
              ),
        ],
      ),
    );
  }
}
