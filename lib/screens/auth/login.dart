import 'package:flutter/material.dart';
import 'package:motamayez/components/login_card.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/screens/activation_page.dart';
import 'package:motamayez/screens/internet_connection_check_screen.dart';
import 'package:motamayez/services/activation_service.dart';
import 'package:motamayez/services/license_session_guard.dart';
import 'package:motamayez/widgets/whatsapp_support_button.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ActivationService _activationService = ActivationService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final AuthProvider authProvider;

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isLoadingCredentials = true;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<AuthProvider>(context, listen: false);
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final savedCreds = await authProvider.getSavedCredentialsForLogin();

    if (!mounted) return;

    if (savedCreds != null) {
      setState(() {
        _emailController.text = savedCreds['email'] ?? '';
        _rememberMe = true;
      });
    }

    setState(() {
      _isLoadingCredentials = false;
    });
  }

  Future<void> _handleActivationRetry() async {
    final activationInfo = await _activationService.getActivationInfo(
      forceServerValidation: true,
    );
    final activationStatus = activationInfo['status']?.toString();

    if (!mounted) return;

    if (activationStatus == 'valid' || activationStatus == 'grace_period') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    if (activationStatus == 'not_activated' || activationStatus == 'expired') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (context) => ActivationPage(
                initialMessage: activationInfo['signature_details']?.toString(),
                renewalMode: activationStatus == 'expired',
              ),
        ),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (context) => InternetConnectionCheckScreen(
              bannerText: 'باقي 5 دقائق على فحص الإنترنت قبل التفعيل',
              onRetry: () async {
                final retry = await _activationService.getActivationInfo(
                  forceServerValidation: true,
                );
                final retryStatus = retry['status']?.toString();
                if (retryStatus == 'valid' || retryStatus == 'grace_period') {
                  return true;
                }
                if (retryStatus == 'not_activated' ||
                    retryStatus == 'expired') {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder:
                          (context) => ActivationPage(
                            initialMessage:
                                retry['signature_details']?.toString(),
                            renewalMode: retryStatus == 'expired',
                          ),
                    ),
                    (route) => false,
                  );
                  return true;
                }
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder:
                        (context) => ActivationPage(
                          initialMessage: retry['signature_details']?.toString(),
                        ),
                  ),
                  (route) => false,
                );
                return true;
              },
            ),
      ),
      (route) => false,
    );
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    var activationInfo = await _activationService.getActivationInfo(
      forceServerValidation: false,
    );
    var activationStatus = activationInfo['status']?.toString();

    if (activationStatus != 'valid' && activationStatus != 'grace_period') {
      if (activationStatus == 'session_only' ||
          activationStatus == 'needs_revalidation' ||
          activationStatus == 'clock_tampering_detected' ||
          activationStatus == 'runtime_suspicious') {
        activationInfo = await _activationService.getActivationInfo(
          forceServerValidation: true,
        );
        activationStatus = activationInfo['status']?.toString();
      }
    }

    if (activationStatus != 'valid' && activationStatus != 'grace_period') {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (context) => ActivationPage(
                initialMessage: activationInfo['signature_details']?.toString(),
                renewalMode: activationStatus == 'expired',
              ),
        ),
        (route) => false,
      );
      return;
    }

    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      await _activationService.markSessionStarted();
      if (!mounted) return;
      LicenseSessionGuard.instance.start(
        authProvider: authProvider,
        navigator: Navigator.of(context),
      );
      showAppToast(context, 'تم تسجيل الدخول بنجاح!', ToastType.success);
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      showAppToast(context, 'البريد أو كلمة السر خاطئة', ToastType.error);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildLoginContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 136,
          height: 136,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
            border: Border.all(
              color: Colors.white.withOpacity(0.58),
              width: 2.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipOval(
            child: ColoredBox(
              color: Colors.white,
              child: Image.asset(
                'assets/images/shop_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.24)),
          ),
          child: const Text(
            'المتميز',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              letterSpacing: 1,
              fontSize: 42,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(2, 2),
                  blurRadius: 5,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _isLoadingCredentials
            ? const Column(
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 10),
                Text(
                  'جاري تحميل البيانات...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            )
            : LoginCard(
              emailController: _emailController,
              passwordController: _passwordController,
              isLoading: _isLoading,
              onLogin: _login,
              rememberMe: _rememberMe,
              onRememberMeChanged: (value) {
                setState(() {
                  _rememberMe = value;
                });
              },
            ),
        const SizedBox(height: 30),
        const Text(
          '© Motamayez POS. جميع الحقوق محفوظة',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: const WhatsAppSupportButton(
        heroTag: 'login_whatsapp_support',
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B5FBF), Color(0xFF6A3093), Color(0xFF4A1C6D)],
          ),
        ),
        child: Stack(
          children: [
            const RepaintBoundary(
              child: CustomPaint(
                painter: BackgroundPainter(),
                size: Size.infinite,
              ),
            ),
            RepaintBoundary(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: _buildLoginContent(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  const BackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          // ignore: deprecated_member_use
          ..color = Colors.white.withOpacity(0.05)
          ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    canvas.drawCircle(Offset(centerX - 120, centerY - 120), 120, paint);
    canvas.drawCircle(Offset(centerX + 140, centerY - 80), 80, paint);
    canvas.drawCircle(Offset(centerX - 160, centerY + 120), 60, paint);
    canvas.drawCircle(Offset(centerX + 170, centerY + 130), 40, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
