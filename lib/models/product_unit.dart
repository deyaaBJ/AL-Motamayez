class ProductUnit {
  int? id;
  int productId;
  String unitName;
  String? barcode;
  double containQty;
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
    required this.sellPrice,
    this.offerPrice,
    this.offerStartDate,
    this.offerEndDate,
    this.offerEnabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'unit_name': unitName,
      'barcode': barcode,
      'contain_qty': containQty,
      'sell_price': sellPrice,
      'offer_price': offerPrice,
      'offer_start_date': offerStartDate,
      'offer_end_date': offerEndDate,
      'offer_enabled': offerEnabled ? 1 : 0,
    };
  }

  factory ProductUnit.fromMap(Map<String, dynamic> map) {
    return ProductUnit(
      id: map['id'],
      productId: map['product_id'],
      unitName: map['unit_name'],
      barcode: map['barcode'],
      containQty: map['contain_qty']?.toDouble() ?? 0.0,
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
}
