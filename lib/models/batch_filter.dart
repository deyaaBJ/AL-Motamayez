class BatchFilter {
  final String? status;
  final String? expiryFilter;

  static const Object _keepValue = Object();

  BatchFilter({this.status, this.expiryFilter});

  BatchFilter copyWith({
    Object? status = _keepValue,
    Object? expiryFilter = _keepValue,
  }) {
    return BatchFilter(
      status: identical(status, _keepValue) ? this.status : status as String?,
      expiryFilter:
          identical(expiryFilter, _keepValue)
              ? this.expiryFilter
              : expiryFilter as String?,
    );
  }

  bool get hasActiveFilters => status != null || expiryFilter != null;

  int getActiveFiltersCount() {
    int count = 0;
    if (status != null) count++;
    if (expiryFilter != null) count++;
    return count;
  }

  /// بناء جملة WHERE (بدون pb.active = 1 لأنها تضاف في الاستعلام الرئيسي)
  String buildWhereClause(List<Object?> args) {
    final conditions = <String>[];

    // معالجة فلتر الحالة (status)
    if (status != null && status!.isNotEmpty) {
      if (status == 'منتهي') {
        conditions.add('''
          pb.expiry_date IS NOT NULL
          AND pb.expiry_date != ''
          AND pb.expiry_date != '2099-12-31'
          AND DATE(pb.expiry_date) < DATE('now')
        ''');
      } else if (status == 'قريب') {
        conditions.add('''
          pb.expiry_date IS NOT NULL
          AND pb.expiry_date != ''
          AND pb.expiry_date != '2099-12-31'
          AND DATE(pb.expiry_date) >= DATE('now')
          AND DATE(pb.expiry_date) <= DATE('now', '+30 days')
        ''');
      } else if (status == 'جيد') {
        conditions.add('''
          (
            pb.expiry_date IS NULL
            OR pb.expiry_date = ''
            OR pb.expiry_date = '2099-12-31'
            OR DATE(pb.expiry_date) > DATE('now', '+30 days')
          )
        ''');
      }
    }

    // معالجة فلتر الصلاحية التفصيلي (expiryFilter)
    if (expiryFilter != null && expiryFilter!.isNotEmpty) {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T').first;

      if (expiryFilter == 'أسبوع') {
        final weekFromNow = today.add(const Duration(days: 7));
        final weekFromNowStr = weekFromNow.toIso8601String().split('T').first;
        conditions.add('''
          pb.expiry_date IS NOT NULL
          AND pb.expiry_date != ''
          AND pb.expiry_date != '2099-12-31'
          AND DATE(pb.expiry_date) BETWEEN ? AND ?
        ''');
        args.addAll([todayStr, weekFromNowStr]);
      } else if (expiryFilter == 'شهر') {
        final monthFromNow = today.add(const Duration(days: 30));
        final monthFromNowStr = monthFromNow.toIso8601String().split('T').first;
        conditions.add('''
          pb.expiry_date IS NOT NULL
          AND pb.expiry_date != ''
          AND pb.expiry_date != '2099-12-31'
          AND DATE(pb.expiry_date) BETWEEN ? AND ?
        ''');
        args.addAll([todayStr, monthFromNowStr]);
      } else if (expiryFilter == 'منتهي') {
        conditions.add('''
          pb.expiry_date IS NOT NULL
          AND pb.expiry_date != ''
          AND pb.expiry_date != '2099-12-31'
          AND DATE(pb.expiry_date) < ?
        ''');
        args.add(todayStr);
      } else if (expiryFilter == 'مستقبل') {
        conditions.add('''
          pb.expiry_date IS NOT NULL
          AND pb.expiry_date != ''
          AND pb.expiry_date != '2099-12-31'
          AND DATE(pb.expiry_date) >= ?
        ''');
        args.add(todayStr);
      }
    }

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
