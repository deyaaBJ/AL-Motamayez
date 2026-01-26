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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
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

  // العناصر التي ستظهر في الشريط الجانبي الأيمن
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
  ];

  // العناصر التي ستظهر في الشريط العلوي مع إضافة نقاط البيع أولاً
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

  // بناء الشريط الجانبي الأيمن - يبدأ من بداية الشاشة
  Widget _buildRightSidebar() {
    return Container(
      width: 100,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7C4DFF), Color(0xFF651FFF), Color(0xFF6200EA)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(98, 0, 234, 0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: Offset(-3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // أيقونة البرنامج في الأعلى - بدون حدود
          Container(
            height: 100,
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
                      blurRadius: 10,
                      spreadRadius: 1,
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

          // قائمة العناصر الرئيسية
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _rightSidebarItems.length,
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

          // قسم الإعدادات وتسجيل الخروج
          Column(
            children: [
              _buildSidebarItem(
                icon: Icons.settings_rounded,
                label: 'الإعدادات',
                isSelected: widget.currentPage == 'settings',
                onTap: () => _handlePageChange('settings'),
              ),
              _buildSidebarItem(
                icon: Icons.logout_rounded,
                label: 'تسجيل خروج',
                isSelected: false,
                onTap: () => _handlePageChange('logout'),
                color: Colors.redAccent,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.white.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Colors.white.withOpacity(0.15)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border:
                isSelected
                    ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                    : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color ?? Colors.white, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء عنصر في الشريط العلوي مع تأثير Hover محسن
  Widget _buildTopSidebarItem({
    required Map<String, dynamic> item,
    required bool isSelected,
    required VoidCallback onTap,
    required double itemWidth,
    bool showText = true,
  }) {
    final isPrimary = item['isPrimary'] == true;

    return Container(
      width: itemWidth,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? const Color(0xFF7C4DFF).withOpacity(0.1)
                    : (isPrimary
                        ? const Color(0xFF7C4DFF)
                        : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border:
                isSelected
                    ? Border.all(
                      color: const Color(0xFF7C4DFF).withOpacity(0.3),
                      width: 1.5,
                    )
                    : (isPrimary
                        ? Border.all(color: const Color(0xFF7C4DFF), width: 1.5)
                        : Border.all(color: Colors.transparent, width: 1.5)),
            boxShadow:
                isSelected || isPrimary
                    ? [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withOpacity(0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor:
                  isPrimary
                      ? const Color(0xFF651FFF)
                      : const Color(0xFF7C4DFF).withOpacity(0.08),
              splashColor: const Color(0xFF7C4DFF).withOpacity(0.2),
              highlightColor: const Color(0xFF7C4DFF).withOpacity(0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            (isSelected || isPrimary)
                                ? Colors.white.withOpacity(0.9)
                                : const Color(0xFF7C4DFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item['icon'],
                        color:
                            isSelected || isPrimary
                                ? const Color(0xFF7C4DFF)
                                : const Color(0xFF666666),
                        size: 20,
                      ),
                    ),
                    if (showText) const SizedBox(width: 8),
                    if (showText)
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color:
                                isSelected || isPrimary
                                    ? (isPrimary
                                        ? Colors.white
                                        : const Color(0xFF7C4DFF))
                                    : const Color(0xFF444444),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          child: Text(
                            item['label'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // بناء الشريط العلوي
  Widget _buildTopSidebar() {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF5F5F5), width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isMobile = screenWidth < 768;
          final isSmallMobile = screenWidth < 480;
          final isVerySmallMobile = screenWidth < 360;

          // حساب عرض العنوان
          final double titleWidth =
              isVerySmallMobile
                  ? 100.0
                  : (isSmallMobile ? 140.0 : (isMobile ? 180.0 : 200.0));

          // حساب المساحة المتبقية للعناصر
          final double actionsWidth =
              (widget.actions != null && !isSmallMobile) ? 60 : 0;
          final double availableSpaceForItems =
              screenWidth - titleWidth - actionsWidth - 20; // 20 للهامش

          return Row(
            children: [
              // العنوان
              Container(
                width: titleWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallMobile ? 8 : (isMobile ? 16 : 24),
                ),
                child: Text(
                  widget.title ?? 'المتميز',
                  style: TextStyle(
                    fontSize:
                        isVerySmallMobile
                            ? 12
                            : (isSmallMobile ? 14 : (isMobile ? 16 : 18)),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF333333),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // العناصر في الشريط العلوي
              Expanded(
                child: _buildResponsiveTopItems(
                  availableWidth: availableSpaceForItems,
                  isMobile: isMobile,
                  isSmallMobile: isSmallMobile,
                  isVerySmallMobile: isVerySmallMobile,
                ),
              ),

              // الإجراءات الإضافية
              if (widget.actions != null && !isSmallMobile)
                Container(
                  width: actionsWidth,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
                  child: Row(children: widget.actions!),
                ),
            ],
          );
        },
      ),
    );
  }

  // بناء العناصر العلوية المتجاوبة
  Widget _buildResponsiveTopItems({
    required double availableWidth,
    required bool isMobile,
    required bool isSmallMobile,
    required bool isVerySmallMobile,
  }) {
    // تحديد عرض كل عنصر بناءً على حجم الشاشة
    double itemWidth;
    bool showText = true;

    if (isVerySmallMobile) {
      itemWidth = 60; // أيقونة فقط
      showText = false;
    } else if (isSmallMobile) {
      itemWidth = 90; // أيقونة مع نص مختصر
    } else if (isMobile) {
      itemWidth = 120; // أيقونة مع نص كامل
    } else {
      itemWidth = 140; // عرض كامل
    }

    // حساب إجمالي العرض المطلوب
    final double totalItemsWidth = _topSidebarItems.length * itemWidth;

    // إذا كان هناك مساحة كافية، نعرض كل العناصر في صف واحد
    if (availableWidth >= totalItemsWidth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children:
              _topSidebarItems.map((item) {
                final isSelected = widget.currentPage == item['page'];
                return _buildTopSidebarItem(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => _handlePageChange(item['page']),
                  itemWidth: itemWidth,
                  showText: showText,
                );
              }).toList(),
        ),
      );
    } else {
      // إذا لم تكن هناك مساحة كافية، نستخدم تمريراً أفقياً
      return ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _topSidebarItems.length,
        itemBuilder: (context, index) {
          final item = _topSidebarItems[index];
          final isSelected = widget.currentPage == item['page'];
          return _buildTopSidebarItem(
            item: item,
            isSelected: isSelected,
            onTap: () => _handlePageChange(item['page']),
            itemWidth: itemWidth,
            showText: showText,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: Row(
        children: [
          // الشريط الجانبي الأيمن - يبدأ من بداية الشاشة
          _buildRightSidebar(),

          // المحتوى الرئيسي مع الشريط العلوي
          Expanded(
            child: Column(
              children: [
                // الشريط العلوي
                _buildTopSidebar(),

                // المحتوى الرئيسي
                Expanded(
                  child: SafeArea(
                    left: false,
                    top: false,
                    right: false,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                        ),
                      ),
                      margin: const EdgeInsets.only(left: 2, top: 2, bottom: 2),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
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
