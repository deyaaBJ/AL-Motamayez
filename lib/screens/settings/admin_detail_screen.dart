// screens/settings/admin_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:motamayez/widgets/settings/settings_detail_card.dart';
import 'package:motamayez/widgets/settings/settings_text_field.dart';
import 'package:motamayez/widgets/settings/settings_password_field.dart';
import 'package:motamayez/widgets/settings/change_password_dialog.dart';

class AdminDetailScreen extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final VoidCallback onSave;
  final Function(String, String, String) onChangePassword;

  const AdminDetailScreen({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.onSave,
    required this.onChangePassword,
  });

  @override
  State<AdminDetailScreen> createState() => _AdminDetailScreenState();
}

class _AdminDetailScreenState extends State<AdminDetailScreen> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: _buildAppBar(),
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

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFFF6B35),
      elevation: 0,
      title: const Text(
        'حساب المدير',
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
    );
  }

  Widget _buildHeader() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.admin_panel_settings,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  Widget _buildForm() {
    return SettingsDetailCard(
      child: Column(
        children: [
          SettingsTextField(
            controller: widget.nameController,
            label: 'اسم المدير',
            icon: Icons.person_outline,
            enabled: _isEditing,
            color: const Color(0xFFFF6B35),
          ),
          const SizedBox(height: 20),
          SettingsTextField(
            controller: widget.emailController,
            label: 'البريد الإلكتروني',
            icon: Icons.email_outlined,
            enabled: _isEditing,
            color: const Color(0xFFFF6B35),
          ),
          const SizedBox(height: 20),
          SettingsTextField(
            controller: widget.phoneController,
            label: 'رقم الهاتف',
            icon: Icons.phone_outlined,
            enabled: _isEditing,
            color: const Color(0xFFFF6B35),
          ),
          const SizedBox(height: 20),
          SettingsPasswordField(
            controller: widget.passwordController,
            label: 'كلمة المرور الحالية',
            enabled: false,
            color: const Color(0xFFFF6B35),
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
        label: const Text(
          'تغيير كلمة المرور',
          style: TextStyle(color: Colors.white),
        ),
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
            role: 'admin',
            currentPasswordController: widget.passwordController,
            onChange: widget.onChangePassword,
          ),
    );
  }
}
