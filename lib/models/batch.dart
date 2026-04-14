// lib/models/batch.dart

class Batch {
  int? id;
  int productId;
  int? purchaseItemId;
  double quantity;
  double remainingQuantity;
  double costPrice;
  String? productionDate;
  String expiryDate;
  bool active;
  String createdAt;
  String? productName;
  String? productBarcode;
  String? supplierName; // اسم المورد
  int? purchaseInvoiceId; // رقم فاتورة الشراء

  Batch({
    this.id,
    required this.productId,
    this.purchaseItemId,
    required this.quantity,
    required this.remainingQuantity,
    required this.costPrice,
    this.productionDate,
    required this.expiryDate,
    this.active = false,
    required this.createdAt,
    this.productName,
    this.productBarcode,
    this.supplierName,
    this.purchaseInvoiceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'purchase_item_id': purchaseItemId,
      'quantity': quantity,
      'remaining_quantity': remainingQuantity,
      'cost_price': costPrice,
      'production_date': productionDate,
      'expiry_date': expiryDate,
      'active': active ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory Batch.fromMap(
    Map<String, dynamic> map, {
    String? productName,
    String? productBarcode,
    String? supplierName,
    int? purchaseInvoiceId,
  }) {
    return Batch(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      purchaseItemId: map['purchase_item_id'] as int?,
      quantity: (map['quantity'] as num).toDouble(),
      remainingQuantity: (map['remaining_quantity'] as num).toDouble(),
      costPrice: (map['cost_price'] as num).toDouble(),
      productionDate: map['production_date'] as String?,
      expiryDate: map['expiry_date'] as String,
      active: (map['active'] as int?) == 1,
      createdAt: map['created_at'] as String,
      productName: productName,
      productBarcode: productBarcode,
      supplierName: supplierName,
      purchaseInvoiceId: purchaseInvoiceId,
    );
  }

  // نسخة من الدفعة مع تحديث الكمية
  Batch copyWith({
    int? id,
    int? productId,
    int? purchaseItemId,
    double? quantity,
    double? remainingQuantity,
    double? costPrice,
    String? productionDate,
    String? expiryDate,
    bool? active,
    String? createdAt,
    String? productName,
    String? productBarcode,
    String? supplierName,
    int? purchaseInvoiceId,
  }) {
    return Batch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      purchaseItemId: purchaseItemId ?? this.purchaseItemId,
      quantity: quantity ?? this.quantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      costPrice: costPrice ?? this.costPrice,
      productionDate: productionDate ?? this.productionDate,
      expiryDate: expiryDate ?? this.expiryDate,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      supplierName: supplierName ?? this.supplierName,
      purchaseInvoiceId: purchaseInvoiceId ?? this.purchaseInvoiceId,
    );
  }

  // تحويل الدفعة إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'purchase_item_id': purchaseItemId,
      'quantity': quantity,
      'remaining_quantity': remainingQuantity,
      'cost_price': costPrice,
      'production_date': productionDate,
      'expiry_date': expiryDate,
      'active': active,
      'created_at': createdAt,
      'product_name': productName,
      'product_barcode': productBarcode,
      'supplier_name': supplierName,
      'purchase_invoice_id': purchaseInvoiceId,
    };
  }

  int get daysRemaining {
    if (expiryDate == '2099-12-31' || expiryDate.isEmpty) {
      return 9999; // منتج بدون صلاحية
    }
    final now = DateTime.now();
    final expiry = DateTime.parse(expiryDate);
    final difference = expiry.difference(now);
    return difference.inDays;
  }

  /// حساب الأيام المتبقية بشكل دقيق (مع الكسور العشرية)
  double get preciseRemainingDays {
    if (expiryDate == '2099-12-31' || expiryDate.isEmpty) {
      return 9999; // منتج بدون صلاحية
    }
    final now = DateTime.now();
    final expiry = DateTime.parse(expiryDate);
    final difference = expiry.difference(now);
    return difference.inHours / 24.0;
  }

  String get status {
    if (expiryDate == '2099-12-31' || expiryDate.isEmpty) {
      return 'بدون صلاحية';
    }
    if (daysRemaining < 0) {
      return 'منتهية';
    } else if (daysRemaining <= 30) {
      return 'قريبة';
    } else {
      return 'نشطة';
    }
  }

  // ✅ لون الحالة
  String get statusColor {
    if (expiryDate == '2099-12-31' || expiryDate.isEmpty) {
      return 'grey'; // رمادي للمنتجات بدون صلاحية
    }
    if (daysRemaining < 0) {
      return 'red';
    } else if (daysRemaining <= 30) {
      return 'yellow';
    } else {
      return 'green';
    }
  }

  // ✅ دالة لمعرفة إذا كان المنتج له صلاحية
  bool get hasExpiry {
    return expiryDate != '2099-12-31' && expiryDate.isNotEmpty;
  }

  @override
  String toString() {
    return 'Batch(id: $id, product: $productName, quantity: $remainingQuantity/$quantity, supplier: $supplierName, expiry: $expiryDate)';
  }
}
