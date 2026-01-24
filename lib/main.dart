// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:motamayez/providers/temporary_invoice_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:window_manager/window_manager.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'dart:developer';

// import 'package:motamayez/db/db_helper.dart';
// import 'package:motamayez/providers/auth_provider.dart';
// import 'package:motamayez/providers/customer_provider.dart';
// import 'package:motamayez/providers/sales_provider.dart';
// import 'package:motamayez/providers/reports_provider.dart';
// import 'package:motamayez/providers/settings_provider.dart';
// import 'package:motamayez/providers/product_provider.dart';
// import 'package:motamayez/providers/sidebar_provider.dart';
// import 'package:motamayez/providers/DebtProvider.dart';
// import 'package:motamayez/providers/purchase_invoice_provider.dart';
// import 'package:motamayez/providers/purchase_item_provider.dart';
// import 'package:motamayez/providers/supplier_provider.dart';
// import 'package:motamayez/providers/expense_provider.dart';

// import 'package:motamayez/screens/auth/login.dart';
// import 'package:motamayez/screens/home.dart';
// import 'package:motamayez/screens/products.dart';
// import 'package:motamayez/screens/pos_screen.dart';
// import 'package:motamayez/screens/customers_screen.dart';
// import 'package:motamayez/screens/SalesHistoryScreen.dart';
// import 'package:motamayez/screens/reports_screen.dart';
// import 'package:motamayez/screens/settings_screen.dart';
// import 'package:motamayez/screens/purchase_invoice_page.dart';
// import 'package:motamayez/screens/PurchaseInvoicesListPage.dart';
// import 'package:motamayez/screens/csuppliers_list_page.dart';
// import 'package:motamayez/screens/expenses_page.dart';

// // Navigator Key
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// // Global AuthProvider reference
// AuthProvider? globalAuthProvider;

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
//     sqfliteFfiInit();
//     databaseFactory = databaseFactoryFfi;

//     await windowManager.ensureInitialized();
//     windowManager.setTitle('المتميز');
//     windowManager.setMinimumSize(const Size(1000, 700));
//   }

//   final dbHelper = DBHelper();
//   await dbHelper.db;

//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(
//           create: (_) {
//             globalAuthProvider = AuthProvider();
//             return globalAuthProvider!;
//           },
//         ),
//         ChangeNotifierProvider(create: (_) => CustomerProvider()),
//         ChangeNotifierProvider(create: (_) => SalesProvider()),
//         ChangeNotifierProvider(create: (_) => ReportsProvider()),
//         ChangeNotifierProvider(create: (_) => SettingsProvider()),
//         ChangeNotifierProvider(create: (_) => ProductProvider()),
//         ChangeNotifierProvider(create: (_) => SideBarProvider()),
//         ChangeNotifierProvider(create: (_) => DebtProvider()),
//         ChangeNotifierProvider(create: (_) => PurchaseInvoiceProvider()),
//         ChangeNotifierProvider(create: (_) => PurchaseItemProvider()),
//         ChangeNotifierProvider(create: (_) => SupplierProvider()),
//         ChangeNotifierProvider(create: (_) => ExpenseProvider()),
//         ChangeNotifierProvider(create: (_) => TemporaryInvoiceProvider()),
//       ],
//       child: const MotamayezApp(),
//     ),
//   );
// }

// class MotamayezApp extends StatefulWidget {
//   const MotamayezApp({super.key});

//   @override
//   State<MotamayezApp> createState() => _MotamayezAppState();
// }

// class _MotamayezAppState extends State<MotamayezApp> with WindowListener {
//   bool _isClosing = false;

//   @override
//   void initState() {
//     super.initState();
//     windowManager.addListener(this);
//   }

//   @override
//   void dispose() {
//     windowManager.removeListener(this);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       navigatorKey: navigatorKey,
//       debugShowCheckedModeBanner: false,
//       title: 'المتميز',
//       theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Poppins'),
//       home: const LoginScreen(),
//       routes: {
//         '/login': (_) => const LoginScreen(),
//         '/home': (_) => const MainScreen(),
//         '/product': (_) => const ProductsScreen(),
//         '/pos': (_) => const PosScreen(),
//         '/customer': (_) => const CustomersScreen(),
//         '/salesHistory': (_) => const SalesHistoryScreen(),
//         '/report': (_) => const ReportsScreen(),
//         '/settings': (_) => const SettingsScreen(),
//         '/purchaseInvoice': (_) => const PurchaseInvoicePage(),
//         '/purchaseInvoicesList': (_) => const PurchaseInvoicesListPage(),
//         '/suppliers': (_) => const SuppliersListPage(),
//         '/expenses': (_) => const ExpensesPage(),
//       },
//     );
//   }
// }

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:motamayez/db/db_helper.dart';
import 'package:motamayez/services/activation_service.dart';

// Providers
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
import 'package:motamayez/providers/temporary_invoice_provider.dart';

// Screens
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

// Navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite for Desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();
    windowManager.setTitle('المتميز');
    windowManager.setMinimumSize(const Size(1000, 700));
  }

  // تأكد من فتح الداتا بيس
  final dbHelper = DBHelper();
  await dbHelper.db;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
      ],
      child: const MotamayezApp(),
    ),
  );
}

class MotamayezApp extends StatelessWidget {
  const MotamayezApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'المتميز',
      theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Poppins'),

      /// 🔐 نقطة الدخول الوحيدة
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
      },
    );
  }
}

/// =================================================
/// 🔐 App Entry – فحص التفعيل قبل أي شيء
/// =================================================
class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ActivationService().isActivated(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // توقيع موجود لكن غير صالح → نوقف البرنامج
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.block, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // فيه توقيع صحيح
        if (snapshot.data == true) {
          return const LoginScreen();
        }

        // لا يوجد توقيع → أول تشغيل
        return const ActivationPage();
      },
    );
  }
}
