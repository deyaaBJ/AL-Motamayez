import 'dart:io';
import 'package:flutter/material.dart';
import 'package:motamayez/providers/product_batch_provider.dart';
import 'package:motamayez/providers/temporary_invoice_provider.dart';
import 'package:motamayez/services/activation_service.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:motamayez/db/db_helper.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/customer_provider.dart';
import 'package:motamayez/providers/sales_provider.dart';
import 'package:motamayez/providers/reports_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/providers/sidebar_provider.dart';
import 'package:motamayez/providers/DebtProvider.dart';
import 'package:motamayez/providers/purchase_invoice_provider.dart';
import 'package:motamayez/providers/purchase_item_provider.dart';
import 'package:motamayez/providers/supplier_provider.dart';
import 'package:motamayez/providers/expense_provider.dart';

import 'package:motamayez/screens/auth/login.dart';
import 'package:motamayez/screens/home.dart';
import 'package:motamayez/screens/products.dart';
import 'package:motamayez/screens/pos_screen.dart';
import 'package:motamayez/screens/customers_screen.dart';
import 'package:motamayez/screens/SalesHistoryScreen.dart';
import 'package:motamayez/screens/reports_screen.dart';
import 'package:motamayez/screens/settings_screen.dart';
import 'package:motamayez/screens/purchase_invoice_page.dart';
import 'package:motamayez/screens/PurchaseInvoicesListPage.dart';
import 'package:motamayez/screens/csuppliers_list_page.dart';
import 'package:motamayez/screens/expenses_page.dart';
import 'package:motamayez/screens/activation_page.dart';
import 'package:motamayez/screens/invalid_signature_screen.dart';

// Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global AuthProvider reference
AuthProvider? globalAuthProvider;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();
    windowManager.setTitle('المتميز');
    windowManager.setMinimumSize(const Size(1000, 700));
  }

  final dbHelper = DBHelper();
  await dbHelper.db;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            globalAuthProvider = AuthProvider();
            return globalAuthProvider!;
          },
        ),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => SideBarProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseInvoiceProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseItemProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => TemporaryInvoiceProvider()),
        ChangeNotifierProvider(create: (_) => ProductBatchProvider()),
      ],
      child: const MotamayezApp(),
    ),
  );
}

class MotamayezApp extends StatefulWidget {
  const MotamayezApp({super.key});

  @override
  State<MotamayezApp> createState() => _MotamayezAppState();
}

class _MotamayezAppState extends State<MotamayezApp> with WindowListener {
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'المتميز',
      theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Poppins'),
      home: const AppEntry(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainScreen(),
        '/product': (_) => const ProductsScreen(),
        '/pos': (_) => const PosScreen(),
        '/customer': (_) => const CustomersScreen(),
        '/salesHistory': (_) => const SalesHistoryScreen(),
        '/report': (_) => const ReportsScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/purchaseInvoice': (_) => const PurchaseInvoicePage(),
        '/purchaseInvoicesList': (_) => const PurchaseInvoicesListPage(),
        '/suppliers': (_) => const SuppliersListPage(),
        '/expenses': (_) => const ExpensesPage(),
        '/activation': (_) => const ActivationPage(),
        '/invalidSignature': (_) => const InvalidSignatureScreen(),
      },
    );
  }
}

/// =================================================
/// 🔐 App Entry - نقطة الدخول الرئيسية مع فحص التفعيل
/// =================================================
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  late Future<Map<String, dynamic>> _activationCheck;

  @override
  void initState() {
    super.initState();
    _activationCheck = _checkActivation();
  }

  Future<Map<String, dynamic>> _checkActivation() async {
    try {
      final activationService = ActivationService();

      // محاولة الحصول على معلومات التفعيل
      final info = await activationService.getActivationInfo();

      // فحص التوقيع
      if (info['has_activation'] == true) {
        try {
          final isValid = await activationService.isActivated();
          return {
            ...info,
            'status': isValid ? 'valid' : 'invalid',
            'error': null,
          };
        } on ActivationException catch (e) {
          return {
            ...info,
            'status': 'invalid',
            'error': e,
            'stored_signature': e.storedSignature,
            'expected_signature': e.expectedSignature,
          };
        }
      }

      return {...info, 'status': 'not_activated', 'error': null};
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _activationCheck,
      builder: (context, snapshot) {
        // حالة التحميل
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // حالة الخطأ
        if (snapshot.hasError) {
          return _buildErrorScreen(snapshot.error.toString());
        }

        final data = snapshot.data!;
        final status = data['status'];

        switch (status) {
          case 'valid':
            // التفعيل صحيح - الانتقال لشاشة تسجيل الدخول
            return const LoginScreen();

          case 'invalid':
            // توقيع غير صحيح - عرض شاشة الخطأ
            return InvalidSignatureScreen(
              storedSignature: data['stored_signature']?.toString(),
              expectedSignature: data['expected_signature']?.toString(),
              activationCode: data['activation_code']?.toString(),
            );

          case 'not_activated':
            // لا يوجد تفعيل - الذهاب لصفحة التفعيل
            return const ActivationPage();

          default:
            return _buildErrorScreen('حالة غير معروفة: $status');
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
            const SizedBox(height: 20),
            const Text('جاري فحص التفعيل...', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text(
              'رقم الجهاز: ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, size: 60, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'خطأ في فحص التفعيل',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _activationCheck = _checkActivation();
                  });
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
