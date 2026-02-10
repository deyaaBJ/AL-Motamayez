import 'dart:io';
import 'package:flutter/material.dart';
import 'package:motamayez/providers/DebtProvider.dart';
import 'package:motamayez/providers/cashier_activity_provider.dart';
import 'package:motamayez/screens/PurchaseInvoicesListPage.dart';
import 'package:motamayez/screens/SalesHistoryScreen.dart';
import 'package:motamayez/screens/cashier_activity_screen.dart';
import 'package:motamayez/screens/csuppliers_list_page.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:developer';

import 'db/db_helper.dart';
import 'providers/auth_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/product_provider.dart';
import 'providers/sidebar_provider.dart';
import 'providers/purchase_invoice_provider.dart';
import 'providers/purchase_item_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/temporary_invoice_provider.dart';
import 'providers/batch_provider.dart';

import 'screens/auth/login.dart';
import 'screens/home.dart';
import 'screens/products.dart';
import 'screens/pos_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/purchase_invoice_page.dart';

import 'screens/expenses_page.dart';
import 'screens/activation_page.dart';
import 'screens/invalid_signature_screen.dart';
import 'screens/batches_screen.dart';
import 'services/activation_service.dart';
import 'package:intl/date_symbol_data_local.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  await ('ar', null);

  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();
    await windowManager.setTitle('المتميز');
    await windowManager.setMinimumSize(const Size(1000, 700));
  }

  final dbHelper = DBHelper();
  await dbHelper.db;

  final authProvider = AuthProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
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
        ChangeNotifierProvider(create: (_) => BatchProvider()),
        ChangeNotifierProvider(create: (_) => CashierActivityProvider()),
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
  void onWindowClose() async {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.isLoggedIn) {
      log('🔄 Creating backup before window close...');
      await authProvider.backupAndCleanOnClose();
    }

    await windowManager.destroy();
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
        '/batches': (_) => const BatchesScreen(),
        '/cashier': (_) => const CashierActivityScreen(),
      },
    );
  }
}

/// =================================================
/// App Entry - نقطة الدخول مع فحص التفعيل
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
      final info = await activationService.getActivationInfo();

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasError) {
          return _buildErrorScreen(snapshot.error.toString());
        }

        final data = snapshot.data!;
        final status = data['status'];

        switch (status) {
          case 'valid':
            return const LoginScreen();

          case 'invalid':
            return InvalidSignatureScreen(
              storedSignature: data['stored_signature']?.toString(),
              expectedSignature: data['expected_signature']?.toString(),
              activationCode: data['activation_code']?.toString(),
            );

          case 'not_activated':
            return const ActivationPage();

          default:
            return _buildErrorScreen('حالة غير معروفة: $status');
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
            SizedBox(height: 20),
            Text('جاري فحص التفعيل...', style: TextStyle(fontSize: 18)),
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
