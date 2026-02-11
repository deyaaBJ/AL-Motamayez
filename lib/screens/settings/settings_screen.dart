// screens/settings/settings_screen.dart
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
import 'package:motamayez/widgets/settings/settings_main_card.dart';
import 'package:motamayez/screens/settings/admin_detail_screen.dart';
import 'package:motamayez/screens/settings/cashiers_management_screen.dart';
import 'package:motamayez/screens/settings/tax_detail_screen.dart';
import 'package:motamayez/screens/settings/store_settings_screen.dart';
import 'package:motamayez/screens/settings/printer_settings_screen.dart';
import 'dart:developer';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Controllers
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _marketNameController = TextEditingController();
  final _cashierNameController = TextEditingController();
  final _cashierEmailController = TextEditingController();
  final _taxNameController = TextEditingController();
  final _taxEmailController = TextEditingController();
  final _currentPasswordAdminController = TextEditingController();
  final _currentPasswordCashierController = TextEditingController();
  final _currentPasswordTaxController = TextEditingController();
  final _printerIpController = TextEditingController();
  final _printerPortController = TextEditingController();

  String? _backupFolderPath;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      await settings.loadSettings();
      _marketNameController.text = settings.marketName ?? '';
      _printerIpController.text = settings.printerIp ?? '';
      _printerPortController.text = (settings.printerPort ?? 9100).toString();

      await _loadUserData(
        auth,
        'admin',
        _adminNameController,
        _adminEmailController,
        _adminPhoneController,
        _currentPasswordAdminController,
      );
      await _loadUserData(
        auth,
        'cashier',
        _cashierNameController,
        _cashierEmailController,
        null,
        _currentPasswordCashierController,
      );
      await _loadUserData(
        auth,
        'tax',
        _taxNameController,
        _taxEmailController,
        null,
        _currentPasswordTaxController,
      );

      await _loadBackupPath();
      setState(() {});
    } catch (e) {
      log('Error loading data: $e');
    }
  }

  Future<void> _loadUserData(
    AuthProvider auth,
    String role,
    TextEditingController nameCtrl,
    TextEditingController emailCtrl,
    TextEditingController? phoneCtrl,
    TextEditingController passCtrl,
  ) async {
    final users = await auth.getUsersByRole(role);
    if (users.isNotEmpty) {
      final user = users.first;
      nameCtrl.text = (user['name'] ?? role).toString();
      emailCtrl.text = (user['email'] ?? '$role@gmail.com').toString();
      phoneCtrl?.text = (user['phone'] ?? '').toString();
      passCtrl.text = user['password'] ?? '123456';
    } else {
      nameCtrl.text = role;
      emailCtrl.text = '$role@gmail.com';
      passCtrl.text = '123456';
    }
  }

  Future<void> _loadBackupPath() async {
    final appConfig = AppConfig(
      configFilePath: p.join(p.current, 'config.json'),
    );
    _backupFolderPath = await appConfig.getBackupFolderPath();
  }

  Future<void> _selectBackupFolder() async {
    final selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir != null) {
      final appConfig = AppConfig(
        configFilePath: p.join(p.current, 'config.json'),
      );
      await appConfig.setBackupFolderPath(selectedDir);
      setState(() => _backupFolderPath = selectedDir);
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
          builder:
              (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildGrid(constraints.maxWidth),
              ),
        ),
      ),
    );
  }

  Widget _buildGrid(double maxWidth) {
    final crossCount =
        maxWidth < 600
            ? 1
            : maxWidth < 1000
            ? 2
            : 3;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossCount,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 1.6,
      children: [
        _buildCard(
          'حساب المدير',
          'إدارة بيانات المدير',
          Icons.admin_panel_settings,
          const [Color(0xFFFF6B35), Color(0xFFFF8E53)],
          () => _navigate(
            AdminDetailScreen(
              nameController: _adminNameController,
              emailController: _adminEmailController,
              phoneController: _adminPhoneController,
              passwordController: _currentPasswordAdminController,
              onSave:
                  () => _saveUserData(
                    'admin',
                    _adminNameController,
                    _adminEmailController,
                    _adminPhoneController,
                  ),
              onChangePassword: (r, o, n) => _changePassword(r, o, n),
            ),
          ),
        ),
        _buildCard(
          'الكاشيرز',
          'إدارة جميع الكاشيرز',
          Icons.people_alt,
          const [Color(0xFF4A90E2), Color(0xFF5BA0F2)],
          () => _navigate(const CashiersManagementScreen()),
        ),
        _buildCard(
          'حساب الضريبة',
          'إعدادات الضريبة',
          Icons.account_balance,
          const [Color(0xFF34C759), Color(0xFF44D769)],
          () => _navigate(
            TaxDetailScreen(
              nameController: _taxNameController,
              emailController: _taxEmailController,
              passwordController: _currentPasswordTaxController,
              onSave:
                  () => _saveUserData(
                    'tax',
                    _taxNameController,
                    _taxEmailController,
                    null,
                  ),
              onChangePassword: (r, o, n) => _changePassword(r, o, n),
            ),
          ),
        ),
        _buildCard(
          'إعدادات المتجر',
          'المتجر والعملة والمخزون',
          Icons.store,
          const [Color(0xFF9C27B0), Color(0xFFBA68C8)],
          () => _navigate(
            StoreSettingsScreen(
              marketNameController: _marketNameController,
              backupFolderPath: _backupFolderPath,
              onSelectBackupFolder: _selectBackupFolder,
              onSaveMarketName: _saveMarketName,
            ),
          ),
        ),
        _buildCard(
          'الطابعة',
          'إعدادات الطباعة',
          Icons.print,
          const [Color(0xFF009688), Color(0xFF26A69A)],
          () => _navigate(
            PrinterSettingsScreen(
              ipController: _printerIpController,
              portController: _printerPortController,
            ),
          ),
        ),
        _buildCard(
          'الدعم الفني',
          'معلومات التواصل',
          Icons.support_agent,
          const [Color(0xFF6A3093), Color(0xFF8B5FBF)],
          _showSupportDialog,
        ),
      ],
    );
  }

  Widget _buildCard(
    String title,
    String subtitle,
    IconData icon,
    List<Color> gradient,
    VoidCallback onTap,
  ) {
    return SettingsMainCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      gradient: gradient,
      onTap: onTap,
    );
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
                  _buildSupportHeader(),
                  const SizedBox(height: 24),
                  _buildContactItem(
                    Icons.person,
                    'اسم المطور',
                    AppConstants.developerName,
                  ),
                  const SizedBox(height: 16),
                  _buildContactItem(
                    Icons.email,
                    'البريد',
                    AppConstants.developerEmail,
                  ),
                  const SizedBox(height: 16),
                  _buildContactItem(
                    Icons.phone,
                    'الهاتف',
                    AppConstants.developerPhone,
                  ),
                  const SizedBox(height: 32),
                  _buildCloseButton(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSupportHeader() {
    return Container(
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
    );
  }

  Widget _buildContactItem(IconData icon, String title, String value) {
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

  Widget _buildCloseButton() {
    return SizedBox(
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _saveUserData(
    String role,
    TextEditingController nameCtrl,
    TextEditingController emailCtrl,
    TextEditingController? phoneCtrl,
  ) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.updateUserDataByRole(
      role: role,
      name: nameCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      phone: phoneCtrl?.text.trim(),
    );
    showAppToast(context, 'تم التحديث بنجاح', ToastType.success);
  }

  Future<void> _saveMarketName(String name) async {
    if (name.isEmpty) {
      showAppToast(context, 'الرجاء إدخال الاسم', ToastType.error);
      return;
    }
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.updateMarketName(name);
    showAppToast(context, 'تم الحفظ بنجاح', ToastType.success);
  }

  Future<void> _changePassword(
    String role,
    String oldPass,
    String newPass,
  ) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.changePasswordByRole(
      role: role,
      oldPassword: oldPass,
      newPassword: newPass,
    );

    showAppToast(
      context,
      success ? 'تم تغيير كلمة المرور' : 'فشل تغيير كلمة المرور',
      success ? ToastType.success : ToastType.error,
    );

    if (success) _loadData();
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
    _printerIpController.dispose();
    _printerPortController.dispose();
    super.dispose();
  }
}
