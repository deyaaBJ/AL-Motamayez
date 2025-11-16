import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/models/app_section.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/providers/settings_provider.dart';
import 'package:shopmate/widgets/sale_center_button.dart';
import 'package:shopmate/widgets/sections_grid.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // الأقسام الرئيسية
  final List<AppSection> _sections = [
    AppSection('المبيعات', Icons.point_of_sale, const Color(0xFF8B5FBF)),
    AppSection('المنتجات', Icons.inventory_2, const Color(0xFF6A3093)),
    AppSection('التقارير', Icons.analytics, const Color(0xFF4A1C6D)),
    AppSection(
      'العملاء',
      Icons.people,
      const Color.fromARGB(255, 131, 78, 190),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final role = auth.role;

    // فلترة الأقسام حسب الدور
    final filteredSections =
        role == 'admin'
            ? _sections
            : _sections.where((section) {
              if (role == 'cashier') {
                // الكاشير → المنتجات فقط
                return section.title == 'المنتجات';
              }

              if (role == 'tax') {
                // حساب الضريبة → المنتجات + المبيعات
                return section.title == 'المنتجات' ||
                    section.title == 'المبيعات';
              }

              // أي دور آخر (لو موجود)
              return section.title == 'المنتجات';
            }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),

              // زر بدء بيع جديد يظهر للجميع
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 80),
                child: SaleCenterButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/pos');
                  },
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: SectionsGrid(
                  sections: filteredSections,
                  onSectionTap: (section) {
                    switch (section.title) {
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
                    }
                  },
                ),
              ),
            ],
          ),

          if (role == 'admin')
            Positioned(
              bottom: 30,
              left: 24,
              child: _buildFloatingSettingsButton(),
            ),
          Positioned(
            bottom: 30,
            right: 24,
            child: _buildFloatingLogoutButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return FutureBuilder<void>(
      future:
          Provider.of<SettingsProvider>(context, listen: false).loadSettings(),
      builder: (context, snapshot) {
        final settingsProvider = Provider.of<SettingsProvider>(context);
        final marketName = settingsProvider.marketName ?? 'اسم المتجر';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5FBF), Color(0xFF6A3093), Color(0xFF4A1C6D)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // استبدال الأيقونة بالصورة
                  Container(
                    width: 70, // عرض الصورة
                    height: 70, // ارتفاع الصورة
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/shop_logo.png', // مسار الصورة
                        fit: BoxFit.fill, // تغطية كاملة للدائرة
                        height: 100,
                        width: 60,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ShopMate POS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        marketName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingSettingsButton() {
    return Column(
      children: [
        // زر الإعدادات الدائري
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5FBF), Color(0xFF6A3093)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/settings');
              },
              borderRadius: BorderRadius.circular(30),
              child: const Icon(Icons.settings, color: Colors.white, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // نص الإعدادات بدون خلفية بيضاء
        const Text(
          'الإعدادات',
          style: TextStyle(
            color: Color(0xFF6A3093),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingLogoutButton() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5FBF), Color(0xFF6A3093)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/login');
              },
              borderRadius: BorderRadius.circular(30),
              child: const Icon(Icons.logout, color: Colors.white, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // نص الإعدادات بدون خلفية بيضاء
        const Text(
          'الخروج',
          style: TextStyle(
            color: Color(0xFF6A3093),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
