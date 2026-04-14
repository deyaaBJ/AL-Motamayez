String translateUnit(String unit) {
  switch (unit) {
    case 'piece':
      return 'قطعة';
    case 'kg':
      return 'كيلو';
    case 'g':
      return 'غرام';
    case 'liter':
      return 'لتر';
    case 'box':
      return 'علبة';
    default:
      return unit; // لو كانت وحدة غير معروفة
  }

  String mixedUnitDisplay(
    double totalQty,
    double containQty,
    String unitName,
    String baseUnit,
  ) {
    final String baseTranslated = translateUnit(baseUnit);
    String unitTranslated =
        unitName.trim().isEmpty ? 'الوحدة' : unitName.trim();

    if (containQty <= 1.0) {
      return '${totalQty.toStringAsFixed(0)} $baseTranslated';
    }

    int wholeUnits = (totalQty / containQty).floor().toInt();
    double remainder = totalQty - (wholeUnits * containQty);

    if (wholeUnits == 0) {
      return '${remainder.toStringAsFixed(0)} $baseTranslated';
    } else if (remainder < 0.5) {
      // Treat small remainder as zero
      return '$wholeUnits $unitTranslated';
    } else {
      return '$wholeUnits $unitTranslated و ${remainder.toStringAsFixed(0)} $baseTranslated';
    }
  }
}
