import 'dart:async';

import 'package:flutter/material.dart';

class InternetConnectionCheckScreen extends StatefulWidget {
  const InternetConnectionCheckScreen({
    super.key,
    required this.onRetry,
  });

  final Future<bool> Function() onRetry;

  @override
  State<InternetConnectionCheckScreen> createState() =>
      _InternetConnectionCheckScreenState();
}

class _InternetConnectionCheckScreenState
    extends State<InternetConnectionCheckScreen> {
  Timer? _timer;
  bool _checking = false;
  String _message = 'لا يوجد اتصال بالإنترنت حالياً. جارٍ انتظار عودة الاتصال...';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      _retrySilently();
    });
    _retrySilently();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _retrySilently() async {
    if (_checking) return;
    _checking = true;
    final online = await widget.onRetry();
    if (!mounted) return;

    if (online) {
      setState(() {
        _message = 'تمت عودة الاتصال، جارٍ متابعة فحص التفعيل...';
      });
    }

    _checking = false;
  }

  Future<void> _retryNow() async {
    setState(() {
      _message = 'جارٍ التحقق من الاتصال...';
    });

    final online = await widget.onRetry();
    if (!mounted) return;

    setState(() {
      _message =
          online
              ? 'تمت عودة الاتصال، جارٍ متابعة فحص التفعيل...'
              : 'لا يوجد اتصال بالإنترنت حالياً. جارٍ انتظار عودة الاتصال...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 84,
                  color: Colors.orange,
                ),
                const SizedBox(height: 20),
                const Text(
                  'فحص الاتصال بالإنترنت',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, height: 1.6),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _retryNow,
                    icon:
                        _checking
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
