// lib/screens/product_details_screen.dart
import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/providers/product_provider.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ProductProvider _provider = ProductProvider();
  Product? _product;
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
      setState(() {
        _product = product;
        _isLoading = false;
      });
    } catch (e) {
      log('Error loading product details: $e');
      setState(() => _isLoading = false);
    }
  }

  /// تحويل الوحدة إلى نص مناسب
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
                        'قد يكون المنتج محذوفاً أو غير متوفر',
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
                              // رأس الصفحة - اسم المنتج الرئيسي
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  'كود: ${_product!.barcode ?? 'غير محدد'}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white
                                                        .withOpacity(0.95),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // صف المعلومات الأساسية - عمودين
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

                              // صف الصلاحية والكمية
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
                                          '${_product!.quantity.toStringAsFixed(2)} ${_getUnitText(_product!.baseUnit)}',
                                      color: Colors.blue.shade700,
                                      backgroundColor: Colors.blue.shade50,
                                      valueFontSize: 20,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // بطاقة الأسعار
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
                                            label: 'سعر الشراء',
                                            value: _product!.costPrice,
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
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.purple.shade50,
                                            Colors.purple.shade100,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.purple.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.trending_up,
                                                color: Colors.purple.shade700,
                                                size: 28,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'الربح لل${_getUnitText(_product!.baseUnit)}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${(_product!.price - _product!.costPrice).toStringAsFixed(2)} شيكل',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple.shade800,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),

                      // أزرار الإجراءات السفلية
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
                                onPressed: () {
                                  // TODO: Navigate to edit screen
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

  /// بناء صندوق معلومات صغير
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
                  ? color.withOpacity(0.3)
                  : Colors.grey.shade200,
        ),
        boxShadow:
            backgroundColor == null
                ? [
                  BoxShadow(
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

  /// بناء صندوق السعر
  Widget _buildPriceBox({
    required String label,
    required double value,
    required Color color,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
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
