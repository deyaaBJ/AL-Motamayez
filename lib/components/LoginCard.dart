import 'package:flutter/material.dart';
import 'package:motamayez/widgets/TextField.dart';

class LoginCard extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final Function() onLogin;
  final bool rememberMe;
  final ValueChanged<bool>? onRememberMeChanged;

  const LoginCard({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
    this.rememberMe = false,
    this.onRememberMeChanged,
  });

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          MediaQuery.of(context).size.width > 600
              ? 500
              : MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'تسجيل الدخول',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A3093),
            ),
          ),
          const SizedBox(height: 30),

          // ✅ حقل الإيميل - معبأ تلقائياً
          CustomTextField(
            controller: widget.emailController,
            label: 'اسم المستخدم',
            prefixIcon: Icons.person,
          ),

          const SizedBox(height: 20),

          // ✅ حقل الباسورد - معبأ تلقائياً
          CustomTextField(
            controller: widget.passwordController,
            label: 'كلمة المرور',
            prefixIcon: Icons.lock,
            obscureText: !_isPasswordVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF8B5FBF),
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          // ✅ تذكرني
          Row(
            children: [
              Checkbox(
                value: widget.rememberMe,
                onChanged: (value) {
                  widget.onRememberMeChanged?.call(value ?? false);
                },
                activeColor: const Color(0xFF8B5FBF),
              ),
              const Text(
                'تذكرني',
                style: TextStyle(fontSize: 14, color: Color(0xFF6A3093)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ زر تسجيل الدخول - أنت بس بتكبس
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5FBF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                shadowColor: Colors.purple.withOpacity(0.5),
              ),
              child:
                  widget.isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
