// lib/screens/product_details_screen.dart
import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/product.dart';
import 'package:motamayez/providers/product_provider.dart';
import 'package:motamayez/widgets/TextField.dart';

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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'تفاصيل المنتج',
        title: 'تفاصيل المنتج',
        child:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _product == null
                ? Center(child: Text('المنتج غير موجود'))
                : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      // بطاقة المعلومات الأساسية
                      Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المعلومات الأساسية',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6A3093),
                                ),
                              ),
                              SizedBox(height: 16),
                              _buildDetailItem('الاسم', _product!.name),
                              _buildDetailItem(
                                'الباركود',
                                _product!.barcode ?? 'غير محدد',
                              ),
                              _buildDetailItem(
                                'الوحدة الأساسية',
                                _product!.baseUnit,
                              ),
                              _buildDetailItem(
                                'الحالة',
                                _product!.active ? 'نشط' : 'غير نشط',
                              ),
                              _buildDetailItem(
                                'له صلاحية',
                                _product!.hasExpiryDate ? 'نعم' : 'لا',
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // بطاقة المخزون والأسعار
                      Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المخزون والأسعار',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6A3093),
                                ),
                              ),
                              SizedBox(height: 16),
                              _buildDetailItem(
                                'الكمية',
                                _product!.quantity.toStringAsFixed(2),
                              ),
                              _buildDetailItem(
                                'سعر البيع',
                                _product!.price.toStringAsFixed(2),
                              ),
                              _buildDetailItem(
                                'سعر الشراء',
                                _product!.costPrice.toStringAsFixed(2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // أزرار الإجراءات
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.edit),
                              label: Text('تعديل المنتج'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF6A3093),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {},
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.arrow_back),
                              label: Text('رجوع'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Color(0xFF6A3093)),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
