// ignore: file_names
import 'package:flutter/material.dart';
import 'package:motamayez/widgets/text_field.dart';

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
            // ignore: deprecated_member_use
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '\u062A\u0633\u062C\u064A\u0644 \u0627\u0644\u062F\u062E\u0648\u0644',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A3093),
            ),
          ),
          const SizedBox(height: 30),
          CustomTextField(
            controller: widget.emailController,
            label: '\u0627\u0633\u0645 \u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645',
            prefixIcon: Icons.person,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          CustomTextField(
            controller: widget.passwordController,
            label: '\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631',
            prefixIcon: Icons.lock,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!widget.isLoading) {
                widget.onLogin();
              }
            },
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
                '\u062A\u0630\u0643\u0631\u0646\u064A',
                style: TextStyle(fontSize: 14, color: Color(0xFF6A3093)),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                // ignore: deprecated_member_use
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
                        '\u062A\u0633\u062C\u064A\u0644 \u0627\u0644\u062F\u062E\u0648\u0644',
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
