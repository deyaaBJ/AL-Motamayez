// widgets/main_screen/notifications_section.dart
import 'package:flutter/material.dart';
import 'package:motamayez/widgets/main_screen/notification_card.dart';

class NotificationsSection extends StatelessWidget {
  final int expiredBatches;
  final int expiringIn7DaysBatches;
  final void Function(String) onTapFilter;
  final bool expandToFill; // خاصية جديدة

  const NotificationsSection({
    super.key,
    required this.expiredBatches,
    required this.expiringIn7DaysBatches,
    required this.onTapFilter,
    this.expandToFill = false, // افتراضياً لا تتمدد
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: Color(0xFF7C3AED),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              "التنبيهات",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1B4B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        expiredBatches > 0 || expiringIn7DaysBatches > 0
            ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (expiredBatches > 0)
                  NotificationCard(
                    title: "منتجات منتهية",
                    description: "$expiredBatches منتج منتهي الصلاحية",
                    icon: Icons.dangerous,
                    color: const Color(0xFFEF4444),
                    count: expiredBatches,
                    onTap: () => onTapFilter('expired'),
                  ),
                if (expiredBatches > 0 && expiringIn7DaysBatches > 0)
                  const SizedBox(height: 8),
                if (expiringIn7DaysBatches > 0)
                  NotificationCard(
                    title: "قريبة من الانتهاء",
                    description: "$expiringIn7DaysBatches منتج",
                    icon: Icons.timer,
                    color: const Color(0xFFF59E0B),
                    count: expiringIn7DaysBatches,
                    onTap: () => onTapFilter('expiring_7_days'),
                  ),
              ],
            )
            : const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 40),
                  SizedBox(height: 8),
                  Text(
                    "لا توجد تنبيهات",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  Text(
                    "جميع المنتجات سليمة",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
      ],
    );

    // إذا أردنا التمدد لملء الارتفاع
    if (expandToFill) {
      content = SizedBox(
        width: double.infinity,
        height: double.infinity, // يملأ المساحة المتاحة
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الجزء العلوي ثابت (العنوان + أول محتوى)
            const Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Color(0xFF7C3AED),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  "التنبيهات",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // قائمة التنبيهات مع تمرير داخلي عند الحاجة
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child:
                    expiredBatches > 0 || expiringIn7DaysBatches > 0
                        ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (expiredBatches > 0)
                              NotificationCard(
                                title: "منتجات منتهية",
                                description:
                                    "$expiredBatches منتج منتهي الصلاحية",
                                icon: Icons.dangerous,
                                color: const Color(0xFFEF4444),
                                count: expiredBatches,
                                onTap: () => onTapFilter('expired'),
                              ),
                            if (expiredBatches > 0 &&
                                expiringIn7DaysBatches > 0)
                              const SizedBox(height: 8),
                            if (expiringIn7DaysBatches > 0)
                              NotificationCard(
                                title: "قريبة من الانتهاء",
                                description: "$expiringIn7DaysBatches منتج",
                                icon: Icons.timer,
                                color: const Color(0xFFF59E0B),
                                count: expiringIn7DaysBatches,
                                onTap: () => onTapFilter('expiring_7_days'),
                              ),
                          ],
                        )
                        : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Color(0xFF10B981),
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                "لا توجد تنبيهات",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E1B4B),
                                ),
                              ),
                              Text(
                                "جميع المنتجات سليمة",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: const Color(0xFF7C3AED).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          // ignore: deprecated_member_use
          color: const Color(0xFF7C3AED).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: content,
    );
  }
}
