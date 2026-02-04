import 'package:flutter/material.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/settings_provider.dart';

class BaseLayout extends StatefulWidget {
  final Widget child;
  final String currentPage;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const BaseLayout({
    super.key,
    required this.child,
    required this.currentPage,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  State<BaseLayout> createState() => _BaseLayoutState();
}

class _BaseLayoutState extends State<BaseLayout> {
  final ScrollController _rightSidebarController = ScrollController();

  @override
  void dispose() {
    _rightSidebarController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          Provider.of<SettingsProvider>(context, listen: false).loadSettings(),
    );
  }

  void _handlePageChange(String page) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    switch (page) {
      case 'home':
        Navigator.pushNamed(context, '/home');
        break;
      case 'المنتجات':
        Navigator.pushNamed(context, '/product');
        break;
      case 'المبيعات':
        Navigator.pushNamed(context, '/salesHistory');
        break;
      case 'التقارير':
        Navigator.pushNamed(context, '/report');
        break;
      case 'العملاء':
        Navigator.pushNamed(context, '/customer');
        break;
      case 'فاتورة شراء':
        Navigator.pushNamed(context, '/purchaseInvoice');
        break;
      case 'الفواتير':
        Navigator.pushNamed(context, '/purchaseInvoicesList');
        break;
      case 'الموردين':
        Navigator.pushNamed(context, '/suppliers');
        break;
      case 'المصاريف':
        Navigator.pushNamed(context, '/expenses');
        break;
      case 'الباتشات':
        Navigator.pushNamed(context, '/batches');
        break;
      case 'pos':
        Navigator.pushNamed(context, '/pos');
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'logout':
        authProvider.logout();
        Navigator.pushReplacementNamed(context, '/login');
        break;
    }
  }

  final List<Map<String, dynamic>> _rightSidebarItems = [
    {'icon': Icons.home_filled, 'label': 'الرئيسية', 'page': 'home'},
    {'icon': Icons.people_alt_rounded, 'label': 'العملاء', 'page': 'العملاء'},
    {
      'icon': Icons.local_shipping_rounded,
      'label': 'الموردين',
      'page': 'الموردين',
    },
    {
      'icon': Icons.account_balance_wallet_rounded,
      'label': 'المصاريف',
      'page': 'المصاريف',
    },
    {
      'icon': Icons.inventory_2_rounded,
      'label': 'الباتشات',
      'page': 'الباتشات',
    },
  ];

  final List<Map<String, dynamic>> _topSidebarItems = [
    {
      'icon': Icons.point_of_sale_rounded,
      'label': 'نقاط البيع',
      'page': 'pos',
      'isPrimary': true,
    },
    {
      'icon': Icons.shopping_bag_rounded,
      'label': 'المنتجات',
      'page': 'المنتجات',
    },
    {
      'icon': Icons.shopping_cart_checkout_rounded,
      'label': 'المبيعات',
      'page': 'المبيعات',
    },
    {
      'icon': Icons.receipt_long_rounded,
      'label': 'فاتورة شراء',
      'page': 'فاتورة شراء',
    },
    {'icon': Icons.analytics_rounded, 'label': 'التقارير', 'page': 'التقارير'},
    {'icon': Icons.receipt_rounded, 'label': 'الفواتير', 'page': 'الفواتير'},
  ];

  // ✅ بناء الشريط الجانبي الأيمن - items أصغر
  Widget _buildRightSidebar() {
    return Container(
      width: 110,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8B5FBF),
            Color(0xFF7C4DFF),
            Color(0xFF6A3093),
            Color(0xFF4A1C6D),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(74, 28, 109, 0.4),
            blurRadius: 15,
            spreadRadius: 2,
            offset: Offset(-3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // اللوقو
          Container(
            height: 85,
            padding: const EdgeInsets.all(10),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/shop_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              controller: _rightSidebarController,
              thumbVisibility: true,
              child: ListView.separated(
                controller: _rightSidebarController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                itemCount: _rightSidebarItems.length,
                separatorBuilder:
                    (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _rightSidebarItems[index];
                  final isSelected = widget.currentPage == item['page'];

                  return _buildSidebarItem(
                    icon: item['icon'],
                    label: item['label'],
                    isSelected: isSelected,
                    onTap: () => _handlePageChange(item['page']),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSidebarItem(
                  icon: Icons.settings_rounded,
                  label: 'الإعدادات',
                  isSelected: widget.currentPage == 'settings',
                  onTap: () => _handlePageChange('settings'),
                ),
                const SizedBox(height: 10),
                _buildSidebarItem(
                  icon: Icons.logout_rounded,
                  label: 'خروج',
                  isSelected: false,
                  onTap: () => _handlePageChange('logout'),
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ items أصغر في السايد بار
  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      hoverColor: Colors.white.withOpacity(0.15),
      child: Container(
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border:
              isSelected
                  ? Border.all(color: Colors.white.withOpacity(0.4), width: 1.5)
                  : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ بناء عنصر في الشريط العلوي
  Widget _buildTopSidebarItem({
    required Map<String, dynamic> item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isPrimary = item['isPrimary'] == true;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: 48,
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? const Color(0xFF8B5FBF).withOpacity(0.1)
                      : (isPrimary
                          ? const Color(0xFF8B5FBF)
                          : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border:
                  isSelected
                      ? Border.all(
                        color: const Color(0xFF8B5FBF).withOpacity(0.4),
                        width: 2,
                      )
                      : (isPrimary
                          ? Border.all(color: const Color(0xFF8B5FBF), width: 2)
                          : Border.all(color: Colors.transparent, width: 2)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                hoverColor:
                    isPrimary
                        ? const Color(0xFF7C4DFF)
                        : const Color(0xFF8B5FBF).withOpacity(0.08),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canShowText = constraints.maxWidth > 70;
                    final canShowIcon = constraints.maxWidth > 40;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (canShowIcon)
                          Icon(
                            item['icon'],
                            color:
                                isSelected || isPrimary
                                    ? (isPrimary
                                        ? Colors.white
                                        : const Color(0xFF8B5FBF))
                                    : const Color(0xFF666666),
                            size: constraints.maxWidth > 90 ? 20 : 18,
                          ),
                        if (canShowText && canShowIcon)
                          const SizedBox(width: 6),
                        if (canShowText)
                          Flexible(
                            child: Text(
                              item['label'],
                              style: TextStyle(
                                color:
                                    isSelected || isPrimary
                                        ? (isPrimary
                                            ? Colors.white
                                            : const Color(0xFF8B5FBF))
                                        : const Color(0xFF444444),
                                fontWeight: FontWeight.w600,
                                fontSize: constraints.maxWidth > 90 ? 12 : 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ بناء الشريط العلوي
  Widget _buildTopSidebar() {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;

          final double titleWidth =
              screenWidth < 400 ? 100.0 : (screenWidth < 600 ? 140.0 : 180.0);

          final double actionsWidth = (widget.actions != null) ? 50 : 0;

          return Row(
            children: [
              // ✅ "المتميز" فاخر بدون container بنفسجي
              Container(
                width: titleWidth,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildFancyTitle(screenWidth),
              ),

              // ✅ الـ 6 items
              Expanded(
                child: Row(
                  children:
                      _topSidebarItems.map((item) {
                        final isSelected = widget.currentPage == item['page'];
                        return _buildTopSidebarItem(
                          item: item,
                          isSelected: isSelected,
                          onTap: () => _handlePageChange(item['page']),
                        );
                      }).toList(),
                ),
              ),

              // ✅ الإجراءات
              if (widget.actions != null)
                Container(
                  width: actionsWidth,
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.actions!,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ✅ "المتميز" فاخر بدون container - نص عادي بستايل مميز
  Widget _buildFancyTitle(double screenWidth) {
    final double fontSize =
        screenWidth < 400
            ? 20 // ✅ أكبر
            : (screenWidth < 600 ? 24 : 28); // ✅ أكبر وأوضح

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ✅ أيقونة صغيرة قبل الاسم (اختياري)
        const SizedBox(width: 4),
        // ✅ النص بستايل فاخر
        Text(
          'المتميز',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontFamily: 'Amiri',
            // ✅ gradient text بدون container
            foreground:
                Paint()
                  ..shader = const LinearGradient(
                    colors: [
                      Color(0xFF8B5FBF),
                      Color(0xFF6A3093),
                      Color(0xFF4A1C6D),
                    ],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
            letterSpacing: 2, // ✅ تباعد أكبر
            shadows: [
              Shadow(
                color: const Color(0xFF8B5FBF).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(2, 2),
              ),
              Shadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 4,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: Row(
        children: [
          // الشريط الجانبي الأيمن
          _buildRightSidebar(),

          // المحتوى الرئيسي
          Expanded(
            child: Column(
              children: [
                // الشريط العلوي
                _buildTopSidebar(),

                // المحتوى
                Expanded(
                  child: SafeArea(
                    left: false,
                    top: false,
                    right: false,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                        ),
                      ),
                      margin: const EdgeInsets.only(left: 1, top: 1),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
