// widgets/settings/settings_main_card.dart
import 'package:flutter/material.dart';

class SettingsMainCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const SettingsMainCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ الحصول على أبعاد الشاشة
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 400; // للشاشات الصغيرة جداً
    final isLarge = size.width > 800; // للشاشات الكبيرة

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          // ✅ ارتفاع مرن حسب حجم الشاشة
          height: isLarge ? 220 : (isSmall ? 160 : 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(isSmall ? 16 : 24),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: isSmall ? 12 : 20,
                offset: Offset(0, isSmall ? 6 : 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isSmall ? 16 : 24),
            child: Stack(
              children: [
                _buildDecorationCircles(isSmall),
                _buildContent(isSmall, isLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecorationCircles(bool isSmall) {
    return Stack(
      children: [
        Positioned(
          left: isSmall ? -20 : -30,
          top: isSmall ? -20 : -30,
          child: Container(
            width: isSmall ? 60 : 100,
            height: isSmall ? 60 : 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        Positioned(
          right: isSmall ? -10 : -20,
          bottom: isSmall ? -10 : -20,
          child: Container(
            width: isSmall ? 50 : 80,
            height: isSmall ? 50 : 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(bool isSmall, bool isLarge) {
    return Padding(
      padding: EdgeInsets.all(isSmall ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ توزيع متساوٍ
        children: [
          // ✅ الجزء العلوي: الأيقونة والعنوان
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(isSmall),
                SizedBox(height: isSmall ? 12 : 16),
                // ✅ عنوان قابل للتكيف (FittedBox لمنع Overflow)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: isLarge ? 28 : (isSmall ? 18 : 24),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isSmall ? 4 : 8),
                // ✅ subtitle قابل للتكيف
                Flexible(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // ✅ الجزء السفلي: زر الإجراء
          _buildActionButton(isSmall),
        ],
      ),
    );
  }

  Widget _buildIcon(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
      ),
      child: Icon(icon, color: Colors.white, size: isSmall ? 24 : 32),
    );
  }

  Widget _buildActionButton(bool isSmall) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 16,
          vertical: isSmall ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'إدارة',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isSmall ? 12 : 14,
              ),
            ),
            SizedBox(width: isSmall ? 2 : 4),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: isSmall ? 12 : 16,
            ),
          ],
        ),
      ),
    );
  }
}
