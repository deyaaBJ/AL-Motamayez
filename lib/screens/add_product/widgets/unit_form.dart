import 'package:flutter/material.dart';
import '../../../../widgets/text_field.dart';
import '../controllers/unit_controller.dart';
import 'unit_offer_section.dart';
import '../../../../../../../utils/unit_translator.dart';

class UnitForm extends StatefulWidget {
  final int index;
  final UnitController controller;
  final bool isExisting;
  final VoidCallback onRemove;
  final double totalQuantity;
  final String baseUnit;

  const UnitForm({
    super.key,
    required this.index,
    required this.controller,
    required this.isExisting,
    required this.onRemove,
    this.totalQuantity = 0,
    required this.baseUnit,
  });

  @override
  State<UnitForm> createState() => _UnitFormState();
}

class _UnitFormState extends State<UnitForm> {
  late final TextEditingController _containQtyController;

  @override
  void initState() {
    super.initState();
    _containQtyController = widget.controller.containQtyController;
    // إعادة بناء الـ widget عند تغيير النص في حقل معامل التحويل
    _containQtyController.addListener(_onContainQtyChanged);
  }

  @override
  void dispose() {
    _containQtyController.removeListener(_onContainQtyChanged);
    super.dispose();
  }

  void _onContainQtyChanged() {
    setState(() {}); // يُحدِّث قسم الحساب فقط
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'الوحدة ${widget.index + 1}${widget.isExisting ? ' (موجودة)' : ' (جديدة)'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A3093),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: widget.controller.unitNameController,
            label: 'اسم الوحدة (مثال: كرتونة، علبة، باكيت)',
            prefixIcon: Icons.category,
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'يرجى إدخال اسم الوحدة';
              return null;
            },
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: widget.controller.containQtyController,
            label: 'كم وحدة مرجعية تحتوي هذه الوحدة',
            prefixIcon: Icons.format_list_numbered,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'يرجى إدخال معامل التحويل';
              final factor = double.tryParse(value.trim());
              if (factor == null || factor <= 0)
                return 'أدخل رقمًا صحيحًا أو عشريًا أكبر من صفر';
              return null;
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'مثال: إذا كانت الوحدة المرجعية حبة: حبة = 1، باكيت = 6، كرتونة = 24',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: widget.controller.sellPriceController,
            label: 'سعر بيع هذه الوحدة',
            prefixIcon: Icons.attach_money,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'يرجى إدخال السعر';
              if (double.tryParse(value) == null) return 'يرجى إدخال سعر صحيح';
              return null;
            },
          ),
          const SizedBox(height: 12),
          UnitOfferSection(controller: widget.controller),
          const SizedBox(height: 12),
          CustomTextField(
            controller: widget.controller.barcodeController,
            label: 'باركود الوحدة (اختياري)',
            prefixIcon: Icons.qr_code,
          ),
          if (_containQtyController.text.isNotEmpty &&
              _containQtyController.text.trim() != '0')
            const SizedBox(height: 16),
          if (_containQtyController.text.isNotEmpty &&
              _containQtyController.text.trim() != '0')
            _buildQuantityCalculationSection(),
        ],
      ),
    );
  }

  Widget _buildQuantityCalculationSection() {
    final containQty =
        double.tryParse(_containQtyController.text.trim()) ?? 1.0;
    if (containQty <= 0) return const SizedBox.shrink();

    final String unitName =
        widget.controller.unitNameController.text.isEmpty
            ? 'الوحدة'
            : widget.controller.unitNameController.text;
    final String mixedQty = mixedUnitDisplay(
      widget.totalQuantity,
      containQty,
      unitName,
      widget.baseUnit,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: Colors.green[700], size: 18),
              const SizedBox(width: 8),
              Text(
                'الكمية المتوقعة من هذه الوحدة:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.totalQuantity.toStringAsFixed(2)} ÷ ${containQty.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.controller.unitNameController.text.isEmpty
                          ? "الوحدة"
                          : widget.controller.unitNameController.text,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    mixedQty,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
