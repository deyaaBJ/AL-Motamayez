import 'package:flutter/material.dart';
import 'package:shopmate/models/customer.dart';

class CustomerFormDialog extends StatefulWidget {
  final Customer? customer;
  final Function(Customer) onSave;

  const CustomerFormDialog({super.key, this.customer, required this.onSave});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // إذا كان تعديل، املأ البيانات الحالية
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phone!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // واجهة عربية كاملة
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, // النص يبدأ من اليمين
            children: [
              // العنوان
              _buildHeader(),

              const SizedBox(height: 20),

              // النموذج
              _buildForm(),

              const SizedBox(height: 24),

              // الأزرار
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5FF),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.customer == null ? Icons.person_add : Icons.edit,
            color: const Color(0xFF6A3093),
          ),
        ),

        const SizedBox(width: 12),

        Text(
          widget.customer == null ? 'إضافة عميل جديد' : 'تعديل العميل',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6A3093),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // حقل الاسم
          TextFormField(
            controller: _nameController,
            textDirection: TextDirection.rtl, // يدعم العربي بشكل طبيعي
            textAlign: TextAlign.right, // محاذاة لليمين
            decoration: InputDecoration(
              labelText: 'اسم العميل',
              prefixIcon: const Icon(Icons.person, color: Color(0xFF8B5FBF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE1D4F7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5FBF),
                  width: 2,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال اسم العميل';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // حقل رقم الهاتف
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr, // الأرقام محاذاة لليسار
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: const Icon(Icons.phone, color: Color(0xFF8B5FBF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE1D4F7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5FBF),
                  width: 2,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال رقم الهاتف';
              }
              if (value.length < 8) {
                return 'رقم الهاتف يجب أن يكون صحيحاً';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // زر الإلغاء
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6A3093),
              side: const BorderSide(color: Color(0xFF6A3093)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('إلغاء'),
          ),
        ),

        const SizedBox(width: 12),

        // زر الحفظ
        Expanded(
          child: ElevatedButton(
            onPressed: _saveCustomer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A3093),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(widget.customer == null ? 'إضافة' : 'تحديث'),
          ),
        ),
      ],
    );
  }

  void _saveCustomer() {
    if (_formKey.currentState!.validate()) {
      final customer = Customer(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      widget.onSave(customer);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
