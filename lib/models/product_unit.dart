class ProductUnit {
  int? id;
  int productId;
  String unitName;
  String? barcode;
  double containQty;
  int multiplierNumerator;
  int multiplierDenominator;
  double sellPrice;
  double? offerPrice;
  String? offerStartDate;
  String? offerEndDate;
  bool offerEnabled;

  ProductUnit({
    this.id,
    required this.productId,
    required this.unitName,
    this.barcode,
    required this.containQty,
    int? multiplierNumerator,
    int? multiplierDenominator,
    required this.sellPrice,
    this.offerPrice,
    this.offerStartDate,
    this.offerEndDate,
    this.offerEnabled = false,
  }) : multiplierNumerator =
           multiplierNumerator ?? _deriveFraction(containQty).$1,
       multiplierDenominator =
           multiplierDenominator ?? _deriveFraction(containQty).$2;

  double get multiplier => containQty;

  String get multiplierLabel {
    if (multiplierDenominator == 1) {
      return multiplierNumerator.toString();
    }
    return '$multiplierNumerator/$multiplierDenominator';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'unit_name': unitName,
      'barcode': barcode,
      'contain_qty': containQty,
      'multiplier_numerator': multiplierNumerator,
      'multiplier_denominator': multiplierDenominator,
      'sell_price': sellPrice,
      'offer_price': offerPrice,
      'offer_start_date': offerStartDate,
      'offer_end_date': offerEndDate,
      'offer_enabled': offerEnabled ? 1 : 0,
    };
  }

  factory ProductUnit.fromMap(Map<String, dynamic> map) {
    final containQty = map['contain_qty']?.toDouble() ?? 0.0;
    final int? numerator = (map['multiplier_numerator'] as num?)?.toInt();
    final int? denominator = (map['multiplier_denominator'] as num?)?.toInt();
    final derivedFraction = _deriveFraction(containQty);

    return ProductUnit(
      id: map['id'],
      productId: map['product_id'],
      unitName: map['unit_name'],
      barcode: map['barcode'],
      containQty: containQty,
      multiplierNumerator: numerator ?? derivedFraction.$1,
      multiplierDenominator: denominator ?? derivedFraction.$2,
      sellPrice: map['sell_price']?.toDouble() ?? 0.0,
      offerPrice: map['offer_price']?.toDouble(),
      offerStartDate: map['offer_start_date'],
      offerEndDate: map['offer_end_date'],
      offerEnabled: map['offer_enabled'] == 1,
    );
  }

  bool get hasValidOffer {
    if (!offerEnabled || offerPrice == null || offerPrice! <= 0) {
      return false;
    }

    final start = _parseDateOnly(offerStartDate);
    final end = _parseDateOnly(offerEndDate);
    if (start == null || end == null) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }

  double get effectivePrice => hasValidOffer ? offerPrice! : sellPrice;

  static DateTime? _parseDateOnly(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }

    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static ProductUnit buildWithMultiplier({
    int? id,
    required int productId,
    required String unitName,
    String? barcode,
    required int multiplierNumerator,
    required int multiplierDenominator,
    required double sellPrice,
    double? offerPrice,
    String? offerStartDate,
    String? offerEndDate,
    bool offerEnabled = false,
  }) {
    final safeDenominator = multiplierDenominator == 0
        ? 1
        : multiplierDenominator;
    final containQty = multiplierNumerator / safeDenominator;

    return ProductUnit(
      id: id,
      productId: productId,
      unitName: unitName,
      barcode: barcode,
      containQty: containQty,
      multiplierNumerator: multiplierNumerator,
      multiplierDenominator: safeDenominator,
      sellPrice: sellPrice,
      offerPrice: offerPrice,
      offerStartDate: offerStartDate,
      offerEndDate: offerEndDate,
      offerEnabled: offerEnabled,
    );
  }

  static ({int numerator, int denominator}) parseMultiplierInput(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Multiplier is empty');
    }

    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length != 2) {
        throw const FormatException('Invalid fraction format');
      }

      final numerator = int.tryParse(parts[0].trim());
      final denominator = int.tryParse(parts[1].trim());
      if (numerator == null || denominator == null || denominator <= 0) {
        throw const FormatException('Invalid fraction values');
      }

      final reduced = _reduceFraction(numerator, denominator);
      return (
        numerator: reduced.$1,
        denominator: reduced.$2,
      );
    }

    final decimal = double.tryParse(trimmed);
    if (decimal == null || decimal <= 0) {
      throw const FormatException('Invalid decimal value');
    }

    final derived = _deriveFraction(decimal);
    return (numerator: derived.$1, denominator: derived.$2);
  }

  bool get isBaseUnitMultiplier =>
      multiplierNumerator == multiplierDenominator;

  bool get isSubUnitMultiplier =>
      multiplierNumerator < multiplierDenominator;

  static (int, int) _deriveFraction(double value) {
    if (value <= 0) {
      return (0, 1);
    }

    final asString = value.toString();
    if (!asString.contains('.')) {
      return (value.round(), 1);
    }

    final decimals = asString.split('.').last.length;
    final denominator = _pow10(decimals);
    final numerator = (value * denominator).round();
    return _reduceFraction(numerator, denominator);
  }

  static (int, int) _reduceFraction(int numerator, int denominator) {
    final divisor = _gcd(numerator.abs(), denominator.abs());
    if (divisor == 0) {
      return (numerator, denominator == 0 ? 1 : denominator);
    }
    return (numerator ~/ divisor, denominator ~/ divisor);
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }

  static int _pow10(int exponent) {
    var value = 1;
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
    return value;
  }
}
