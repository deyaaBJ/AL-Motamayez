class Product {
  int? id;
  String name;
  String? barcode;
  String baseUnit;
  double price;
  double? offerPrice;
  String? offerStartDate;
  String? offerEndDate;
  bool offerEnabled;
  double quantity;
  double costPrice;
  String? addedDate;
  bool hasExpiryDate;
  bool hasOfferInUnits;
  bool active;
  int? lowStockThreshold;

  Product({
    this.id,
    required this.name,
    this.barcode,
    required this.baseUnit,
    required this.price,
    this.offerPrice,
    this.offerStartDate,
    this.offerEndDate,
    this.offerEnabled = false,
    required this.quantity,
    required this.costPrice,
    this.addedDate,
    this.hasExpiryDate = false,
    this.hasOfferInUnits = false,
    this.active = true,
    this.lowStockThreshold,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode ?? '',
      'base_unit': baseUnit,
      'price': price,
      'offer_price': offerPrice,
      'offer_start_date': offerStartDate,
      'offer_end_date': offerEndDate,
      'offer_enabled': offerEnabled ? 1 : 0,
      'quantity': quantity,
      'cost_price': costPrice,
      'added_date': addedDate,
      'has_expiry_date': hasExpiryDate ? 1 : 0,
      'has_offer_in_units': hasOfferInUnits ? 1 : 0,
      'active': active ? 1 : 0,
      'low_stock_threshold': lowStockThreshold,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      baseUnit: map['base_unit'] ?? 'piece',
      price: map['price']?.toDouble() ?? 0.0,
      offerPrice: map['offer_price']?.toDouble(),
      offerStartDate: map['offer_start_date'],
      offerEndDate: map['offer_end_date'],
      offerEnabled: map['offer_enabled'] == 1,
      quantity: map['quantity']?.toDouble() ?? 0.0,
      costPrice: map['cost_price']?.toDouble() ?? 0.0,
      addedDate: map['added_date'],
      hasExpiryDate: map['has_expiry_date'] == 1,
      hasOfferInUnits: map['has_offer_in_units'] == 1,
      active: map['active'] == 1,
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toInt(),
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

  double get effectivePrice => hasValidOffer ? offerPrice! : price;

  int resolveLowStockThreshold(int defaultThreshold) {
    return lowStockThreshold ?? defaultThreshold;
  }

  bool isLowStock(int defaultThreshold) {
    if (quantity <= 0) return false;
    return quantity <= resolveLowStockThreshold(defaultThreshold);
  }

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
