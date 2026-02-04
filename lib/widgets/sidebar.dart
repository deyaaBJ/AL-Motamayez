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

  final List<Map<String, dynamic>> _sidebarSections = [
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
    final filteredSections = _getFilteredSections(role);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isSidebarExpanded ? 220 : 70, // ✅ أصغر
      child: Container(
        decoration: BoxDecoration(
          // ✅ لون بنفسجي أكثر
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B5FBF), Color(0xFF7C4DFF), Color(0xFF6A3093)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A1C6D).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // User Info
            _buildUserInfo(role),
            const SizedBox(height: 12),
            // Divider
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _isSidebarExpanded ? 16 : 8,
              ),
              child: Divider(
                height: 1,
                color: Colors.white.withOpacity(0.3),
                thickness: 1,
              ),
            ),
            const SizedBox(height: 12),
            // ✅ Menu Items مع Scroll
            Expanded(
              child: Scrollbar(child: _buildMenuItems(filteredSections)),
            ),
            // Bottom Actions
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                "المتميز",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildToggleButton(),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: _buildToggleButton()),
      );
    }
  }

  Widget _buildToggleButton() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: IconButton(
        onPressed: _toggleSidebar,
        icon: Icon(
          _isSidebarExpanded ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
          color: Colors.white,
          size: 16,
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
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.store,
                        color: Color(0xFF6A3093),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      return Text(
                        settings.marketName ?? "اسم المتجر",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getRoleTitle(role ?? 'user'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              )
              : Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.store, color: Color(0xFF6A3093), size: 18),
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
      padding: EdgeInsets.symmetric(
        horizontal: _isSidebarExpanded ? 12 : 4,
        vertical: 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الرئيسية
          _buildSidebarItem(
            title: "الرئيسية",
            icon: Icons.dashboard_rounded,
            isActive: widget.currentPage == 'home',
            onTap: () => _safePageChange('home'),
          ),
          SizedBox(height: _isSidebarExpanded ? 6 : 3),

          // الأقسام
          ...sections.expand((section) {
            final items = <Widget>[];

            if (_isSidebarExpanded && section['label'] != null) {
              items.add(_buildSectionLabel(section['label'] as String));
              items.add(const SizedBox(height: 2));
            }

            items.addAll(
              (section['items'] as List).map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: _isSidebarExpanded ? 4 : 2),
                  child: _buildSidebarItem(
                    title: item['title'],
                    icon: item['icon'],
                    isActive: widget.currentPage == item['title'],
                    onTap: () => _safePageChange(item['page']),
                    color: item['color'],
                  ),
                ),
              ),
            );

            if (section != sections.last) {
              items.add(SizedBox(height: _isSidebarExpanded ? 8 : 4));
            }

            return items;
          }),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.w600,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.white.withOpacity(0.1),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(
            horizontal: _isSidebarExpanded ? 12 : 0,
          ),
          decoration: BoxDecoration(
            color:
                isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border:
                isActive
                    ? Border.all(color: Colors.white.withOpacity(0.4))
                    : null,
          ),
          child:
              _isSidebarExpanded
                  ? Row(
                    children: [
                      _icon(icon, isActive),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                  : Center(child: _icon(icon, isActive)),
        ),
      ),
    );
  }

  Widget _icon(IconData icon, bool isActive) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isActive ? const Color(0xFF6A3093) : Colors.white,
      ),
    );
  }

  Widget _buildBottomActions(String? role) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isSidebarExpanded ? 12 : 4,
        vertical: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role == 'admin')
            Padding(
              padding: EdgeInsets.only(bottom: _isSidebarExpanded ? 6 : 3),
              child: _buildSidebarItem(
                title: "الإعدادات",
                icon: Icons.settings_rounded,
                isActive: widget.currentPage == 'settings',
                onTap: () => _safePageChange('settings'),
              ),
            ),
          _buildSidebarItem(
            title: "خروج",
            icon: Icons.logout_rounded,
            isActive: false,
            onTap: () => _safePageChange('logout'),
          ),
          if (_isSidebarExpanded) ...[
            const SizedBox(height: 8),
            Text(
              "v1.0.0",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
              ),
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
