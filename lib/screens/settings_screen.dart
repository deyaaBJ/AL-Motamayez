// screens/settings_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:motamayez/utils/app_config.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:motamayez/components/base_layout.dart';
import 'package:motamayez/constant/constant.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'dart:developer';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // متحكمات المدير
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPhoneController = TextEditingController();
  final TextEditingController _marketNameController = TextEditingController();

  // متحكمات الكاشير
  final TextEditingController _cashierNameController = TextEditingController();
  final TextEditingController _cashierEmailController = TextEditingController();

  // متحكمات مسؤول الضريبة
  final TextEditingController _taxNameController = TextEditingController();
  final TextEditingController _taxEmailController = TextEditingController();

  // متحكمات مشتركة
  final TextEditingController _currentPasswordAdminController =
      TextEditingController();
  final TextEditingController _currentPasswordCashierController =
      TextEditingController();
  final TextEditingController _currentPasswordTaxController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  //معلومات الطابعة
  final TextEditingController _printerIpController = TextEditingController();
  final TextEditingController _printerPortController = TextEditingController();

  // متغيرات لإخفاء كلمات المرور
  bool _obscureAdminPassword = true;
  bool _obscureCashierPassword = true;
  bool _obscureTaxPassword = true;

  // مسار النسخ الاحتياطي
  String? _backupFolderPath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBackupPath();
  }

  Future<void> _loadUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );

      await settingsProvider.loadSettings();
      _marketNameController.text = settingsProvider.marketName ?? '';

      //بيانات الطابعة
      _printerIpController.text = settingsProvider.printerIp ?? '';
      _printerPortController.text =
          (settingsProvider.printerPort ?? 9100).toString();

      // جلب بيانات المدير
      final admins = await authProvider.getUsersByRole('admin');
      if (admins.isNotEmpty) {
        final admin = admins.first;
        _adminNameController.text = (admin['name'] ?? '').toString();
        _adminEmailController.text = (admin['email'] ?? '').toString();
        _adminPhoneController.text = (admin['phone'] ?? '').toString();
        _currentPasswordAdminController.text = admin['password'] ?? '';
      } else {
        _adminNameController.text = 'admin';
        _adminEmailController.text = 'admin@gmail.com';
        _currentPasswordAdminController.text = '123456';
        _adminPhoneController.text = '';
      }

      // جلب بيانات الكاشير
      final cashiers = await authProvider.getUsersByRole('cashier');
      if (cashiers.isNotEmpty) {
        final cashier = cashiers.first;
        _cashierNameController.text = (cashier['name'] ?? '').toString();
        _cashierEmailController.text = (cashier['email'] ?? '').toString();
        _currentPasswordCashierController.text = cashier['password'] ?? '';
      } else {
        _cashierNameController.text = 'cashier';
        _cashierEmailController.text = 'cashier@gmail.com';
        _currentPasswordCashierController.text = '123456';
      }

      // جلب بيانات حساب الضريبة
      final tax = await authProvider.getUsersByRole('tax');
      if (tax.isNotEmpty) {
        final taxAcaunt = tax.first;
        _taxNameController.text = (taxAcaunt['name'] ?? '').toString();
        _taxEmailController.text = (taxAcaunt['email'] ?? '').toString();
        _currentPasswordTaxController.text = taxAcaunt['password'] ?? '';
      } else {
        _taxNameController.text = 'tax';
        _taxEmailController.text = 'tax@gmail.com';
        _currentPasswordTaxController.text = '123456';
      }

      setState(() {});
    } catch (e) {
      log('Error loading user data: $e');
      setState(() {});
    }
  }

  Future<void> _loadBackupPath() async {
    final appConfig = AppConfig(
      configFilePath: p.join(p.current, 'config.json'),
    );
    final path = await appConfig.getBackupFolderPath();
    setState(() {
      _backupFolderPath = path;
    });
  }

  Future<void> _selectBackupFolder() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir != null) {
      final appConfig = AppConfig(
        configFilePath: p.join(p.current, 'config.json'),
      );
      await appConfig.setBackupFolderPath(selectedDir);

      setState(() {
        _backupFolderPath = selectedDir;
      });

      showAppToast(context, 'تم حفظ مكان النسخ الاحتياطي', ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BaseLayout(
        currentPage: 'settings',
        title: 'الإعدادات',
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildMainGrid(constraints.maxWidth),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainGrid(double maxWidth) {
    // تحديد عدد الأعمدة حسب عرض الشاشة
    int crossAxisCount =
        maxWidth < 600
            ? 1
            : maxWidth < 1200
            ? 2
            : 3;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 1.1,
      children: [
        _buildMainCard(
          title: 'حساب المدير',
          subtitle: 'إدارة بيانات المدير وكلمة المرور',
          icon: Icons.admin_panel_settings,
          color: const Color(0xFFFF6B35),
          gradient: const [Color(0xFFFF6B35), Color(0xFFFF8E53)],
          onTap:
              () => _navigateToDetail(
                AdminDetailScreen(
                  nameController: _adminNameController,
                  emailController: _adminEmailController,
                  phoneController: _adminPhoneController,
                  passwordController: _currentPasswordAdminController,
                  onSave: _saveAdminChanges,
                  onChangePassword: () => _showChangePasswordDialog('admin'),
                ),
              ),
        ),
        _buildMainCard(
          title: 'الكاشيرز',
          subtitle: 'إدارة جميع الكاشيرز وإضافة جديد',
          icon: Icons.people_alt,
          color: const Color(0xFF4A90E2),
          gradient: const [Color(0xFF4A90E2), Color(0xFF5BA0F2)],
          onTap: () => _navigateToDetail(const CashiersManagementScreen()),
        ),
        _buildMainCard(
          title: 'حساب الضريبة',
          subtitle: 'إعدادات حساب الضريبة والتقارير',
          icon: Icons.account_balance,
          color: const Color(0xFF34C759),
          gradient: const [Color(0xFF34C759), Color(0xFF44D769)],
          onTap:
              () => _navigateToDetail(
                TaxDetailScreen(
                  nameController: _taxNameController,
                  emailController: _taxEmailController,
                  passwordController: _currentPasswordTaxController,
                  onSave: _saveTaxChanges,
                  onChangePassword: () => _showChangePasswordDialog('tax'),
                ),
              ),
        ),
        _buildMainCard(
          title: 'إعدادات المتجر',
          subtitle: 'اسم المتجر والعملة والمخزون',
          icon: Icons.store,
          color: const Color(0xFF9C27B0),
          gradient: const [Color(0xFF9C27B0), Color(0xFFBA68C8)],
          onTap:
              () => _navigateToDetail(
                StoreSettingsScreen(
                  marketNameController: _marketNameController,
                  backupFolderPath: _backupFolderPath,
                  onSelectBackupFolder: _selectBackupFolder,
                  onSaveMarketName: _saveMarketName,
                ),
              ),
        ),
        _buildMainCard(
          title: 'الطابعة والفواتير',
          subtitle: 'إعدادات الطباعة وحجم الورق',
          icon: Icons.print,
          color: const Color(0xFF009688),
          gradient: const [Color(0xFF009688), Color(0xFF26A69A)],
          onTap:
              () => _navigateToDetail(
                PrinterSettingsScreen(
                  ipController: _printerIpController,
                  portController: _printerPortController,
                ),
              ),
        ),
        _buildMainCard(
          title: 'الدعم الفني',
          subtitle: 'معلومات التواصل والمساعدة',
          icon: Icons.support_agent,
          color: const Color(0xFF6A3093),
          gradient: const [Color(0xFF6A3093), Color(0xFF8B5FBF)],
          onTap: () => _showSupportDialog(),
        ),
      ],
    );
  }

  Widget _buildMainCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // الدائرة الزخرفية
              Positioned(
                left: -30,
                top: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: -20,
                bottom: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              // المحتوى
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'إدارة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
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

  void _navigateToDetail(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A3093).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      size: 48,
                      color: Color(0xFF6A3093),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'الدعم الفني',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'نحن هنا لمساعدتك',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _buildContactTile(
                    icon: Icons.person,
                    title: 'اسم المطور',
                    value: AppConstants.developerName,
                  ),
                  const SizedBox(height: 16),
                  _buildContactTile(
                    icon: Icons.email,
                    title: 'البريد الإلكتروني',
                    value: AppConstants.developerEmail,
                  ),
                  const SizedBox(height: 16),
                  _buildContactTile(
                    icon: Icons.phone,
                    title: 'رقم الهاتف',
                    value: AppConstants.developerPhone,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A3093),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'إغلاق',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6A3093).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF6A3093)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMarketName(String newName) async {
    if (newName.isEmpty) {
      showAppToast(context, 'الرجاء إدخال اسم السوبر ماركت', ToastType.error);
      return;
    }

    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    await settingsProvider.updateMarketName(newName);

    showAppToast(context, 'تم حفظ اسم السوبر ماركت بنجاح', ToastType.success);
  }

  Future<void> _saveAdminChanges() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.updateUserDataByRole(
      role: 'admin',
      name: _adminNameController.text.trim(),
      email: _adminEmailController.text.trim(),
      phone: _adminPhoneController.text.trim(),
    );

    showAppToast(context, 'تم تحديث بيانات المدير بنجاح', ToastType.success);
  }

  Future<void> _saveTaxChanges() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.updateUserDataByRole(
      role: 'tax',
      name: _taxNameController.text.trim(),
      email: _taxEmailController.text.trim(),
    );

    showAppToast(
      context,
      'تم تحديث بيانات حساب الضريبة بنجاح',
      ToastType.success,
    );
  }

  void _showChangePasswordDialog(String role) {
    showDialog(
      context: context,
      builder: (context) {
        bool obscureCurrent = true;
        bool obscureNew = true;
        bool obscureConfirm = true;

        return StatefulBuilder(
          builder: (context, setState) {
            String dialogTitle;
            TextEditingController currentPasswordController;

            if (role == 'admin') {
              dialogTitle = 'تغيير كلمة مرور المدير';
              currentPasswordController = _currentPasswordAdminController;
            } else if (role == 'cashier') {
              dialogTitle = 'تغيير كلمة مرور الكاشير';
              currentPasswordController = _currentPasswordCashierController;
            } else {
              dialogTitle = 'تغيير كلمة مرور حساب الضريبة';
              currentPasswordController = _currentPasswordTaxController;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.lock, color: Color(0xFF6A3093)),
                  const SizedBox(width: 8),
                  Text(
                    dialogTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogPasswordField(
                      controller: currentPasswordController,
                      label: 'كلمة المرور الحالية',
                      obscureText: obscureCurrent,
                      onToggle:
                          () =>
                              setState(() => obscureCurrent = !obscureCurrent),
                    ),
                    const SizedBox(height: 16),
                    _buildDialogPasswordField(
                      controller: _newPasswordController,
                      label: 'كلمة المرور الجديدة',
                      obscureText: obscureNew,
                      onToggle: () => setState(() => obscureNew = !obscureNew),
                    ),
                    const SizedBox(height: 16),
                    _buildDialogPasswordField(
                      controller: _confirmPasswordController,
                      label: 'تأكيد كلمة المرور',
                      obscureText: obscureConfirm,
                      onToggle:
                          () =>
                              setState(() => obscureConfirm = !obscureConfirm),
                    ),
                    const SizedBox(height: 12),
                    Container(
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
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearPasswordFields();
                  },
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _changePassword(role),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A3093),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'تغيير كلمة المرور',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }

  void _changePassword(String role) async {
    final oldPasswordController =
        role == 'admin'
            ? _currentPasswordAdminController
            : role == 'cashier'
            ? _currentPasswordCashierController
            : _currentPasswordTaxController;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_newPasswordController.text != _confirmPasswordController.text) {
      showAppToast(context, 'كلمات المرور غير متطابقة', ToastType.error);
      return;
    }

    final success = await authProvider.changePasswordByRole(
      role: role,
      oldPassword: oldPasswordController.text.trim(),
      newPassword: _newPasswordController.text.trim(),
    );

    Navigator.pop(context);
    _clearPasswordFields();

    showAppToast(
      context,
      success ? 'تم تغيير كلمة المرور بنجاح' : 'كلمة المرور الحالية غير صحيحة',
      success ? ToastType.success : ToastType.error,
    );

    if (success) {
      oldPasswordController.text = _newPasswordController.text;
      _loadUserData();
    }
  }

  void _clearPasswordFields() {
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  @override
  void dispose() {
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    _marketNameController.dispose();
    _cashierNameController.dispose();
    _cashierEmailController.dispose();
    _taxNameController.dispose();
    _taxEmailController.dispose();
    _currentPasswordAdminController.dispose();
    _currentPasswordCashierController.dispose();
    _currentPasswordTaxController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _printerIpController.dispose();
    _printerPortController.dispose();
    super.dispose();
  }
}

// ==================== شاشة تفاصيل المدير ====================
class AdminDetailScreen extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final VoidCallback onSave;
  final VoidCallback onChangePassword;

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
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
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
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // صورة الملف الشخصي
              Container(
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
              ),
              const SizedBox(height: 32),
              _buildDetailCard(
                child: Column(
                  children: [
                    _buildTextField(
                      controller: widget.nameController,
                      label: 'اسم المدير',
                      icon: Icons.person_outline,
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: widget.emailController,
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: widget.phoneController,
                      label: 'رقم الهاتف',
                      icon: Icons.phone_outlined,
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 20),
                    _buildPasswordField(
                      controller: widget.passwordController,
                      label: 'كلمة المرور الحالية',
                      obscureText: _obscurePassword,
                      onToggle:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                      enabled: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onSave();
                          setState(() => _isEditing = false);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('حفظ التغييرات'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isEditing = false),
                        icon: const Icon(Icons.close),
                        label: const Text('إلغاء'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onChangePassword,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('تغيير كلمة المرور'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A3093),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFFF6B35)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[50],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFF6B35)),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFFFF6B35),
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[50],
      ),
    );
  }
}

// ==================== شاشة إدارة الكاشيرز ====================
class CashiersManagementScreen extends StatefulWidget {
  const CashiersManagementScreen({super.key});

  @override
  State<CashiersManagementScreen> createState() =>
      _CashiersManagementScreenState();
}

class _CashiersManagementScreenState extends State<CashiersManagementScreen> {
  List<Map<String, dynamic>> cashiers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCashiers();
  }

  Future<void> _loadCashiers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final data = await authProvider.getUsersByRole('cashier');
    setState(() {
      cashiers = data;
      _isLoading = false;
    });
  }

  void _showAddCashierDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'إضافة كاشير جديد',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الكاشير',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () async {
                  // منطق إضافة الكاشير
                  Navigator.pop(context);
                  _loadCashiers();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                ),
                child: const Text(
                  'إضافة',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4A90E2),
          elevation: 0,
          title: const Text(
            'إدارة الكاشيرز',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddCashierDialog,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddCashierDialog,
          backgroundColor: const Color(0xFF4A90E2),
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة كاشير'),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : cashiers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cashiers.length,
                  itemBuilder: (context, index) {
                    final cashier = cashiers[index];
                    return _buildCashierCard(cashier);
                  },
                ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا يوجد كاشيرز مضافين',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddCashierDialog,
            icon: const Icon(Icons.add),
            label: const Text('إضافة كاشير جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashierCard(Map<String, dynamic> cashier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF5BA0F2)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 30),
        ),
        title: Text(
          cashier['name'] ?? 'غير معروف',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          cashier['email'] ?? '',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              // تعديل
            } else if (value == 'delete') {
              // حذف
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف'),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }
}

// ==================== شاشة تفاصيل الضريبة ====================
class TaxDetailScreen extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onSave;
  final VoidCallback onChangePassword;

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
  bool _obscurePassword = true;

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
              Container(
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
                child: const Icon(
                  Icons.account_balance,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: widget.nameController,
                      label: 'اسم حساب الضريبة',
                      icon: Icons.person_outline,
                      enabled: _isEditing,
                      color: const Color(0xFF34C759),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: widget.emailController,
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                      enabled: _isEditing,
                      color: const Color(0xFF34C759),
                    ),
                    const SizedBox(height: 20),
                    _buildPasswordField(
                      controller: widget.passwordController,
                      label: 'كلمة المرور الحالية',
                      obscureText: _obscurePassword,
                      onToggle:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                      enabled: false,
                      color: const Color(0xFF34C759),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onSave();
                          setState(() => _isEditing = false);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('حفظ التغييرات'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isEditing = false),
                        icon: const Icon(Icons.close),
                        label: const Text('إلغاء'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onChangePassword,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('تغيير كلمة المرور'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A3093),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    required Color color,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[50],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    required bool enabled,
    required Color color,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: color),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: color,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[50],
      ),
    );
  }
}

// ==================== شاشة إعدادات المتجر ====================
class StoreSettingsScreen extends StatelessWidget {
  final TextEditingController marketNameController;
  final String? backupFolderPath;
  final VoidCallback onSelectBackupFolder;
  final Function(String) onSaveMarketName;

  const StoreSettingsScreen({
    super.key,
    required this.marketNameController,
    required this.backupFolderPath,
    required this.onSelectBackupFolder,
    required this.onSaveMarketName,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF9C27B0),
          elevation: 0,
          title: const Text(
            'إعدادات المتجر',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildSettingsSection(
                    title: 'معلومات المتجر',
                    icon: Icons.store,
                    child: Column(
                      children: [
                        TextField(
                          controller: marketNameController,
                          decoration: InputDecoration(
                            labelText: 'اسم السوبر ماركت',
                            prefixIcon: const Icon(
                              Icons.store,
                              color: Color(0xFF9C27B0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                () =>
                                    onSaveMarketName(marketNameController.text),
                            icon: const Icon(Icons.save),
                            label: const Text('حفظ الاسم'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9C27B0),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'إعدادات العملة',
                    icon: Icons.currency_exchange,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: settings.currency,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          items: const [
                            DropdownMenuItem(
                              value: 'USD',
                              child: Text("🇺🇸 الدولار الأمريكي (USD)"),
                            ),
                            DropdownMenuItem(
                              value: 'JOD',
                              child: Text("🇯🇴 الدينار الأردني (JOD)"),
                            ),
                            DropdownMenuItem(
                              value: 'ILS',
                              child: Text("🇮🇱 الشيكل الإسرائيلي (ILS)"),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) settings.updateCurrency(value);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'إعدادات المخزون',
                    icon: Icons.inventory_2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحد الأدنى للمخزون: ${settings.lowStockThreshold}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Slider(
                          value: settings.lowStockThreshold.toDouble(),
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: settings.lowStockThreshold.toString(),
                          activeColor: const Color(0xFF9C27B0),
                          onChanged: (value) {
                            settings.updateLowStockThreshold(value.round());
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'النسخ الاحتياطي',
                    icon: Icons.backup,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder,
                                color:
                                    backupFolderPath != null
                                        ? Colors.green
                                        : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  backupFolderPath ?? 'لم يتم تحديد مكان',
                                  style: TextStyle(
                                    color:
                                        backupFolderPath != null
                                            ? Colors.green
                                            : Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onSelectBackupFolder,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('اختيار مكان النسخ الاحتياطي'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9C27B0),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: settings.numberOfCopies ?? 1,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              items: List.generate(7, (index) {
                                final value = index + 1;
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value نسخة'),
                                );
                              }),
                              onChanged: (value) {
                                if (value != null) {
                                  settings.updateNumberOfCopies(value);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF9C27B0)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ==================== شاشة إعدادات الطابعة ====================
class PrinterSettingsScreen extends StatelessWidget {
  final TextEditingController ipController;
  final TextEditingController portController;

  const PrinterSettingsScreen({
    super.key,
    required this.ipController,
    required this.portController,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF009688),
          elevation: 0,
          title: const Text(
            'إعدادات الطابعة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF009688), Color(0xFF26A69A)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.print,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: ipController,
                          decoration: InputDecoration(
                            labelText: 'عنوان IP للطابعة',
                            prefixIcon: const Icon(
                              Icons.network_wifi,
                              color: Color(0xFF009688),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: portController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'منفذ الطابعة (مثال: 9100)',
                            prefixIcon: const Icon(
                              Icons.usb,
                              color: Color(0xFF009688),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: settings.paperSize,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: '58mm',
                                  child: Text('58mm (فاتورة صغيرة)'),
                                ),
                                DropdownMenuItem(
                                  value: '80mm',
                                  child: Text('80mm (فاتورة كبيرة)'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  settings.updatePaperSize(value);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final ip = ipController.text.trim();
                              final portText = portController.text.trim();

                              if (ip.isEmpty || portText.isEmpty) {
                                showAppToast(
                                  context,
                                  'الرجاء إدخال جميع البيانات',
                                  ToastType.error,
                                );
                                return;
                              }

                              final port = int.tryParse(portText);
                              if (port == null) {
                                showAppToast(
                                  context,
                                  'رقم المنفذ غير صحيح',
                                  ToastType.error,
                                );
                                return;
                              }

                              settings.updatePrinterSettings(
                                ip: ip,
                                port: port,
                                size: settings.paperSize ?? '58mm',
                              );

                              showAppToast(
                                context,
                                'تم حفظ الإعدادات بنجاح',
                                ToastType.success,
                              );
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('حفظ الإعدادات'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009688),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
