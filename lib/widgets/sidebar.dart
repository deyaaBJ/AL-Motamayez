import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/models/app_section.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/providers/settings_provider.dart';

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

  final List<AppSection> _sections = [
    AppSection('المبيعات', Icons.point_of_sale, const Color(0xFF8B5FBF)),
    AppSection('المنتجات', Icons.inventory_2, const Color(0xFF6A3093)),
    AppSection('التقارير', Icons.analytics, const Color(0xFF4A1C6D)),
    AppSection('المشتريات', Icons.store, const Color(0xFF8B5FBF)),
    AppSection('الفواتير', Icons.receipt, const Color(0xFF6A3093)),
    AppSection(
      'العملاء',
      Icons.people,
      const Color.fromARGB(255, 131, 78, 190),
    ),
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

    final filteredSections =
        role == 'admin'
            ? _sections
            : _sections.where((section) {
              if (role == 'cashier') {
                return section.title == 'المنتجات';
              }
              if (role == 'tax') {
                return section.title == 'المنتجات' ||
                    section.title == 'المبيعات';
              }
              return section.title == 'المنتجات' ||
                  section.title == 'المشتريات' ||
                  section.title == 'الفواتير';
            }).toList();

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
            right: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Column(
          children: [
            // ------------------- Header -------------------
            _buildHeader(),
            // ---------------------------------------------------
            _buildUserInfo(role),
            const SizedBox(height: 16),
            _buildDivider(),
            const SizedBox(height: 16),
            Expanded(child: _buildMenuItems(filteredSections)),
            _buildBottomActions(role),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_isSidebarExpanded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "ShopMate",
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A1C6D),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
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
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: _toggleSidebar,
        icon: Icon(
          _isSidebarExpanded ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
          color: const Color(0xFF6A3093),
          size: 18,
        ),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF3F0F7),
          padding: const EdgeInsets.all(6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo(String? role) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 12 : 0),
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
                      radius: 24,
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
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          settings.marketName ?? "اسم المتجر",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      role?.toUpperCase() ?? "USER",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
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
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.store, color: Color(0xFF6A3093), size: 18),
                ),
              ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 16 : 8),
      child: const Divider(height: 1),
    );
  }

  Widget _buildMenuItems(List<AppSection> filteredSections) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 8 : 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSidebarItem(
              title: "الرئيسية",
              icon: Icons.dashboard_rounded,
              isActive: widget.currentPage == 'home',
              onTap: () => _safePageChange('home'),
            ),
            SizedBox(height: _isSidebarExpanded ? 6 : 3),
            ...filteredSections.map(
              (section) => Padding(
                padding: EdgeInsets.only(bottom: _isSidebarExpanded ? 6 : 3),
                child: _buildSidebarItem(
                  title: section.title,
                  icon: section.icon,
                  isActive: widget.currentPage == section.title,
                  onTap: () => _safePageChange(section.title),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(String? role) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isSidebarExpanded ? 8 : 4,
        vertical: 8,
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
            title: "تسجيل خروج",
            icon: Icons.logout_rounded,
            isActive: false,
            color: Colors.redAccent,
            onTap: () => _safePageChange('logout'),
          ),
        ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_isSidebarExpanded ? 12 : 8),
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(
            vertical: 10,
            horizontal: _isSidebarExpanded ? 10 : 6,
          ),
          decoration: BoxDecoration(
            color: isActive ? themeColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(_isSidebarExpanded ? 12 : 8),
            border:
                isActive
                    ? Border.all(color: themeColor.withOpacity(0.3), width: 1)
                    : null,
          ),
          child: Row(
            mainAxisAlignment:
                _isSidebarExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _isSidebarExpanded ? 32 : 28,
                height: _isSidebarExpanded ? 32 : 28,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isActive ? themeColor : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.grey.shade600,
                  size: _isSidebarExpanded ? 18 : 16,
                ),
              ),
              if (_isSidebarExpanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive ? themeColor : Colors.grey.shade700,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _safePageChange(String page) {
    try {
      widget.onPageChange(page);
    } catch (e) {
      print('Error in page change: $e');
    }
  }
}
