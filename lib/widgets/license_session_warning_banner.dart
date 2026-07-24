import 'package:flutter/material.dart';
import 'package:motamayez/services/license_session_guard.dart';

class LicenseSessionWarningBanner extends StatefulWidget {
  const LicenseSessionWarningBanner({super.key});

  @override
  State<LicenseSessionWarningBanner> createState() =>
      _LicenseSessionWarningBannerState();
}

class _LicenseSessionWarningBannerState
    extends State<LicenseSessionWarningBanner> {
  Offset _dragOffset = Offset.zero;
  Size _bannerSize = const Size(380, 0);
  Size _viewportSize = Size.zero;

  void _clampOffset() {
    if (_viewportSize == Size.zero) return;

    final maxX = (_viewportSize.width - _bannerSize.width - 16).clamp(0.0, double.infinity);
    final maxY = (_viewportSize.height - _bannerSize.height - 16).clamp(0.0, double.infinity);

    _dragOffset = Offset(
      _dragOffset.dx.clamp(0.0, maxX),
      _dragOffset.dy.clamp(0.0, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LicenseSessionWarning?>(
      valueListenable: LicenseSessionGuard.instance.warning,
      builder: (context, warning, _) {
        final topPadding = MediaQuery.paddingOf(context).top + 12;

        return IgnorePointer(
          ignoring: warning == null,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child:
                warning == null
                    ? const SizedBox.shrink()
                    : LayoutBuilder(
                      key: const ValueKey('license-session-warning'),
                      builder: (context, constraints) {
                        _viewportSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );

                        _clampOffset();

                        return Stack(
                          children: [
                            Positioned(
                              left: 16 + _dragOffset.dx,
                              top: topPadding + _dragOffset.dy,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanUpdate: (details) {
                                  setState(() {
                                    _dragOffset += details.delta;
                                    _clampOffset();
                                  });
                                },
                                child: _WarningSurface(
                                  warning: warning,
                                  onSizeChanged: (size) {
                                    if (size == _bannerSize) return;
                                    setState(() {
                                      _bannerSize = size;
                                      _clampOffset();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
          ),
        );
      },
    );
  }
}

class _WarningSurface extends StatelessWidget {
  const _WarningSurface({required this.warning, required this.onSizeChanged});

  final LicenseSessionWarning warning;
  final ValueChanged<Size> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          elevation: 14,
          shadowColor: const Color(0x4DD97706),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFFFF7ED),
          child: SizeChangedLayoutNotifier(
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null && renderBox.hasSize) {
                    onSizeChanged(renderBox.size);
                  }
                });
                return true;
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFC2410C),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            warning.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9A3412),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            warning.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF7C2D12),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
