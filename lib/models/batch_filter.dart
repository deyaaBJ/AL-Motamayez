// lib/models/batch_filter.dart
class BatchFilter {
  final String? status;
  final String? expiryFilter;

  BatchFilter({this.status, this.expiryFilter});

  BatchFilter copyWith({String? status, String? expiryFilter}) {
    return BatchFilter(
      status: status ?? this.status,
      expiryFilter: expiryFilter ?? this.expiryFilter,
    );
  }

  bool get hasActiveFilters {
    return status != null || expiryFilter != null;
  }

  int getActiveFiltersCount() {
    int count = 0;
    if (status != null) count++;
    if (expiryFilter != null) count++;
    return count;
  }

  // دالة لبناء جملة WHERE بناءً على الفلاتر
  String buildWhereClause(List<Object?> args) {
    final conditions = <String>[];

    // الدفعات تكون دائماً active
    conditions.add('pb.active = 1');

    if (status != null && status!.isNotEmpty) {
      final today = DateTime.now();

      if (status == 'منتهي') {
        conditions.add('pb.days_remaining < 0');
      } else if (status == 'قريب') {
        conditions.add('pb.days_remaining <= 30 AND pb.days_remaining > 0');
      } else if (status == 'جيد') {
        conditions.add('pb.days_remaining > 30');
      }
    }

    if (expiryFilter != null && expiryFilter!.isNotEmpty) {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];

      if (expiryFilter == 'أسبوع') {
        final weekFromNow = today.add(Duration(days: 7));
        final weekFromNowStr = weekFromNow.toIso8601String().split('T')[0];
        conditions.add('pb.expiry_date BETWEEN ? AND ?');
        args.addAll([todayStr, weekFromNowStr]);
      } else if (expiryFilter == 'شهر') {
        final monthFromNow = today.add(Duration(days: 30));
        final monthFromNowStr = monthFromNow.toIso8601String().split('T')[0];
        conditions.add('pb.expiry_date BETWEEN ? AND ?');
        args.addAll([todayStr, monthFromNowStr]);
      } else if (expiryFilter == 'منتهي') {
        conditions.add('pb.expiry_date < ?');
        args.add(todayStr);
      } else if (expiryFilter == 'مستقبل') {
        conditions.add('pb.expiry_date >= ?');
        args.add(todayStr);
      }
    }

    if (conditions.isEmpty) return '';

    return conditions.join(' AND ');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BatchFilter &&
        other.status == status &&
        other.expiryFilter == expiryFilter;
  }

  @override
  int get hashCode => status.hashCode ^ expiryFilter.hashCode;
}
