// lib/widgets/thermal_receipt_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/models/cart_item.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'dart:developer';

class ThermalReceiptWidget extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;
  final double finalAmount;
  final bool isTotalModified;
  final DateTime dateTime;
  final int? receiptNumber;
  final String? paperSize;
  final Function() onCompleteSale;
  final Function() onCancel;

  const ThermalReceiptWidget({
    super.key,
    required this.cartItems,
    required this.totalAmount,
    required this.finalAmount,
    required this.isTotalModified,
    required this.dateTime,
    this.receiptNumber,
    this.paperSize = '58mm',
    required this.onCompleteSale,
    required this.onCancel,
  });

  @override
  State<ThermalReceiptWidget> createState() => _ThermalReceiptWidgetState();
}

class _ThermalReceiptWidgetState extends State<ThermalReceiptWidget> {
  String? _adminEmail;

  @override
  void initState() {
    super.initState();
    _loadAdminEmail();
  }

  Future<void> _loadAdminEmail() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final admins = await authProvider.getUsersByRole('admin');
      if (admins.isNotEmpty) {
        setState(() {
          _adminEmail = admins[0]['email'];
        });
      }
    } catch (e) {
      log('Error loading admin email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final paperWidth = widget.paperSize == '58mm' ? 240.0 : 360.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A3093),
        title: const Text(
          'معاينة الإيصال',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: widget.onCancel,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              // تنبيه المعاينة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: const Color(0xFFE3F2FD),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'معاينة للإيصال قبل الطباعة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // الإيصال الرئيسي
              Container(
                width: paperWidth,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF6A3093), width: 1),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildReceiptContent(context),
              ),

              const SizedBox(height: 16),

              // ملخص الفاتورة
              Container(
                width: paperWidth,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE1D4F7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ملخص الفاتورة:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A3093),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'عدد العناصر:',
                          style: TextStyle(fontSize: 11),
                        ),
                        Text(
                          '${widget.cartItems.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المجموع الفرعي:',
                          style: TextStyle(fontSize: 11),
                        ),
                        Text(
                          '${settings.currencyName} ${widget.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    if (widget.isTotalModified)
                      Column(
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'التعديل:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                ),
                              ),
                              Text(
                                '${settings.currencyName} ${(widget.finalAmount - widget.totalAmount).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const Divider(height: 8, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المجموع النهائي:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${settings.currencyName} ${widget.finalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // أزرار الإجراءات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: paperWidth,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onCompleteSale();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text(
                          'تأكيد البيع والطباعة',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: paperWidth,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          widget.onCancel();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text(
                          'العودة للبيع',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6A3093),
                          side: const BorderSide(color: Color(0xFF6A3093)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptContent(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final marketName = settings.marketName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // رأس الفاتورة
        Container(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            children: [
              // شعار النظام
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart,
                    color: const Color(0xFF6A3093),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'المتميز',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A3093),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'نظام إدارة المبيعات',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ),

        // خط فاصل
        _buildDivider(),

        // معلومات المتجر
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                marketName!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (_adminEmail != null) ...[
                const SizedBox(height: 2),
                Text(
                  '📧 $_adminEmail',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),

        // خط فاصل
        _buildDivider(),

        // معلومات الفاتورة
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('التاريخ:', style: _receiptLabelStyle()),
                  Text(
                    '${widget.dateTime.year}/${widget.dateTime.month.toString().padLeft(2, '0')}/${widget.dateTime.day.toString().padLeft(2, '0')}',
                    style: _receiptValueStyle(),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الوقت:', style: _receiptLabelStyle()),
                  Text(
                    '${widget.dateTime.hour.toString().padLeft(2, '0')}:${widget.dateTime.minute.toString().padLeft(2, '0')}',
                    style: _receiptValueStyle(),
                  ),
                ],
              ),
              if (widget.receiptNumber != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('رقم الفاتورة:', style: _receiptLabelStyle()),
                    Text(
                      '#${widget.receiptNumber!.toString().padLeft(5, '0')}',
                      style: _receiptValueStyle().copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // خط فاصل
        _buildDivider(),

        // عناصر الفاتورة
        Container(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            children: [
              // رأس الجدول
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5FF),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'الصنف',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'الكمية',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'الصنف',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'المجموع',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 2),

              // قائمة العناصر (مع عمود للوحدة وتحويل محدد للوحدات)
              ...widget.cartItems.map((item) {
                final productName = item.product.name;
                final unitName = item.unitName;
                final quantity = item.quantity;
                final price = item.unitPrice;
                final total = item.totalPrice;

                final bool isModifiedPrice = item.customPrice != null;

                // دالة لتحويل وحدات محددة إلى العربية فقط
                String translateUnit(String unit) {
                  final unitLower = unit.toLowerCase();

                  // تحويل piece إلى قطعة
                  if (unitLower.contains('piece')) {
                    return 'قطعة';
                  }

                  // تحويل kg إلى كيلو
                  if (unitLower.contains('kg')) {
                    return 'كيلو';
                  }

                  // الباقي يبقى كما هو
                  return unit;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عمود اسم المنتج
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName.length > 18
                                  ? '${productName.substring(0, 15)}...'
                                  : productName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color:
                                    isModifiedPrice
                                        ? Colors.orange
                                        : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isModifiedPrice)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8E1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text(
                                    'سعر معدل',
                                    style: TextStyle(
                                      fontSize: 7,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // عمود الكمية
                      Expanded(
                        flex: 1,
                        child: Text(
                          quantity.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // عمود الوحدة
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            translateUnit(unitName),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // عمود المجموع
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              total.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color:
                                    isModifiedPrice
                                        ? Colors.orange
                                        : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        // خط فاصل
        _buildDivider(),

        // المجموع الكلي
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              if (widget.isTotalModified)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المجموع:', style: _receiptLabelStyle()),
                        Text(
                          '${settings.currencyName} ${widget.totalAmount.toStringAsFixed(2)}',
                          style: _receiptValueStyle(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'التعديل:',
                          style: _receiptLabelStyle().copyWith(
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          '${settings.currencyName} ${(widget.finalAmount - widget.totalAmount).toStringAsFixed(2)}',
                          style: _receiptValueStyle().copyWith(
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: const Color(0xFF4CAF50),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المجموع النهائي:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${settings.currencyName} ${widget.finalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // خط فاصل
        _buildDivider(),

        // تذييل الفاتورة
        Container(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            children: [
              Text(
                'شكراً لتسوقكم معنا',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'نتمنى لكم يوماً سعيداً',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.receipt, size: 10, color: Colors.grey),
                  SizedBox(width: 2),
                  Text(
                    'motamayez',
                    style: TextStyle(fontSize: 8, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: const Divider(color: Colors.grey, height: 1, thickness: 0.5),
    );
  }

  TextStyle _receiptLabelStyle() {
    return const TextStyle(
      fontSize: 10,
      color: Colors.black87,
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle _receiptValueStyle() {
    return const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
  }
}
