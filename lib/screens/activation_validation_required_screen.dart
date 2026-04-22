import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class ActivationValidationRequiredScreen extends StatelessWidget {
  const ActivationValidationRequiredScreen({
    super.key,
    this.message,
    this.onRetry,
  });

  final String? message;
  final VoidCallback? onRetry;

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
        title: const Text('فحص التفعيل مطلوب'),
        backgroundColor: Colors.orange.shade700,
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
                  Icons.wifi_find_rounded,
                  size: 82,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(height: 20),
                const Text(
                  'يلزم الاتصال بالإنترنت لإكمال فحص التفعيل المؤقت',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      'يرجى تشغيل الإنترنت ثم إعادة المحاولة حتى نتحقق من صلاحية التفعيل المؤقت.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
                  child: const Text(
                    'هذا الفحص يطبق فقط على التفعيل المؤقت. بعد نجاح التحقق سيُسمح لك بمتابعة الدخول بشكل طبيعي حسب إعدادات الفحص.',
                    style: TextStyle(fontSize: 15, height: 1.7),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
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
