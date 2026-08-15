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
  static const double _horizontalMargin = 24;
  static const double _verticalMargin = 20;
  static const double _bannerWidth = 380;
  static const double _bannerHeight = 90;

  Offset _clampDragOffset(Size screenSize, Offset proposedOffset) {
    final minDx = _horizontalMargin - 16;
    final maxDx = (screenSize.width - _bannerWidth - _horizontalMargin - 16)
        .clamp(minDx, double.infinity)
        .toDouble();

    return Offset(
      proposedOffset.dx.clamp(minDx, maxDx),
      0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LicenseSessionWarning?>(
      valueListenable: LicenseSessionGuard.instance.warning,
      builder: (context, warning, _) {
        final visibleWarning = warning;
        if (visibleWarning == null) return const SizedBox.shrink();

        return IgnorePointer(
          ignoring: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
              final safeOffset = _clampDragOffset(screenSize, _dragOffset);

              return SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16 + safeOffset.dx,
                      top: 12 + safeOffset.dy,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        setState(() {
                          _dragOffset = _clampDragOffset(
                            screenSize,
                            _dragOffset + details.delta,
                          );
                        });
                      },
                      child: _WarningSurface(warning: visibleWarning),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _WarningSurface extends StatelessWidget {
  const _WarningSurface({required this.warning});

  final LicenseSessionWarning warning;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 380),
        child: Material(
          elevation: 14,
          shadowColor: const Color(0x4DD97706),
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFFFF7ED),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    );
  }
}
