import 'package:flutter/material.dart';
import 'package:motamayez/screens/auth/login.dart';
import 'package:motamayez/services/activation_service.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _activate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _error = 'الرجاء إدخال كود التفعيل';
        _loading = false;
      });
      return;
    }

    try {
      print('🚀 بدء عملية التفعيل...');
      final activationService = ActivationService();
      final success = await activationService.activate(code);
      print('📊 نتيجة التفعيل: $success');

      if (success) {
        print('✅ تم التفعيل بنجاح، الانتقال إلى صفحة الدخول...');

        if (!mounted) return;

        // استخدام Navigator.of(context) بدلاً من pushReplacementNamed
        // لإضافة تأخير بسيط لضمان اكتمال العمليات
        await Future.delayed(const Duration(milliseconds: 1000));

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        print('❌ كود التفعيل غير صحيح');
        setState(() {
          _error = 'كود التفعيل غير صحيح';
        });
      }
    } catch (e) {
      print('❌ حدث خطأ أثناء التفعيل: $e');
      setState(() {
        _error = 'حدث خطأ أثناء التفعيل';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تفعيل برنامج المتميز',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'كود التفعيل',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _activate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      child:
                          _loading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text('تفعيل'),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed:
                        _loading
                            ? null
                            : () async {
                              final service = ActivationService();
                              await service.checkDatabase();
                            },
                    child: const Text(
                      'فحص قاعدة البيانات',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
