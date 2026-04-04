import 'dart:math';

import 'package:flutter/material.dart';
import 'package:motamayez/components/login_card.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/widgets/whatsapp_support_button.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _fadeAnimation;
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

    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final savedCreds = await authProvider.getSavedCredentialsForLogin();

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

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() {
      _isLoading = true;
    });

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
      showAppToast(context, 'تم تسجيل الدخول بنجاح!', ToastType.success);
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      showAppToast(context, 'البريد أو كلمة السر خاطئة', ToastType.error);
    }
  }

  Widget _buildLoginContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/shop_logo.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'المتميز',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.0,
                  fontSize: 50,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(3, 3),
                      blurRadius: 6,
                      color: Colors.black45,
                    ),
                    Shadow(
                      offset: Offset(-2, -2),
                      blurRadius: 4,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
            ],
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
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: BackgroundPainter(_animation.value),
                  size: Size.infinite,
                );
              },
            ),
            Center(
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
          ],
        ),
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final double animationValue;

  BackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          // ignore: deprecated_member_use
          ..color = Colors.white.withOpacity(0.05)
          ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final circle1X = centerX + cos(animationValue) * 100;
    final circle1Y = centerY + sin(animationValue) * 80;
    canvas.drawCircle(Offset(circle1X, circle1Y), 120, paint);

    final circle2X = centerX + cos(animationValue + pi) * 150;
    final circle2Y = centerY + sin(animationValue + pi) * 100;
    canvas.drawCircle(Offset(circle2X, circle2Y), 80, paint);

    final circle3X = centerX + cos(animationValue * 1.5) * 200;
    final circle3Y = centerY + sin(animationValue * 1.5) * 150;
    canvas.drawCircle(Offset(circle3X, circle3Y), 60, paint);

    final circle4X = centerX + cos(animationValue * 0.7) * 250;
    final circle4Y = centerY + sin(animationValue * 0.7) * 120;
    canvas.drawCircle(Offset(circle4X, circle4Y), 40, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
