// lib/models/batch.dart
import 'dart:math';

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
  String? productName; // للعرض فقط، ليس مخزنا في DB
  String? productBarcode; // للعرض فقط

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
  });

  // حساب الأيام المتبقية
  int get daysRemaining {
    final now = DateTime.now();
    final expiry = DateTime.parse(expiryDate);
    final difference = expiry.difference(now);
    return difference.inDays;
  }

  // تحديد حالة الدفعة
  String get status {
    if (daysRemaining < 0) {
      return 'منتهية';
    } else if (daysRemaining <= 30) {
      return 'قريبة';
    } else {
      return 'نشطة';
    }
  }

  // لون الحالة
  String get statusColor {
    if (daysRemaining < 0) {
      return 'red';
    } else if (daysRemaining <= 30) {
      return 'yellow';
    } else {
      return 'green';
    }
  }

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
    );
  }
}
