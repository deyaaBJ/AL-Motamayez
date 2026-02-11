// widgets/settings/change_password_dialog.dart
import 'package:flutter/material.dart';
import 'package:motamayez/helpers/helpers.dart';

class ChangePasswordDialog extends StatefulWidget {
  final String role;
  final TextEditingController currentPasswordController;
  final Function(String role, String oldPass, String newPass) onChange;

  const ChangePasswordDialog({
    super.key,
    required this.role,
    required this.currentPasswordController,
    required this.onChange,
  });

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String get _title {
    switch (widget.role) {
      case 'admin':
        return 'تغيير كلمة مرور المدير';
      case 'cashier':
        return 'تغيير كلمة مرور الكاشير';
      case 'tax':
        return 'تغيير كلمة مرور حساب الضريبة';
      default:
        return 'تغيير كلمة المرور';
    }
  }

  void _submit() {
    if (_newPassController.text != _confirmPassController.text) {
      // استخدم الـ context المناسب هنا
      return;
    }
    widget.onChange(
      widget.role,
      widget.currentPasswordController.text.trim(),
      _newPassController.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.lock, color: Color(0xFF6A3093)),
          const SizedBox(width: 8),
          Text(_title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildField(
              controller: widget.currentPasswordController,
              label: 'كلمة المرور الحالية',
              obscure: _obscureCurrent,
              onToggle:
                  () => setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _newPassController,
              label: 'كلمة المرور الجديدة',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _confirmPassController,
              label: 'تأكيد كلمة المرور',
              obscure: _obscureConfirm,
              onToggle:
                  () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 12),
            _buildInfoBox(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A3093),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'تغيير كلمة المرور',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.orange[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
              style: TextStyle(fontSize: 13, color: Colors.orange[700]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }
}
