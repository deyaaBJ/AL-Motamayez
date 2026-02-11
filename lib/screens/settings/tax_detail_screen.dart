// screens/settings/tax_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:motamayez/widgets/settings/settings_detail_card.dart';
import 'package:motamayez/widgets/settings/settings_text_field.dart';
import 'package:motamayez/widgets/settings/settings_password_field.dart';
import 'package:motamayez/widgets/settings/change_password_dialog.dart';

class TaxDetailScreen extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onSave;
  final Function(String, String, String) onChangePassword;

  const TaxDetailScreen({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.onSave,
    required this.onChangePassword,
  });

  @override
  State<TaxDetailScreen> createState() => _TaxDetailScreenState();
}

class _TaxDetailScreenState extends State<TaxDetailScreen> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF34C759),
          elevation: 0,
          title: const Text(
            'حساب الضريبة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => setState(() => _isEditing = true),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildForm(),
              const SizedBox(height: 24),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34C759), Color(0xFF44D769)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF34C759).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.account_balance, size: 60, color: Colors.white),
    );
  }

  Widget _buildForm() {
    return SettingsDetailCard(
      child: Column(
        children: [
          SettingsTextField(
            controller: widget.nameController,
            label: 'اسم حساب الضريبة',
            icon: Icons.person_outline,
            enabled: _isEditing,
            color: const Color(0xFF34C759),
          ),
          const SizedBox(height: 20),
          SettingsTextField(
            controller: widget.emailController,
            label: 'البريد الإلكتروني',
            icon: Icons.email_outlined,
            enabled: _isEditing,
            color: const Color(0xFF34C759),
          ),
          const SizedBox(height: 20),
          SettingsPasswordField(
            controller: widget.passwordController,
            label: 'كلمة المرور الحالية',
            enabled: false,
            color: const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onSave();
                setState(() => _isEditing = false);
              },
              icon: const Icon(Icons.check),
              label: const Text('حفظ'),
              style: _buttonStyle(Colors.green),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isEditing = false),
              icon: const Icon(Icons.close),
              label: const Text('إلغاء'),
              style: _buttonStyle(Colors.red),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showChangePassword,
        icon: const Icon(Icons.lock_outline),
        label: const Text('تغيير كلمة المرور'),
        style: _buttonStyle(const Color(0xFF6A3093)),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showChangePassword() {
    showDialog(
      context: context,
      builder:
          (context) => ChangePasswordDialog(
            role: 'tax',
            currentPasswordController: widget.passwordController,
            onChange: widget.onChangePassword,
          ),
    );
  }
}
