import 'package:flutter/material.dart';
import 'package:motamayez/services/whatsapp_support_service.dart';

class WhatsAppSupportButton extends StatefulWidget {
  const WhatsAppSupportButton({super.key, required this.heroTag});

  final String heroTag;

  @override
  State<WhatsAppSupportButton> createState() => _WhatsAppSupportButtonState();
}

class _WhatsAppSupportButtonState extends State<WhatsAppSupportButton>
    with SingleTickerProviderStateMixin {
  final WhatsAppSupportService _supportService = const WhatsAppSupportService();
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final opened = await _supportService.openChat();
    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تعذر فتح واتساب حاليًا. يرجى المحاولة مرة أخرى.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(right: 12, bottom: 12),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapCancel: () => _controller.reverse(),
          onTapUp: (_) => _controller.reverse(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: const Color(0xFF25D366).withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: widget.heroTag,
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              highlightElevation: 0,
              tooltip: 'تواصل عبر واتساب',
              shape: const CircleBorder(),
              onPressed: _openWhatsApp,
              child: const Icon(Icons.message_rounded, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}
