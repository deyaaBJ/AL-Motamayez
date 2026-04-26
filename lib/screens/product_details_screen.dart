import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/screens/add_product/add_product_screen.dart';
import 'package:motamayez/utils/formatters.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ProductProvider _provider = ProductProvider();
  Product? _product;
  Map<String, dynamic>? _costSummary;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);

    try {
      final product = await _provider.getProductById(widget.productId);
      final costSummary = await _provider.getProductCostSummary(
        widget.productId,
      );

      setState(() {
        _product = product;
        _costSummary = costSummary;
        _isLoading = false;
      });
    } catch (e) {
      log('Error loading product details: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getUnitText(String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
      case 'كيلو':
      case 'كيلوغرام':
        return 'كيلو';
      case 'piece':
      case 'قطعة':
      case 'pcs':
      case 'pc':
        return 'قطعة';
      case 'gram':
      case 'غرام':
      case 'g':
        return 'غرام';
      case 'liter':
      case 'لتر':
      case 'l':
        return 'لتر';
      case 'box':
      case 'صندوق':
      case 'علبة':
        return 'علبة';
      default:
        return unit;
    }
  }

  double get _averageCost {
    return (_costSummary?['average_cost'] as num?)?.toDouble() ??
        _product?.costPrice ??
        0.0;
  }

  double get _latestPurchaseCost {
    return (_costSummary?['latest_purchase_cost'] as num?)?.toDouble() ?? 0.0;
  }

  int get _openBatchesCount {
    return (_costSummary?['open_batches_count'] as num?)?.toInt() ?? 0;
  }

  String get _latestPurchaseDateText {
    final value = _costSummary?['latest_purchase_date'] as String?;
    if (value == null || value.trim().isEmpty) {
      return 'لا يوجد';
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'تفاصيل المنتج',
        title: 'تفاصيل المنتج',
        child:
            _isLoading
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.blue.shade700,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'جاري تحميل بيانات المنتج...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
                : _product == null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'المنتج غير موجود',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'قد يكون المنتج محذوفا أو غير متوفر',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
                : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade700,
                                      Colors.blue.shade800,
                                    ],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.shade300,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        // ignore: deprecated_member_use
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _product!.name,
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              // ignore: deprecated_member_use
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'كود: ${_product!.barcode ?? 'غير محدد'}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                // ignore: deprecated_member_use
                                                color: Colors.white.withOpacity(
                                                  0.95,
                                                ),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoBox(
                                      icon: Icons.scale,
                                      label: 'الوحدة',
                                      value: _getUnitText(_product!.baseUnit),
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInfoBox(
                                      icon:
                                          _product!.active
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                      label: 'الحالة',
                                      value:
                                          _product!.active ? 'نشط' : 'غير نشط',
                                      color:
                                          _product!.active
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                      backgroundColor:
                                          _product!.active
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoBox(
                                      icon:
                                          _product!.hasExpiryDate
                                              ? Icons.date_range
                                              : Icons.event_busy,
                                      label: 'الصلاحية',
                                      value:
                                          _product!.hasExpiryDate
                                              ? 'له صلاحية'
                                              : 'لا يوجد',
                                      color:
                                          _product!.hasExpiryDate
                                              ? Colors.orange.shade700
                                              : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInfoBox(
                                      icon: Icons.inventory,
                                      label: 'المخزون',
                                      value:
                                          '${Formatters.formatQuantity(_product!.quantity)} ${_getUnitText(_product!.baseUnit)}',
                                      color: Colors.blue.shade700,
                                      backgroundColor: Colors.blue.shade50,
                                      valueFontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      // ignore: deprecated_member_use
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.attach_money,
                                          color: Colors.green.shade700,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'الأسعار',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildPriceBox(
                                            label: 'متوسط التكلفة',
                                            value: _averageCost,
                                            color: Colors.orange.shade700,
                                            unit: _getUnitText(
                                              _product!.baseUnit,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildPriceBox(
                                            label: 'سعر البيع',
                                            value: _product!.price,
                                            color: Colors.green.shade700,
                                            unit: _getUnitText(
                                              _product!.baseUnit,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildPriceBox(
                                            label: 'آخر سعر شراء',
                                            value: _latestPurchaseCost,
                                            color: Colors.blueGrey.shade700,
                                            unit: _getUnitText(
                                              _product!.baseUnit,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildInfoBox(
                                            icon: Icons.layers_outlined,
                                            label: 'الواردات المتوفرة',
                                            value: _openBatchesCount.toString(),
                                            color: Colors.indigo.shade700,
                                            backgroundColor:
                                                Colors.indigo.shade50,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoBox(
                                      icon: Icons.event_note_outlined,
                                      label: 'تاريخ آخر شراء',
                                      value: _latestPurchaseDateText,
                                      color: Colors.teal.shade700,
                                      backgroundColor: Colors.teal.shade50,
                                      valueFontSize: 16,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.edit, size: 22),
                                label: const Text(
                                  'تعديل المنتج',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => AddProductScreen(
                                            productId: _product!.id,
                                          ),
                                    ),
                                  );

                                  if (result == true && mounted) {
                                    await _loadProduct();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(
                                  Icons.arrow_back,
                                  size: 22,
                                  color: Colors.grey.shade700,
                                ),
                                label: Text(
                                  'رجوع',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    Color? backgroundColor,
    double valueFontSize = 18,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              backgroundColor != null
                  // ignore: deprecated_member_use
                  ? color.withOpacity(0.3)
                  : Colors.grey.shade200,
        ),
        boxShadow:
            backgroundColor == null
                ? [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBox({
    required String label,
    required double value,
    required Color color,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        // ignore: deprecated_member_use
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              // ignore: deprecated_member_use
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'Cairo',
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'شيكل',
                  style: TextStyle(
                    fontSize: 14,
                    // ignore: deprecated_member_use
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'لل$unit',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
