import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/providers/customer_provider.dart';
import 'package:shopmate/providers/product_provider.dart';
import 'package:shopmate/providers/settings_provider.dart';
import 'package:shopmate/providers/reports_provider.dart';
import 'package:shopmate/providers/sales_provider.dart';
import 'package:shopmate/screens/SalesHistoryScreen.dart';
import 'package:shopmate/screens/auth/login.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/screens/customers_screen.dart';
import 'package:shopmate/screens/home.dart';
import 'package:shopmate/screens/pos_screen.dart';
import 'package:shopmate/screens/products.dart';
import 'package:shopmate/screens/reports_screen.dart';
import 'package:shopmate/screens/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_size/window_size.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ تهيئة sqflite على Desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowMinSize(
      const Size(700, 700),
    ); // الحد الأدنى = 20 سم × 20 سم تقريبا
    setWindowMaxSize(const Size(1920, 1080)); // اختياري
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
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
      },
    );
  }
}
