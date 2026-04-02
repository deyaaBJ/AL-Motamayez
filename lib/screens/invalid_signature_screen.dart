import 'dart:io';

import 'package:flutter/material.dart';
import 'package:motamayez/screens/activation_page.dart';
import 'package:motamayez/services/activation_service.dart';
import 'package:window_manager/window_manager.dart';

class InvalidSignatureScreen extends StatelessWidget {
  const InvalidSignatureScreen({super.key});

  Future<void> _resetAndReactivate(BuildContext context) async {
    await ActivationService().clearActivation();

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ActivationPage()),
    );
  }

  void _closeApp() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.close();
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشكلة في التفعيل'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.security_update_warning_rounded,
                  size: 82,
                  color: Colors.red.shade600,
                ),
                const SizedBox(height: 20),
                const Text(
                  'تعذر التحقق من بيانات التفعيل على هذا الجهاز',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'غالبًا تم نقل نسخة البرنامج أو البيانات من جهاز آخر، أو أصبحت بيانات التفعيل الحالية غير مطابقة لهذا الجهاز. لا يمكن متابعة الدخول قبل إعادة التفعيل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سبب المشكلة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'بيانات التفعيل المحفوظة لا تطابق هذا الجهاز حاليًا، لذلك تم إيقاف الدخول لحماية الترخيص.',
                        style: TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الخطوات المطلوبة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '1. اضغط على "إعادة التفعيل".\n'
                        '2. سيتم نقلك إلى شاشة التفعيل.\n'
                        '3. أرسل طلب التفعيل وانتظر الموافقة.\n'
                        '4. أدخل كود التفعيل الصحيح ثم اضغط "تفعيل".\n'
                        '5. بعد النجاح سيُربط التفعيل بهذا الجهاز من جديد.',
                        style: TextStyle(fontSize: 15, height: 1.7),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _resetAndReactivate(context),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة التفعيل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _closeApp,
                      icon: const Icon(Icons.exit_to_app_rounded),
                      label: const Text('إغلاق البرنامج'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
