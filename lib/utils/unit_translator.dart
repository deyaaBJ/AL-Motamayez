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
}
