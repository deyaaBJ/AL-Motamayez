import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import 'package:shopmate/components/LoginCard.dart';
import 'package:shopmate/providers/auth_provider.dart';

void main() {
  runApp(const ShopMateApp());
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
    );
  }
}

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

    bool success = await authProvider.login(
      _emailController.text,
      _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الدخول بنجاح!'),
            backgroundColor: Colors.purple,
          ),
        );
        // مثال: انتقل للشاشة الرئيسية
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('البريد أو كلمة السر خاطئة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            // الخلفية المتحركة
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: BackgroundPainter(_animation.value),
                  size: Size.infinite,
                );
              },
            ),

            // محتوى صفحة تسجيل الدخول
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // الشعار
                          Container(
                            width: 120, // عرض الصورة
                            height: 120, // ارتفاع الصورة
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/shop_logo.png', // مسار الصورة
                                fit: BoxFit.fill, // تغطية كاملة للدائرة
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'ShopMate',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    LoginCard(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      isLoading: _isLoading,
                      onLogin: _login,
                    ),

                    const SizedBox(height: 30),

                    // حقوق النشر
                    const Text(
                      '© ShopMate POS. جميع الحقوق محفوظة',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// رسم الخلفية المتحركة
class BackgroundPainter extends CustomPainter {
  final double animationValue;

  BackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..style = PaintingStyle.fill;

    // دوائر متحركة في الخلفية
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // دائرة كبيرة تتحرك ببطء
    final circle1X = centerX + cos(animationValue) * 100;
    final circle1Y = centerY + sin(animationValue) * 80;
    canvas.drawCircle(Offset(circle1X, circle1Y), 120, paint);

    // دائرة متوسطة تتحرك في اتجاه معاكس
    final circle2X = centerX + cos(animationValue + pi) * 150;
    final circle2Y = centerY + sin(animationValue + pi) * 100;
    canvas.drawCircle(Offset(circle2X, circle2Y), 80, paint);

    // دوائر صغيرة
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
