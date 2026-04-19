import 'package:flutter/material.dart';
import 'package:motamayez/widgets/main_screen/notification_card.dart';
import 'package:motamayez/models/batch.dart';

class NotificationsSection extends StatelessWidget {
  final int expiredBatches;
  final int expiringSoonBatches;
  final int nearExpiryDays;
  final void Function(String) onTapFilter;
  final bool expandToFill;
  final List<Batch> expiredBatchList;
  final List<Batch> expiringBatchList;

  const NotificationsSection({
    super.key,
    required this.expiredBatches,
    required this.expiringSoonBatches,
    required this.nearExpiryDays,
    required this.onTapFilter,
    this.expandToFill = false,
    this.expiredBatchList = const [],
    this.expiringBatchList = const [],
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final hasAlerts = expiredBatches > 0 || expiringSoonBatches > 0;

    Widget alertsList =
        hasAlerts
            ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (expiredBatches > 0)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NotificationCard(
                        title: "منتجات منتهية",
                        description: "$expiredBatches منتج منتهي الصلاحية",
                        icon: Icons.dangerous,
                        color: const Color(0xFFEF4444),
                        count: expiredBatches,
                        onTap: () => onTapFilter('expired'),
                      ),
                      if (expiredBatchList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: _buildBatchesList(
                            expiredBatchList,
                            const Color(0xFFEF4444),
                            context,
                          ),
                        ),
                    ],
                  ),
                if (expiredBatches > 0 && expiringSoonBatches > 0)
                  const SizedBox(height: 16),
                if (expiringSoonBatches > 0)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NotificationCard(
                        title: "قريبة من الانتهاء",
                        description:
                            "$expiringSoonBatches منتج خلال $nearExpiryDays يوم",
                        icon: Icons.timer,
                        color: const Color(0xFFF59E0B),
                        count: expiringSoonBatches,
                        onTap: () => onTapFilter('expiring_soon'),
                      ),
                      if (expiringBatchList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: _buildBatchesList(
                            expiringBatchList,
                            const Color(0xFFF59E0B),
                            context,
                          ),
                        ),
                    ],
                  ),
              ],
            )
            : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: const Color(0xFF10B981),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "لا توجد تنبيهات",
                    textScaler: textScaler,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  Text(
                    "جميع المنتجات سليمة",
                    textScaler: textScaler,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            );

    Widget content =
        expandToFill
            ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: alertsList,
                    ),
                  ),
                ],
              ),
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                alertsList,
              ],
            );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: const Color(0xFF7C3AED).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
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

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(Icons.notifications_active, color: Color(0xFF7C3AED), size: 24),
        SizedBox(width: 10),
        Text(
          "التنبيهات",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E1B4B),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchesList(
    List<Batch> batches,
    Color color,
    BuildContext context,
  ) {
    return Container(
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        // ignore: deprecated_member_use
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            batches
                .map((batch) => _buildBatchItem(batch, color, context))
                .toList(),
      ),
    );
  }

  Widget _buildBatchItem(Batch batch, Color color, BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  batch.productName ?? 'منتج',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: textScaler,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الكمية: ${batch.remainingQuantity.toStringAsFixed(0)}',
                  textScaler: textScaler,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${batch.daysRemaining} يوم',
              textScaler: textScaler,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
