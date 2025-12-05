// screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/components/base_layout.dart';
import 'package:shopmate/constant/constant.dart';
import 'package:shopmate/helpers/helpers.dart';
import 'package:shopmate/providers/auth_provider.dart';
import 'package:shopmate/providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // متحكمات المدير
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
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

  int _lowStockThreshold = 5;
  bool _isEditingAdmin = false;
  bool _isEditingCashier = false;
  bool _isEditingTax = false;
  bool _isChangingPassword = false;
  bool _isAdminPassword = true;
  bool _isCashierPassword = true;
  bool _isTaxPassword = true;

  // متغيرات لإخفاء كلمات المرور
  bool _obscureAdminPassword = true;
  bool _obscureCashierPassword = true;
  bool _obscureTaxPassword = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

      // جلب بيانات المدير
      final admins = await authProvider.getUsersByRole('admin');
      if (admins.isNotEmpty) {
        final admin = admins.first;
        _adminNameController.text = (admin['name'] ?? '').toString();
        _adminEmailController.text = (admin['email'] ?? '').toString();
        _currentPasswordAdminController.text = admin['password'] ?? '';
      } else {
        _adminNameController.text = 'admin';
        _adminEmailController.text = 'admin@gmail.com';
        _currentPasswordAdminController.text = '123456';
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
      print('Error loading user data: $e');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // واجهة عربية كاملة
      child: BaseLayout(
        currentPage: 'settings', // اسم الصفحة للسايدبار
        showAppBar: true,
        title: 'الإعدادات',
        actions: [
          IconButton(
            onPressed: () {
              // أي عملية تحديث إذا احتجت
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildResponsiveLayout(constraints.maxWidth),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(double maxWidth) {
    if (maxWidth < 900) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildAdminCard(),
        const SizedBox(height: 20),
        _buildCashierCard(),
        const SizedBox(height: 20),
        _buildTaxCard(),
        const SizedBox(height: 20),
        _buildContactCard(),
        const SizedBox(height: 20),
        _buildStockSettingsCard(),
        const SizedBox(height: 20),
        _buildTaxSettingsCard(),
        const SizedBox(height: 20),
        _buildCurrencyCard(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        // الصف الأول: الحسابات
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildAdminCard(),
                  const SizedBox(height: 20),
                  _buildCashierCard(),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  _buildTaxCard(),
                  const SizedBox(height: 20),
                  _buildContactCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // الصف الثاني: الإعدادات - الثلاث كروت بنفس الحجم
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // إعدادات المخزون
            Expanded(child: _buildStockSettingsCard()),
            const SizedBox(width: 15),

            // الإعدادات الضريبية
            Expanded(child: _buildTaxSettingsCard()),
            const SizedBox(width: 15),

            // إعدادات العملة
            Expanded(child: _buildCurrencyCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminCard() {
    return _buildSettingsCard(
      title: 'حساب المدير',
      icon: Icons.admin_panel_settings,
      color: const Color(0xFFFF6B35),
      child: Column(
        children: [
          _buildTextFieldWithIcon(
            controller: _adminNameController,
            label: 'اسم المدير',
            icon: Icons.person_outline,
            enabled: _isEditingAdmin,
          ),
          const SizedBox(height: 15),
          _buildTextFieldWithIcon(
            controller: _adminEmailController,
            label: 'البريد الإلكتروني',
            icon: Icons.email_outlined,
            enabled: _isEditingAdmin,
          ),
          const SizedBox(height: 15),
          _buildPasswordField(
            controller: _currentPasswordAdminController,
            label: 'كلمة المرور الحالية',
            obscureText: _obscureAdminPassword,
            onToggle:
                () => setState(
                  () => _obscureAdminPassword = !_obscureAdminPassword,
                ),
            enabled: false,
          ),
          const SizedBox(height: 15),
          _buildTextFieldWithIcon(
            controller: _marketNameController,
            label: 'اسم المتجر / السوبر ماركت',
            icon: Icons.storefront_outlined,
            enabled: _isEditingAdmin,
          ),
          const SizedBox(height: 20),
          _buildCardActions(
            isEditing: _isEditingAdmin,
            onEdit: () => setState(() => _isEditingAdmin = true),
            onSave: _saveAdminChanges,
            onCancel:
                () => setState(() {
                  _isEditingAdmin = false;
                  _loadUserData();
                }),
            onChangePassword: () {
              setState(() {
                _isChangingPassword = true;
                _isAdminPassword = true;
                _isCashierPassword = false;
                _isTaxPassword = false;
              });
              _showChangePasswordDialog();
            },
            color: const Color(0xFFFF6B35),
          ),
        ],
      ),
    );
  }

  Widget _buildCashierCard() {
    return _buildSettingsCard(
      title: 'حساب الكاشير',
      icon: Icons.person,
      color: const Color(0xFF4A90E2),
      child: Column(
        children: [
          _buildTextFieldWithIcon(
            controller: _cashierNameController,
            label: 'اسم الكاشير',
            icon: Icons.person_outline,
            enabled: _isEditingCashier,
          ),
          const SizedBox(height: 15),
          _buildTextFieldWithIcon(
            controller: _cashierEmailController,
            label: 'البريد الإلكتروني',
            icon: Icons.email_outlined,
            enabled: _isEditingCashier,
          ),
          const SizedBox(height: 15),
          _buildPasswordField(
            controller: _currentPasswordCashierController,
            label: 'كلمة المرور الحالية',
            obscureText: _obscureCashierPassword,
            onToggle:
                () => setState(
                  () => _obscureCashierPassword = !_obscureCashierPassword,
                ),
            enabled: false,
          ),
          const SizedBox(height: 20),
          _buildCardActions(
            isEditing: _isEditingCashier,
            onEdit: () => setState(() => _isEditingCashier = true),
            onSave: _saveCashierChanges,
            onCancel:
                () => setState(() {
                  _isEditingCashier = false;
                  _loadUserData();
                }),
            onChangePassword: () {
              setState(() {
                _isChangingPassword = true;
                _isCashierPassword = true;
                _isAdminPassword = false;
                _isTaxPassword = false;
              });
              _showChangePasswordDialog();
            },
            color: const Color(0xFF4A90E2),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxCard() {
    return _buildSettingsCard(
      title: 'حساب الضريبة',
      icon: Icons.account_balance,
      color: const Color(0xFF34C759),
      child: Column(
        children: [
          _buildTextFieldWithIcon(
            controller: _taxNameController,
            label: 'اسم حساب الضريبة',
            icon: Icons.person_outline,
            enabled: _isEditingTax,
          ),
          const SizedBox(height: 15),
          _buildTextFieldWithIcon(
            controller: _taxEmailController,
            label: 'البريد الإلكتروني',
            icon: Icons.email_outlined,
            enabled: _isEditingTax,
          ),
          const SizedBox(height: 15),
          _buildPasswordField(
            controller: _currentPasswordTaxController,
            label: 'كلمة المرور الحالية',
            obscureText: _obscureTaxPassword,
            onToggle:
                () =>
                    setState(() => _obscureTaxPassword = !_obscureTaxPassword),
            enabled: false,
          ),
          const SizedBox(height: 20),
          _buildCardActions(
            isEditing: _isEditingTax,
            onEdit: () => setState(() => _isEditingTax = true),
            onSave: _saveTaxChanges,
            onCancel:
                () => setState(() {
                  _isEditingTax = false;
                  _loadUserData();
                }),
            onChangePassword: () {
              setState(() {
                _isChangingPassword = true;
                _isTaxPassword = true;
                _isAdminPassword = false;
                _isCashierPassword = false;
              });
              _showChangePasswordDialog();
            },
            color: const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return _buildSettingsCard(
      title: 'معلومات التواصل',
      icon: Icons.contact_support,
      color: const Color(0xFF6A3093),
      child: Column(
        children: [
          _buildContactItem(
            icon: Icons.person,
            title: 'اسم المطور',
            value: AppConstants.developerName,
          ),
          const SizedBox(height: 8),
          _buildContactItem(
            icon: Icons.email,
            title: 'البريد الإلكتروني',
            value: AppConstants.developerEmail,
          ),
          const SizedBox(height: 8),
          _buildContactItem(
            icon: Icons.phone,
            title: 'رقم الهاتف',
            value: AppConstants.developerPhone,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6A3093).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6A3093).withOpacity(0.2),
              ),
            ),
            child: const Text(
              'للاستفسارات والدعم الفني، لا تتردد في التواصل معنا',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6A3093),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSettingsCard() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return _buildSettingsCard(
          title: 'إعدادات المخزون',
          icon: Icons.inventory_2,
          color: const Color(0xFF4A1C6D),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'حدد الحد الأدنى لكمية المنتج التي تعتبر منخفضة:',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5FBF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الحد الحالي:',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6A3093)),
                    ),
                    Text(
                      '${settingsProvider.lowStockThreshold} قطعة',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A3093),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Slider(
                value: settingsProvider.lowStockThreshold.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                label: settingsProvider.lowStockThreshold.toString(),
                activeColor: const Color(0xFF8B5FBF),
                inactiveColor: const Color(0xFF8B5FBF).withOpacity(0.3),
                onChanged: (value) {
                  settingsProvider.updateLowStockThreshold(value.round());
                },
                onChangeEnd: (value) {
                  showAppToast(
                    context,
                    'تم حفظ الحد الأدنى للمخزون: ${value.round()}',
                    ToastType.success,
                  );
                },
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1', style: TextStyle(color: Colors.grey)),
                  Text('25', style: TextStyle(color: Colors.grey)),
                  Text('50', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaxSettingsCard() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return _buildSettingsCard(
          title: 'الإعدادات الضريبية',
          icon: Icons.receipt_long,
          color: Colors.blue[700]!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'الضريبة الافتراضية للمبيعات:',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: settingsProvider.defaultTaxSetting,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'غير مضمنه بالضرائب',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'مضمنه بالضرائب',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (int? newValue) {
                      settingsProvider.updateDefaultTaxSetting(newValue!);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'معلومة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تحدد إذا كانت الضريبة مضمنة تلقائياً في الفواتير الجديدة',
                      style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrencyCard() {
    final settings = Provider.of<SettingsProvider>(context);

    return _buildSettingsCard(
      title: 'إعدادات العملة',
      icon: Icons.currency_exchange,
      color: const Color(0xFFFFA000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'اختر العملة الافتراضية للنظام:',
            style: TextStyle(fontSize: 15, color: Colors.grey),
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
                value: settings.currency,
                isExpanded: true,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF6A3093),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'USD',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "🇺🇸 الدولار الأمريكي (USD)",
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'JOD',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "🇯🇴 الدينار الأردني (JOD)",
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'ILS',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "🇮🇱 الشيكل الإسرائيلي (ILS)",
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    settings.updateCurrency(newValue);
                    showAppToast(
                      context,
                      'تم تغيير العملة إلى $newValue',
                      ToastType.success,
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'معلومة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'سيتم تطبيق العملة المحددة على جميع الفواتير والعروض',
                  style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      height: 420,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldWithIcon({
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
        prefixIcon: Icon(icon, color: const Color(0xFF8B5FBF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5FBF), width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8B5FBF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5FBF), width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF8B5FBF),
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _buildContactItem({
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6A3093).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF6A3093)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A1C6D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardActions({
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    required VoidCallback onChangePassword,
    required Color color,
  }) {
    if (!isEditing) {
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              text: 'تعديل البيانات',
              icon: Icons.edit,
              color: color,
              onPressed: onEdit,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildActionButton(
              text: 'تغيير كلمة المرور',
              icon: Icons.lock_outline,
              color: const Color(0xFF6A3093),
              onPressed: onChangePassword,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              text: 'حفظ',
              icon: Icons.check,
              color: Colors.green,
              onPressed: onSave,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildActionButton(
              text: 'إلغاء',
              icon: Icons.close,
              color: Colors.red,
              onPressed: onCancel,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
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

            if (_isAdminPassword) {
              dialogTitle = 'تغيير كلمة مرور المدير';
              currentPasswordController = _currentPasswordAdminController;
            } else if (_isCashierPassword) {
              dialogTitle = 'تغيير كلمة مرور الكاشير';
              currentPasswordController = _currentPasswordCashierController;
            } else {
              dialogTitle = 'تغيير كلمة مرور حساب الضريبة';
              currentPasswordController = _currentPasswordTaxController;
            }

            return AlertDialog(
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
                  onPressed: _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A3093),
                  ),
                  child: Text(
                    _isAdminPassword
                        ? 'تغيير كلمة المدير'
                        : _isCashierPassword
                        ? 'تغيير كلمة الكاشير'
                        : 'تغيير كلمة حساب الضريبة',
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Future<void> _saveAdminChanges() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    await authProvider.updateUserDataByRole(
      role: 'admin',
      name: _adminNameController.text.trim(),
      email: _adminEmailController.text.trim(),
    );

    await settingsProvider.updateMarketName(_marketNameController.text.trim());

    setState(() => _isEditingAdmin = false);

    showAppToast(context, 'تم تحديث بيانات المدير بنجاح', ToastType.success);
  }

  Future<void> _saveCashierChanges() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.updateUserDataByRole(
      role: 'cashier',
      name: _cashierNameController.text.trim(),
      email: _cashierEmailController.text.trim(),
    );

    setState(() => _isEditingCashier = false);

    showAppToast(context, 'تم تحديث بيانات الكاشير بنجاح', ToastType.success);
  }

  Future<void> _saveTaxChanges() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.updateUserDataByRole(
      role: 'tax',
      name: _taxNameController.text.trim(),
      email: _taxEmailController.text.trim(),
    );

    setState(() => _isEditingTax = false);

    showAppToast(
      context,
      'تم تحديث بيانات حساب الضريبة بنجاح',
      ToastType.success,
    );
  }

  void _changePassword() async {
    final oldPasswordController =
        _isAdminPassword
            ? _currentPasswordAdminController
            : _isCashierPassword
            ? _currentPasswordCashierController
            : _currentPasswordTaxController;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role =
        _isAdminPassword
            ? 'admin'
            : _isCashierPassword
            ? 'cashier'
            : 'tax';

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
      success
          ? (_isAdminPassword
              ? 'تم تغيير كلمة مرور المدير بنجاح'
              : _isCashierPassword
              ? 'تم تغيير كلمة مرور الكاشير بنجاح'
              : 'تم تغيير كلمة مرور حساب الضريبة بنجاح')
          : 'كلمة المرور الحالية غير صحيحة أو حدث خطأ أثناء التحديث',
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
    super.dispose();
  }
}
