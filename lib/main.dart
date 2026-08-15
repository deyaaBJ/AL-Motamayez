import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:motamayez/constant/constant.dart';
import 'package:motamayez/providers/debt_provider.dart';
import 'package:motamayez/providers/cashier_activity_provider.dart';
import 'package:motamayez/screens/purchase_invoices_list_page.dart';
import 'package:motamayez/screens/sales_history_screen.dart';
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
import 'providers/opening_balance_provider.dart';
import 'services/local_backup_service.dart';
import 'services/update_service.dart';

import 'screens/auth/login.dart';
import 'screens/home.dart';
import 'screens/products.dart';
import 'screens/pos/pos_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/purchase_invoice_page.dart';

import 'screens/expenses_page.dart';
import 'screens/activation_page.dart';
import 'screens/internet_connection_check_screen.dart';
import 'screens/batches_screen.dart';
import 'screens/opening_balance_screen.dart';
import 'services/activation_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'widgets/license_session_warning_banner.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  // تهيئة التواريخ العربية
  await initializeDateFormatting('ar', null);

  // تهيئة Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // ========== تهيئة Windows ==========
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // تهيئة قاعدة البيانات
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // تهيئة النافذة
    await windowManager.ensureInitialized();
    await windowManager.setTitle('المتميز');
    await windowManager.setMinimumSize(const Size(1000, 600));
  }

  if (Platform.isWindows) {
    FlutterError.onError = (FlutterErrorDetails details) {
      final errorMessage = details.exceptionAsString();

      if (errorMessage.contains('viewId') ||
          errorMessage.contains('Accessibility') ||
          errorMessage.contains('accessibility_plugin') ||
          errorMessage.contains('FlutterViewId')) {
        return;
      }

      FlutterError.dumpErrorToConsole(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      final errorStr = error.toString();
      if (errorStr.contains('viewId') ||
          errorStr.contains('Accessibility') ||
          errorStr.contains('accessibility_plugin')) {
        return true;
      }
      return false;
    };
  }

  // ========== تهيئة قاعدة البيانات ==========
  final dbHelper = DBHelper();
  await dbHelper.db;

  // ========== تهيئة Auth Provider ==========
  final authProvider = AuthProvider();

  // ========== تشغيل التطبيق ==========
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
        ChangeNotifierProvider(create: (_) => OpeningBalanceProvider()),
        ChangeNotifierProvider(create: (_) => CashierActivityProvider()),
        ChangeNotifierProvider(create: (_) => LocalBackupService()),
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
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LocalBackupService>().init();
      unawaited(_checkForAppUpdate());
    });
  }

  Future<void> _checkForAppUpdate() async {
    if (!Platform.isWindows) return;

    try {
      final info = await UpdateService().checkForUpdate();
      if (!mounted || info == null || !info.hasUpdate) return;

      final shouldUpdate = await showDialog<bool>(
        context: navigatorKey.currentContext ?? context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تحديث جديد متوفر'),
              content: Text(
                'يوجد إصدار أحدث للتطبيق.\n'
                'الإصدار الحالي: ${info.currentVersion}\n'
                'الإصدار الجديد: ${info.tagName}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('تحديث لاحقاً'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('تحديث الآن'),
                ),
              ],
            ),
          );
        },
      );

      if (shouldUpdate == true) {
        final messenger = ScaffoldMessenger.maybeOf(
          navigatorKey.currentContext ?? context,
        );
        messenger?.showSnackBar(
          const SnackBar(content: Text('جارٍ تنزيل التحديث وتثبيته...')),
        );

        final installed = await UpdateService().downloadAndInstall(info);
        if (installed && mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            exit(0);
          });
        }
      }
    } catch (_) {
      // فشل التحديث لا يجب أن يمنع فتح التطبيق.
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
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

  // main.dart
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      title: 'المتميز',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LicenseSessionWarningBanner(),
            ),
          ],
        );
      },
      home: const AppEntry(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainScreen(),
        '/product': (_) => const ProductsScreen(),
        '/products': (_) => const ProductsScreen(), // ✅ أضف هذا
        '/pos': (_) => const PosScreen(),
        '/customer': (_) => const CustomersScreen(),
        '/customers': (_) => const CustomersScreen(), // ✅ أضف هذا
        '/salesHistory': (_) => const SalesHistoryScreen(),
        '/report': (_) => const ReportsScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/purchaseInvoice': (_) => const PurchaseInvoicePage(),
        '/purchaseInvoicesList': (_) => const PurchaseInvoicesListPage(),
        '/suppliers': (_) => const SuppliersListPage(),
        '/expenses': (_) => const ExpensesPage(),
        '/activation': (_) => const ActivationPage(),
        '/batches': (_) => const BatchesScreen(),
        '/openingBalance': (_) => const OpeningBalanceScreen(),
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
  late Future<Map<String, dynamic>> _activationCheck = Future.value({
    'status': 'loading',
  });
  String? _activationWarningLabel;
  bool _showActivationWarning = false;
  DateTime? _warningDeadline;
  bool _lastKnownInternet = true;
  bool _requiresActivationCheckGate = false;
  Timer? _activationDeadlineTimer;

  @override
  void initState() {
    super.initState();
    _bootstrapActivationFlow();
  }

  @override
  void dispose() {
    _activationDeadlineTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapActivationFlow() async {
    final localInfo = await ActivationService().getInitialActivationInfo();
    if (!mounted) return;
    _updateActivationWarning(localInfo);
    _requiresActivationCheckGate = _needsActivationGate(localInfo);
    final hasInternet = await _hasInternetConnection();
    if (!mounted) return;
    _lastKnownInternet = hasInternet;

    setState(() {
      _activationCheck = Future.value(_activationInfoForStartup(localInfo));
    });
  }

  bool _needsActivationGate(Map<String, dynamic> info) {
    final status = info['status']?.toString();
    return status == 'session_only' ||
        status == 'needs_revalidation' ||
        status == 'clock_tampering_detected' ||
        status == 'runtime_suspicious';
  }

  void _updateActivationWarning(Map<String, dynamic> info) {
    _activationDeadlineTimer?.cancel();
    _activationDeadlineTimer = null;

    final status = info['status']?.toString();
    final now = DateTime.now();

    DateTime? deadline;
    if (status == 'expired') {
      final expiresAt = info['expires_at']?.toString();
      deadline = expiresAt == null ? null : DateTime.tryParse(expiresAt);
    } else {
      final nextRevalidationAt = info['next_revalidation_at']?.toString();
      deadline =
          nextRevalidationAt == null
              ? null
              : DateTime.tryParse(nextRevalidationAt);
      final offlineGraceUntil = info['offline_grace_until']?.toString();
      final graceDeadline =
          offlineGraceUntil == null
              ? null
              : DateTime.tryParse(offlineGraceUntil);
      if (deadline == null ||
          (graceDeadline != null && graceDeadline.isBefore(deadline))) {
        deadline = graceDeadline;
      }
    }

    final warningAt =
        deadline == null ? null : deadline.subtract(const Duration(minutes: 5));
    final shouldShowWarning =
        deadline != null &&
        warningAt != null &&
        !warningAt.isAfter(now) &&
        deadline.isAfter(now);

    if (!mounted) return;
    setState(() {
      _warningDeadline = deadline;
      _showActivationWarning = shouldShowWarning;
      _activationWarningLabel =
          shouldShowWarning
              ? 'تنبيه: متبقي 5 دقائق على فحص الإنترنت قبل التفعيل'
              : null;
    });

    if (deadline != null && _activationDeadlineTimer == null) {
      final delay =
          warningAt != null && warningAt.isAfter(now)
              ? warningAt.difference(now)
              : const Duration(seconds: 1);
      _activationDeadlineTimer = Timer(delay, () {
        if (!mounted) return;
        setState(() {
          _showActivationWarning = false;
          _activationWarningLabel = null;
        });
        _activationDeadlineTimer?.cancel();
        _activationDeadlineTimer = null;
        _activationCheck = _checkActivation(forceServerValidation: true);
      });
    }
  }

  Map<String, dynamic> _offlineActivationResult(Map<String, dynamic> info) {
    final status = info['status']?.toString() ?? 'not_activated';
    if (status == 'valid' || status == 'grace_period') {
      return {
        'status': status,
        'activation_type': info['activation_type'],
        'remaining_days': info['remaining_days'],
        'message': info['signature_details']?.toString(),
      };
    }

    if (status == 'expired') {
      return {
        'status': 'expired',
        'message':
            'انتهت مدة الاشتراك. يرجى إرسال طلب تجديد ثم إدخال كود التفعيل الجديد بعد الموافقة.',
      };
    }

    if (status == 'needs_revalidation' ||
        status == 'session_only' ||
        status == 'clock_tampering_detected' ||
        status == 'runtime_suspicious') {
      return {
        'status': status,
        'message': info['signature_details']?.toString(),
      };
    }

    return {'status': status};
  }

  Map<String, dynamic> _activationInfoForStartup(
    Map<String, dynamic> localInfo,
  ) {
    final status = localInfo['status']?.toString();

    if (status == 'valid' || status == 'grace_period') {
      return {
        'status': status,
        'activation_type': localInfo['activation_type'],
        'remaining_days': localInfo['remaining_days'],
        'message': localInfo['signature_details']?.toString(),
      };
    }

    if (status == 'not_activated') {
      return {'status': 'not_activated'};
    }

    if (status == 'expired') {
      return {
        'status': 'expired',
        'message': localInfo['signature_details']?.toString(),
      };
    }

    if (status == 'session_only' ||
        status == 'needs_revalidation' ||
        status == 'clock_tampering_detected' ||
        status == 'runtime_suspicious') {
      return {
        'status': status,
        'message': localInfo['signature_details']?.toString(),
      };
    }

    return {
      'status': status ?? 'not_activated',
      'message': localInfo['signature_details']?.toString(),
    };
  }

  Future<bool> _retryConnectivityAndActivation() async {
    final hasInternet = await _hasInternetConnection();
    if (!mounted) return false;

    if (!hasInternet) {
      setState(() {
        _lastKnownInternet = false;
      });
      return false;
    }

    setState(() {
      _lastKnownInternet = true;
      _activationCheck = _checkActivation(forceServerValidation: true);
    });
    return true;
  }

  // main.dart - AppEntry
  Future<Map<String, dynamic>> _checkActivation({
    bool forceServerValidation = false,
  }) async {
    try {
      final activationService = ActivationService();
      var info = await activationService.getActivationInfo(
        forceServerValidation: forceServerValidation,
      );

      var status = info['status'];
      var signatureDetails = info['signature_details']?.toString();

      var hasActivation = info['has_activation'] == true;

      if (!forceServerValidation &&
          status is String &&
          (status == 'session_only' ||
              status == 'needs_revalidation' ||
              status == 'clock_tampering_detected' ||
              status == 'runtime_suspicious')) {
        final serverInfo = await activationService.getActivationInfo(
          forceServerValidation: true,
        );
        final serverStatus = serverInfo['status'];
        if (serverStatus == 'valid' || serverStatus == 'grace_period') {
          return {
            'status': serverStatus,
            'activation_type': serverInfo['activation_type'],
            'remaining_days': serverInfo['remaining_days'],
            'message': serverInfo['signature_details']?.toString(),
          };
        }

        info = serverInfo;
        status = info['status'];
        signatureDetails = info['signature_details']?.toString();
        hasActivation = info['has_activation'] == true;
      }

      if (!hasActivation) {
        _updateActivationWarning(info);
        return {'status': 'not_activated'};
      }

      switch (status) {
        case 'valid':
        case 'grace_period':
          _updateActivationWarning(info);
          return {
            'status': status,
            'activation_type': info['activation_type'],
            'remaining_days': info['remaining_days'],
            'message': signatureDetails ?? info['message']?.toString(),
          };

        case 'session_only':
        case 'needs_revalidation':
        case 'clock_tampering_detected':
        case 'runtime_suspicious':
        case 'not_activated':
          _updateActivationWarning(info);
          return {
            'status': status,
            'message': signatureDetails ?? info['message']?.toString(),
          };

        case 'invalid':
        case 'expired':
          _updateActivationWarning(info);
          return {
            'status': 'expired',
            'message':
                info['message']?.toString() ??
                signatureDetails ??
                'انتهت مدة الاشتراك. يرجى إرسال طلب تجديد ثم إدخال كود التفعيل الجديد بعد الموافقة.',
          };

        case 'error':
          _updateActivationWarning(info);
          return {
            'status': hasActivation ? 'error' : 'not_activated',
            'error':
                info['error']?.toString() ??
                signatureDetails ??
                status?.toString(),
          };

        default:
          _updateActivationWarning(info);
          return {
            'status': 'error',
            'error':
                info['error']?.toString() ??
                signatureDetails ??
                status?.toString(),
          };
      }
    } catch (e) {
      try {
        final fallback = await ActivationService().getInitialActivationInfo();
        _updateActivationWarning(fallback);
        final fallbackStatus = fallback['status']?.toString();
        if (fallbackStatus == 'valid' || fallbackStatus == 'grace_period') {
          return {
            'status': fallbackStatus,
            'activation_type': fallback['activation_type'],
            'remaining_days': fallback['remaining_days'],
            'message': fallback['signature_details']?.toString(),
          };
        }

        if (fallbackStatus == 'expired') {
          return {
            'status': 'expired',
            'message':
                'انتهت مدة الاشتراك. يرجى إرسال طلب تجديد ثم إدخال كود التفعيل الجديد بعد الموافقة.',
          };
        }

        if (fallbackStatus == 'needs_revalidation' ||
            fallbackStatus == 'session_only' ||
            fallbackStatus == 'clock_tampering_detected' ||
            fallbackStatus == 'runtime_suspicious') {
          return {
            'status': fallbackStatus,
            'message': fallback['signature_details']?.toString(),
          };
        }
      } catch (_) {}
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final uri = Uri.parse(AppConstants.activationBaseUrl);
      final host = uri.host;
      if (host.isEmpty) return false;

      final addresses = await InternetAddress.lookup(host);
      return addresses.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content =
        !_lastKnownInternet && _requiresActivationCheckGate
            ? InternetConnectionCheckScreen(
              onRetry: _retryConnectivityAndActivation,
            )
            : FutureBuilder<Map<String, dynamic>>(
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
                  case 'grace_period':
                    return const LoginScreen();

                  case 'session_only':
                  case 'needs_revalidation':
                  case 'clock_tampering_detected':
                  case 'runtime_suspicious':
                    return _lastKnownInternet
                        ? ActivationPage(
                          initialMessage: data['message']?.toString(),
                        )
                        : InternetConnectionCheckScreen(
                          onRetry: _retryConnectivityAndActivation,
                        );

                  case 'not_activated':
                    return _lastKnownInternet
                        ? ActivationPage(
                          initialMessage: data['message']?.toString(),
                        )
                        : InternetConnectionCheckScreen(
                          onRetry: _retryConnectivityAndActivation,
                        );

                  case 'expired':
                    return ActivationPage(
                      initialMessage: data['message']?.toString(),
                      renewalMode: true,
                    );

                  case 'error':
                    return _lastKnownInternet
                        ? ActivationPage(
                          initialMessage:
                              data['error']?.toString() ??
                              'تعذر قراءة حالة التفعيل',
                        )
                        : InternetConnectionCheckScreen(
                          onRetry: _retryConnectivityAndActivation,
                        );

                  default:
                    return ActivationPage(
                      initialMessage: data['message']?.toString(),
                    );
                }
              },
            );

    return Stack(
      children: [
        content,
        if (_showActivationWarning && _activationWarningLabel != null)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _ActivationWarningStrip(
              label: _activationWarningLabel!,
              deadline: _warningDeadline,
            ),
          ),
      ],
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

class _ActivationWarningStrip extends StatelessWidget {
  const _ActivationWarningStrip({required this.label, required this.deadline});

  final String label;
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFFF7ED),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFFC2410C),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  deadline == null ? label : '$label',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

