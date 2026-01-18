import 'dart:async';
import 'package:flutter/material.dart';
import 'package:motamayez/models/customer.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/customer_provider.dart';
import 'package:motamayez/helpers/helpers.dart';

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
  Timer? _nameCheckTimer;
  bool _isCheckingName = false;
  String? _nameError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // إذا كان تعديل، املأ البيانات الحالية
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameCheckTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // دالة التحقق من توفر الاسم
  Future<void> _checkNameAvailability() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _nameError = null);
      return;
    }

    // إلغاء المؤقت السابق إذا كان موجوداً
    _nameCheckTimer?.cancel();

    // إضافة تأخير 500ms لمنع التحقق المتكرر السريع
    _nameCheckTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      setState(() => _isCheckingName = true);

      try {
        final provider = Provider.of<CustomerProvider>(context, listen: false);
        final nameExists = await provider.isCustomerNameExists(
          name,
          excludeId: widget.customer?.id,
        );

        if (mounted) {
          setState(() {
            _isCheckingName = false;
            _nameError = nameExists ? 'هذا الاسم مستخدم بالفعل' : null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCheckingName = false;
            _nameError = null;
          });
        }
      }
    });
  }

  void _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      // التحقق النهائي من الاسم
      final name = _nameController.text.trim();
      if (_nameError != null || _isCheckingName) {
        showAppToast(
          context,
          'الرجاء انتظار التحقق من الاسم',
          ToastType.warning,
        );
        return;
      }

      setState(() => _isSaving = true);

      try {
        final customer = Customer(
          id: widget.customer?.id,
          name: name,
          phone:
              _phoneController.text.trim().isNotEmpty
                  ? _phoneController.text.trim()
                  : null,
        );

        await widget.onSave(customer);

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          showAppToast(context, e.toString(), ToastType.error);
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'اسم العميل',
              prefixIcon: const Icon(Icons.person, color: Color(0xFF8B5FBF)),
              suffixIcon:
                  _isCheckingName
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : _nameError != null
                      ? const Icon(Icons.error, color: Colors.red)
                      : null,
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
              errorText: _nameError,
            ),
            onChanged: (value) => _checkNameAvailability(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
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
            textDirection: TextDirection.ltr,
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
            onPressed: _isSaving ? null : () => Navigator.pop(context),
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
            onPressed: _isSaving || _isCheckingName ? null : _saveCustomer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A3093),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child:
                _isSaving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(widget.customer == null ? 'إضافة' : 'تحديث'),
          ),
        ),
      ],
    );
  }
}
