import 'package:flutter/material.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/widgets/sidebar.dart';

class BaseLayout extends StatefulWidget {
  final Widget child;
  final String currentPage;
  final bool showAppBar;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton; // أضف هذا السطر

  const BaseLayout({
    super.key,
    required this.child,
    required this.currentPage,
    this.showAppBar = false,
    this.title,
    this.actions,
    this.floatingActionButton, // أضف هذا السطر
  });

  @override
  State<BaseLayout> createState() => _BaseLayoutState();
}

class _BaseLayoutState extends State<BaseLayout> {
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
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'logout':
        // ✅ هنا ننفذ logout قبل التنقل
        authProvider.logout();
        Navigator.pushReplacementNamed(
          context,
          '/login',
        ); // pushReplacement لتجنب العودة للصفحة السابقة
        break;
    }
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title ?? 'المتميز',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          if (widget.actions != null) ...widget.actions!,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F5FF),
        body: Row(
          children: [
            Sidebar(
              currentPage: widget.currentPage,
              onPageChange: _handlePageChange,
            ),
            Expanded(
              child: Column(
                children: [
                  if (widget.showAppBar) _buildAppBar(),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }
}
