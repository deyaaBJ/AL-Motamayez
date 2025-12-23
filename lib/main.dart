import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/db/db_helper.dart';
import 'package:shopmate/providers/DebtProvider.dart';
import 'package:shopmate/providers/customer_provider.dart';
import 'package:shopmate/providers/product_provider.dart';
import 'package:shopmate/providers/purchase_invoice_provider.dart';
import 'package:shopmate/providers/purchase_item_provider.dart';
import 'package:shopmate/providers/settings_provider.dart';
import 'package:shopmate/providers/reports_provider.dart';
import 'package:shopmate/providers/sales_provider.dart';
import 'package:shopmate/providers/sidebar_provider.dart';
import 'package:shopmate/providers/supplier_provider.dart';
import 'package:shopmate/screens/PurchaseInvoicesListPage.dart';
import 'package:shopmate/screens/SalesHistoryScreen.dart';
import 'package:shopmate/screens/auth/login.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/screens/customers_screen.dart';
import 'package:shopmate/screens/home.dart';
import 'package:shopmate/screens/pos_screen.dart';
import 'package:shopmate/screens/products.dart';
import 'package:shopmate/screens/purchase_invoice_page.dart';
import 'package:shopmate/screens/reports_screen.dart';
import 'package:shopmate/screens/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_size/window_size.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final DBHelper dbHelper = DBHelper();
  await dbHelper.db;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('ShopMate POS');
    setWindowMinSize(const Size(1000, 700)); // الحد الأدنى
    // setWindowMaxSize(const Size(1200, 1000)); // إذا بدك حد أقصى
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()), // ✅ صح
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => SideBarProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseInvoiceProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseItemProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
      ],
      child: const ShopMateApp(),
    ),
  );
}

class ShopMateApp extends StatelessWidget {
  const ShopMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShopMate POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Poppins'),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainScreen(),
        '/product': (context) => const ProductsScreen(),
        '/pos': (context) => const PosScreen(),
        '/customer': (context) => const CustomersScreen(),
        '/salesHistory': (context) => const SalesHistoryScreen(),
        '/report': (context) => const ReportsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/purchaseInvoice': (context) => const PurchaseInvoicePage(),
        '/purchaseInvoicesList': (context) => const PurchaseInvoicesListPage(),
      },
    );
  }
}
