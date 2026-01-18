import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'dart:developer';

class Sidebar extends StatefulWidget {
  final String currentPage;
  final Function(String) onPageChange;

  const Sidebar({
    super.key,
    required this.currentPage,
    required this.onPageChange,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isSidebarExpanded = true;

  // تعريف أقسام السايدبار مع التصنيفات
  final List<Map<String, dynamic>> _sidebarSections = [
    // العمليات اليومية
    {
      'label': 'العمليات اليومية',
      'items': [
        {
          'title': 'المبيعات',
          'icon': Icons.point_of_sale,
          'color': Color(0xFF8B5FBF),
          'page': 'المبيعات',
        },
        {
          'title': 'فاتورة شراء',
          'icon': Icons.store,
          'color': Color(0xFF6A3093),
          'page': 'فاتورة شراء',
        },
      ],
    },

    // إدارة البيانات
    {
      'label': 'إدارة البيانات',
      'items': [
        {
          'title': 'المنتجات',
          'icon': Icons.inventory_2,
          'color': Color(0xFF4A1C6D),
          'page': 'المنتجات',
        },
        {
          'title': 'العملاء',
          'icon': Icons.people,
          'color': Color(0xFF8B5FBF),
          'page': 'العملاء',
        },
        {
          'title': 'الموردين',
          'icon': Icons.business,
          'color': Color(0xFF6A3093),
          'page': 'الموردين',
        },
      ],
    },

    // التقارير والإدارة
    {
      'label': 'التقارير والإدارة',
      'items': [
        {
          'title': 'الفواتير',
          'icon': Icons.receipt,
          'color': Color(0xFF4A1C6D),
          'page': 'الفواتير',
        },
        {
          'title': 'التقارير',
          'icon': Icons.analytics,
          'color': Color(0xFF8B5FBF),
          'page': 'التقارير',
        },
        {
          'title': 'المصاريف',
          'icon': Icons.money_off,
          'color': Color(0xFF6A3093),
          'page': 'المصاريف',
        },
      ],
    },
  ];

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final role = auth.role;

    // تصفية العناصر حسب الدور مع الاحتفاظ بالتصنيفات
    final filteredSections = _getFilteredSections(role);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isSidebarExpanded ? 240 : 80,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 25,
              offset: const Offset(5, 0),
            ),
          ],
          border: Border(
            right: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Column(
          children: [
            // ------------------- Header -------------------
            _buildHeader(),
            // ------------------- User Info -------------------
            _buildUserInfo(role),
            const SizedBox(height: 16),
            // ------------------- Divider -------------------
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _isSidebarExpanded ? 16 : 8,
              ),
              child: Divider(
                height: 1,
                color: Colors.grey.shade400,
                thickness: 1,
              ),
            ),
            const SizedBox(height: 16),
            // ------------------- Menu Items -------------------
            Expanded(child: _buildMenuItems(filteredSections)),
            // ------------------- Bottom Actions -------------------
            _buildBottomActions(role),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredSections(String? role) {
    if (role == 'admin') return _sidebarSections;

    return _sidebarSections
        .map((section) {
          final filteredItems =
              section['items'].where((item) {
                final title = item['title'];
                if (role == 'cashier') {
                  return title == 'المنتجات' || title == 'المبيعات';
                }
                if (role == 'tax') {
                  return title == 'المنتجات' ||
                      title == 'المبيعات' ||
                      title == 'الفواتير';
                }
                return title == 'المنتجات' ||
                    title == 'فاتورة شراء' ||
                    title == 'الفواتير' ||
                    title == 'الموردين' ||
                    title == 'المصاريف';
              }).toList();

          return {'label': section['label'], 'items': filteredItems};
        })
        .where((section) => (section['items'] as List).isNotEmpty)
        .toList();
  }

  Widget _buildHeader() {
    if (_isSidebarExpanded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "المتميز",
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A1C6D),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            _buildToggleButton(),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: _buildToggleButton()),
      );
    }
  }

  Widget _buildToggleButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF8B5FBF).withOpacity(0.2)),
      ),
      child: IconButton(
        onPressed: _toggleSidebar,
        icon: Icon(
          _isSidebarExpanded ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
          color: const Color(0xFF6A3093),
          size: 20,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildUserInfo(String? role) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 16 : 0),
      child:
          _isSidebarExpanded
              ? Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF8B5FBF),
                        width: 1.5,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.store,
                        color: Color(0xFF6A3093),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          settings.marketName ?? "اسم المتجر",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _getRoleTitle(role ?? 'user'),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              )
              : Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8B5FBF),
                    width: 1.5,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.store, color: Color(0xFF6A3093), size: 20),
                ),
              ),
    );
  }

  String _getRoleTitle(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'مدير النظام';
      case 'cashier':
        return 'كاشير';
      case 'tax':
        return 'موظف ضريبة';
      default:
        return 'مستخدم';
    }
  }

  Widget _buildMenuItems(List<Map<String, dynamic>> sections) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _isSidebarExpanded ? 12 : 4,
          vertical: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // العنصر الأول: الرئيسية
            _buildSidebarItem(
              title: "الرئيسية",
              icon: Icons.dashboard_rounded,
              isActive: widget.currentPage == 'home',
              onTap: () => _safePageChange('home'),
            ),
            SizedBox(height: _isSidebarExpanded ? 8 : 4),

            // بقية الأقسام مع تصنيفاتها
            ...sections.expand((section) {
              final items = <Widget>[];

              // إضافة التصنيف إذا كان السايدبار مفتوحاً
              if (_isSidebarExpanded && section['label'] != null) {
                items.add(_buildSectionLabel(section['label'] as String));
                items.add(const SizedBox(height: 4));
              }

              // إضافة عناصر القسم
              items.addAll(
                (section['items'] as List)
                    .map(
                      (item) => Padding(
                        padding: EdgeInsets.only(
                          bottom: _isSidebarExpanded ? 6 : 3,
                        ),
                        child: _buildSidebarItem(
                          title: item['title'],
                          icon: item['icon'],
                          isActive: widget.currentPage == item['title'],
                          onTap: () => _safePageChange(item['page']),
                          color: item['color'],
                        ),
                      ),
                    )
                    .toList(),
              );

              // إضافة مسافة بين الأقسام
              if (section != sections.last) {
                items.add(SizedBox(height: _isSidebarExpanded ? 12 : 6));
              }

              return items;
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    Color? color,
  }) {
    final themeColor = color ?? const Color(0xFF6A3093);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canShowText = constraints.maxWidth >= 160; // 🔑 المفتاح

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(canShowText ? 12 : 8),
            child: Container(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: canShowText ? 12 : 0),
              decoration: BoxDecoration(
                color:
                    isActive
                        ? themeColor.withOpacity(0.15)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(canShowText ? 12 : 8),
              ),

              // 👇 التغيير الحقيقي هنا
              child:
                  canShowText
                      ? Row(
                        children: [
                          _icon(icon, isActive, themeColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                      : Center(child: _icon(icon, isActive, themeColor)),
            ),
          ),
        );
      },
    );
  }

  Widget _icon(IconData icon, bool isActive, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 20,
        color: isActive ? Colors.white : Colors.grey.shade600,
      ),
    );
  }

  Widget _buildBottomActions(String? role) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isSidebarExpanded ? 12 : 4,
        vertical: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role == 'admin')
            Padding(
              padding: EdgeInsets.only(bottom: _isSidebarExpanded ? 8 : 4),
              child: _buildSidebarItem(
                title: "الإعدادات",
                icon: Icons.settings_rounded,
                isActive: widget.currentPage == 'settings',
                onTap: () => _safePageChange('settings'),
              ),
            ),
          _buildSidebarItem(
            title: "تسجيل خروج",
            icon: Icons.logout_rounded,
            isActive: false,
            color: Colors.redAccent,
            onTap: () => _safePageChange('logout'),
          ),
          if (_isSidebarExpanded) ...[
            const SizedBox(height: 12),
            Text(
              "الإصدار 1.0.0",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  void _safePageChange(String page) {
    try {
      widget.onPageChange(page);
    } catch (e) {
      log('Error in page change: $e');
    }
  }
}
