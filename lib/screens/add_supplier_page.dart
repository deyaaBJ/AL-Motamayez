import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/models/supplier_model.dart';
import '../providers/supplier_provider.dart';

class AddEditSupplierPage extends StatefulWidget {
  final SupplierModel? supplier; // null يعني إضافة، غير null يعني تعديل

  const AddEditSupplierPage({super.key, this.supplier});

  @override
  State<AddEditSupplierPage> createState() => _AddEditSupplierPageState();
}

class _AddEditSupplierPageState extends State<AddEditSupplierPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // إذا كان هناك مورد (تعديل) نملأ الحقول ببياناته
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!.name;
      _phoneController.text = widget.supplier!.phone ?? '';
      _addressController.text = widget.supplier!.address ?? '';
      _notesController.text = widget.supplier!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<SupplierProvider>(context, listen: false);

      if (widget.supplier == null) {
        // حالة الإضافة
        await provider.addSupplier(
          name: _nameController.text,
          phone:
              _phoneController.text.isNotEmpty ? _phoneController.text : null,
          address:
              _addressController.text.isNotEmpty
                  ? _addressController.text
                  : null,
          notes:
              _notesController.text.isNotEmpty ? _notesController.text : null,
        );
        _showSuccess('تم إضافة المورد بنجاح');
      } else {
        // حالة التعديل
        await provider.updateSupplier(
          supplierId: widget.supplier!.id,
          name: _nameController.text,
          phone:
              _phoneController.text.isNotEmpty ? _phoneController.text : null,
          address:
              _addressController.text.isNotEmpty
                  ? _addressController.text
                  : null,
          notes:
              _notesController.text.isNotEmpty ? _notesController.text : null,
        );
        _showSuccess('تم تعديل المورد بنجاح');
      }

      // الانتقال للخلف بعد تأخير قصير
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('خطأ في حفظ المورد: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.supplier != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: isEditMode ? 'تعديل مورد' : 'إضافة مورد جديد',
        child: _buildContent(isEditMode),
      ),
    );
  }

  Widget _buildContent(bool isEditMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(isEditMode),
          const SizedBox(height: 20),
          _buildSupplierForm(),
          const SizedBox(height: 20),
          _buildSaveButton(isEditMode),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isEditMode) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isEditMode ? Icons.edit : Icons.person_add,
              size: 32,
              color: isEditMode ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditMode ? 'تعديل المورد' : 'إضافة مورد جديد',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEditMode
                        ? 'قم بتعديل بيانات المورد'
                        : 'أضف موردًا جديدًا لإدارة المشتريات',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // اسم المورد
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المورد *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  hintText: 'أدخل اسم المورد',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم المورد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // رقم الهاتف
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: 'أدخل رقم الهاتف',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              // العنوان
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  hintText: 'أدخل عنوان المورد',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // الملاحظات
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  hintText: 'أي ملاحظات إضافية',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isEditMode) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveSupplier,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEditMode ? Colors.orange : Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isEditMode ? Icons.edit : Icons.save,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditMode ? 'تعديل المورد' : 'حفظ المورد',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
