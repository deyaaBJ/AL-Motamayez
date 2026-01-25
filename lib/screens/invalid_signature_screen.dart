import 'dart:io';
import 'package:flutter/material.dart';
import 'package:motamayez/screens/activation_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:motamayez/services/activation_service.dart';

class InvalidSignatureScreen extends StatelessWidget {
  final String? storedSignature;
  final String? expectedSignature;
  final String? activationCode;

  const InvalidSignatureScreen({
    super.key,
    this.storedSignature,
    this.expectedSignature,
    this.activationCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خطأ في التفعيل'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // أيقونة الخطأ
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 24),

            // رسالة الخطأ الرئيسية
            const Text(
              '❌ التوقيع غير صحيح',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            const Text(
              'لا تملك صلاحية الدخول إلى التطبيق',
              style: TextStyle(fontSize: 18, color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // معلومات تفصيلية (اختياري)
            if (storedSignature != null || expectedSignature != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  //    border: Border.all(color: Colors.grey[300]),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات التفعيل:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (activationCode != null)
                      Row(
                        children: [
                          const Text('كود التفعيل: '),
                          SelectableText(
                            activationCode!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                    if (storedSignature != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text('التوقيع المخزن:'),
                          SelectableText(
                            storedSignature!,
                            style: const TextStyle(
                              fontFamily: 'Monospace',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),

                    if (expectedSignature != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text('التوقيع المتوقع:'),
                          SelectableText(
                            expectedSignature!,
                            style: const TextStyle(
                              fontFamily: 'Monospace',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 40),

            // أزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // زر إعادة التفعيل
                ElevatedButton.icon(
                  onPressed: () async {
                    // حذف التوقيع القديم
                    await ActivationService().clearActivation();

                    // الانتقال لصفحة التفعيل مع إرسال الكود القديم
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const ActivationPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('مسح التوقيع وإعادة التفعيل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // زر الخروج
                ElevatedButton.icon(
                  onPressed: () {
                    if (Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS) {
                      windowManager.close();
                    } else {
                      exit(0);
                    }
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('خروج'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // تعليمات مساعدة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text(
                    '💡 تعليمات:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. اضغط على "مسح التوقيع" لإعادة التفعيل من البداية\n'
                    '2. ستحتاج إلى كود تفعيل جديد من المسؤول\n'
                    '3. تأكد من اتصالك بالإنترنت أثناء التفعيل',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
