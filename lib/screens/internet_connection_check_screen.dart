import 'dart:async';

import 'package:flutter/material.dart';

class InternetConnectionCheckScreen extends StatefulWidget {
  const InternetConnectionCheckScreen({
    super.key,
    required this.onRetry,
    this.bannerText,
  });

  final Future<bool> Function() onRetry;
  final String? bannerText;

  @override
  State<InternetConnectionCheckScreen> createState() =>
      _InternetConnectionCheckScreenState();
}

class _InternetConnectionCheckScreenState
    extends State<InternetConnectionCheckScreen> {
  Timer? _timer;
  bool _checking = false;
  String _message =
      'لا يوجد اتصال بالإنترنت حاليًا. جاري انتظار عودة الاتصال...';

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
        _message = 'تمت عودة الاتصال، جاري متابعة فحص التفعيل...';
      });
    }

    _checking = false;
  }

  Future<void> _retryNow() async {
    setState(() {
      _message = 'جاري التحقق من الاتصال...';
    });

    final online = await widget.onRetry();
    if (!mounted) return;

    setState(() {
      _message =
          online
              ? 'تمت عودة الاتصال، جاري متابعة فحص التفعيل...'
              : 'لا يوجد اتصال بالإنترنت حاليًا. جاري انتظار عودة الاتصال...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
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
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
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
          if (widget.bannerText != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: _NoInternetBanner(text: widget.bannerText!),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoInternetBanner extends StatelessWidget {
  const _NoInternetBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFFF7ED),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Color(0xFFC2410C)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
