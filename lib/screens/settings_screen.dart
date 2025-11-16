// screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopmate/constant/constant.dart';
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

  // متحكمات مشتركة
  final TextEditingController _currentPasswordAdminController =
      TextEditingController();
  final TextEditingController _currentPasswordCashierController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _lowStockController = TextEditingController();

  int _lowStockThreshold = 5;
  bool _isEditingAdmin = false;
  bool _isEditingCashier = false;
  bool _isChangingPassword = false;
  bool _isAdminPassword =
      true; // لتحديد إذا كان تغيير كلمة المرور للمدير أو الكاشير

  // داخل _SettingsScreenState

  @override
  void initState() {
    super.initState();
    // استدعاء غير متزامن لجلب البيانات من البروفايدر
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      // تأكد من تحميل الإعدادات من DB أولاً
      await settingsProvider.loadSettings();

      _marketNameController.text = settingsProvider.marketName ?? '';
      // جلب بيانات المدير
      final admins = await authProvider.getUsersByRole('admin');
      if (admins.isNotEmpty) {
        final admin = admins.first;
        _adminNameController.text = (admin['name'] ?? '').toString();
        _adminEmailController.text = (admin['email'] ?? '').toString();
        // لو عندك حقل اسم المتجر مخزن في DB أبدله هنا مثلاً admin['market_name']

        _currentPasswordAdminController.text = admin['password'] ?? '';
      } else {
        // لو ما في مدير مخزن، خليه قيم افتراضية أو فاضية حسب رغبتك
        _adminNameController.text = 'admin';
        _adminEmailController.text = 'admin@gmail.com';
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
      }

      // باقي الاعدادات المحلية
      _lowStockController.text = _lowStockThreshold.toString();

      setState(() {}); // لتحديث الواجهة بعد تحمّل البيانات
    } catch (e) {
      print('Error loading user data: $e');

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF6A3093),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 16),
        child: Column(
          children: [
            // قسم المدير
            _buildAdminSection(),
            const SizedBox(height: 20),

            // قسم الكاشير
            _buildCashierSection(),
            const SizedBox(height: 20),

            // قسم معلومات التواصل
            _buildContactSection(),
            const SizedBox(height: 20),

            _buildTaxSettingsSection(),
            const SizedBox(height: 20),
            // قسم إعدادات المخزون
            _buildStockSettingsSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان قسم المدير
            _buildSectionHeader(
              title: 'حساب المدير',
              icon: Icons.admin_panel_settings,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),

            // حقل اسم المدير
            _buildTextField(
              controller: _adminNameController,
              label: 'اسم المدير',
              icon: Icons.person_outline,
              enabled: _isEditingAdmin,
            ),
            const SizedBox(height: 16),

            // حقل إيميل المدير
            _buildTextField(
              controller: _adminEmailController,
              label: 'بريد المدير الإلكتروني',
              icon: Icons.email_outlined,
              enabled: _isEditingAdmin,
            ),
            const SizedBox(height: 16),

            // حقل اسم السوبر ماركت (فقط في قسم المدير)
            _buildTextField(
              controller: _marketNameController,
              label: 'اسم المتجر / السوبر ماركت',
              icon: Icons.storefront_outlined,
              enabled: _isEditingAdmin,
            ),
            const SizedBox(height: 20),

            // أزرار التحكم للمدير
            if (!_isEditingAdmin) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      text: 'تعديل بيانات المدير',
                      icon: Icons.edit,
                      color: Colors.orange,
                      onPressed: () {
                        setState(() {
                          _isEditingAdmin = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      text: 'تغيير كلمة المرور',
                      icon: Icons.lock_outline,
                      color: const Color(0xFF6A3093),
                      onPressed: () {
                        setState(() {
                          _isChangingPassword = true;
                          _isAdminPassword = true;
                        });
                        _showChangePasswordDialog();
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      text: 'حفظ التعديلات',
                      icon: Icons.check,
                      color: Colors.green,
                      onPressed: _saveAdminChanges,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      text: 'إلغاء',
                      icon: Icons.close,
                      color: Colors.red,
                      onPressed: () {
                        setState(() {
                          _isEditingAdmin = false;
                          _loadUserData(); // إعادة تحميل البيانات الأصلية
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCashierSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان قسم الكاشير
            _buildSectionHeader(
              title: 'حساب الكاشير',
              icon: Icons.person,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),

            // حقل اسم الكاشير
            _buildTextField(
              controller: _cashierNameController,
              label: 'اسم الكاشير',
              icon: Icons.person_outline,
              enabled: _isEditingCashier,
            ),
            const SizedBox(height: 16),

            // حقل إيميل الكاشير
            _buildTextField(
              controller: _cashierEmailController,
              label: 'بريد الكاشير الإلكتروني',
              icon: Icons.email_outlined,
              enabled: _isEditingCashier,
            ),
            const SizedBox(height: 20),

            // أزرار التحكم للكاشير
            if (!_isEditingCashier) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      text: 'تعديل بيانات الكاشير',
                      icon: Icons.edit,
                      color: Colors.blue,
                      onPressed: () {
                        setState(() {
                          _isEditingCashier = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      text: 'تغيير كلمة المرور',
                      icon: Icons.lock_outline,
                      color: const Color(0xFF6A3093),
                      onPressed: () {
                        setState(() {
                          _isChangingPassword = true;
                          _isAdminPassword = false;
                        });
                        _showChangePasswordDialog();
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      text: 'حفظ التعديلات',
                      icon: Icons.check,
                      color: Colors.green,
                      onPressed: _saveCashierChanges,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      text: 'إلغاء',
                      icon: Icons.close,
                      color: Colors.red,
                      onPressed: () {
                        setState(() {
                          _isEditingCashier = false;
                          _loadUserData(); // إعادة تحميل البيانات الأصلية
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم
            _buildSectionHeader(
              title: 'معلومات التواصل',
              icon: Icons.contact_support,
              color: const Color(0xFF6A3093),
            ),
            const SizedBox(height: 20),

            // معلومات المطور
            ...[
              _buildContactInfo(
                icon: Icons.person,
                title: 'اسم المطور',
                value: AppConstants.developerName,
              ),
              _buildContactInfo(
                icon: Icons.email,
                title: 'البريد الإلكتروني',
                value: AppConstants.developerEmail,
              ),
              _buildContactInfo(
                icon: Icons.phone,
                title: 'رقم الهاتف',
                value: AppConstants.developerPhone,
              ),
            ],

            const SizedBox(height: 10),

            // ملاحظة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5FBF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5FBF).withOpacity(0.2),
                ),
              ),
              child: const Text(
                'للاستفسارات والدعم الفني، لا تتردد في التواصل معنا',
                style: TextStyle(fontSize: 12, color: Color(0xFF6A3093)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockSettingsSection() {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    return FutureBuilder(
      future: settingsProvider.loadSettings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // بعد تحميل القيمة من قاعدة البيانات
        int _lowStockThreshold = settingsProvider.lowStockThreshold;
        if (_lowStockThreshold < 1) _lowStockThreshold = 1;
        if (_lowStockThreshold > 50) _lowStockThreshold = 50;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  title: 'إعدادات المخزون',
                  icon: Icons.inventory_2,
                  color: const Color(0xFF4A1C6D),
                ),
                const SizedBox(height: 20),
                const Text(
                  'حدد الحد الأدنى لكمية المنتج التي تعتبر منخفضة:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5FBF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'الحد الحالي: $_lowStockThreshold قطعة',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A3093),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _lowStockThreshold.toDouble(),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: _lowStockThreshold.toString(),
                  activeColor: const Color(0xFF8B5FBF),
                  inactiveColor: const Color(0xFF8B5FBF).withOpacity(0.3),
                  onChanged: (value) {
                    settingsProvider.updateLowStockThreshold(value.round());
                  },
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1', style: TextStyle(color: Colors.grey)),
                    Text('25', style: TextStyle(color: Colors.grey)),
                    Text('50', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  text: 'حفظ إعدادات المخزون',
                  icon: Icons.save,
                  color: const Color(0xFF4A1C6D),
                  onPressed: () async {
                    await settingsProvider.updateLowStockThreshold(
                      _lowStockThreshold,
                    );
                    _saveStockSettings(_lowStockThreshold);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: isPassword,
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
      ),
    );
  }

  Widget _buildContactInfo({
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
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF6A3093)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // قسم إعدادات الضريبة
  Widget _buildTaxSettingsSection() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        // طباعة القيمة الحالية للمساعدة في التصحيح

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان
              Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'الإعدادات الضريبية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // إعداد الضريبة الافتراضي
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الضريبة الافتراضية للمبيعات',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تحدد إذا كانت الضريبة مضمنة تلقائياً في الفواتير الجديدة',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'غير مضمنه بالضرائب',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'مضمنه بالضرائب',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (int? newValue) {
                          // استدعاء دالة التحديث في البروفايدر
                          settingsProvider.updateDefaultTaxSetting(newValue!);
                        },
                        icon: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // متغيرات محلية لتبديل الإخفاء داخل الـ Dialog
        bool obscureCurrent = true;
        bool obscureNew = true;
        bool obscureConfirm = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.lock, color: Color(0xFF6A3093)),
                  const SizedBox(width: 8),
                  Text(
                    _isAdminPassword
                        ? 'تغيير كلمة مرور المدير'
                        : 'تغيير كلمة مرور الكاشير',
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPasswordField(
                      'كلمة المرور الحالية',
                      (_isAdminPassword
                          ? _currentPasswordAdminController
                          : _currentPasswordCashierController),
                      obscureCurrent,
                      () => setState(() => obscureCurrent = !obscureCurrent),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordField(
                      'كلمة المرور الجديدة',
                      _newPasswordController,
                      obscureNew,
                      () => setState(() => obscureNew = !obscureNew),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordField(
                      'تأكيد كلمة المرور',
                      _confirmPasswordController,
                      obscureConfirm,
                      () => setState(() => obscureConfirm = !obscureConfirm),
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
                    style: TextStyle(color: Colors.red),
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
                        : 'تغيير كلمة الكاشير',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback onToggle,
  ) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Future<void> _saveAdminChanges() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.updateUserDataByRole(
      role: 'admin',
      name: _adminNameController.text.trim(),
      email: _adminEmailController.text.trim(),
    );
    final marketName = Provider.of<SettingsProvider>(context, listen: false);

    await marketName.updateMarketName(_marketNameController.text.trim());

    setState(() {
      _isEditingAdmin = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث بيانات المدير بنجاح')),
    );
  }

  Future<void> _saveCashierChanges() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.updateUserDataByRole(
      role: 'cashier',
      name: _cashierNameController.text.trim(),
      email: _cashierEmailController.text.trim(),
    );

    setState(() {
      _isEditingCashier = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث بيانات الكاشير بنجاح')),
    );
  }

  void _saveStockSettings(int threshold) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ الحد الأدنى للمخزون: $threshold'),
        backgroundColor: const Color(0xFF6A3093),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _changePassword() async {
    var oldPassword =
        (_isAdminPassword
            ? _currentPasswordAdminController
            : _currentPasswordCashierController);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role = _isAdminPassword ? 'admin' : 'cashier';

    // التحقق من التطابق
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمات المرور غير متطابقة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // تنفيذ عملية التغيير من خلال البروفايدر
    final success = await authProvider.changePasswordByRole(
      role: role,
      oldPassword: oldPassword.text.trim(),
      newPassword: _newPasswordController.text.trim(),
    );

    // إغلاق الحوار وتنظيف الحقول
    Navigator.pop(context);
    _clearPasswordFields();

    // عرض النتيجة
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (_isAdminPassword
                  ? 'تم تغيير كلمة مرور المدير بنجاح'
                  : 'تم تغيير كلمة مرور الكاشير بنجاح')
              : 'كلمة المرور الحالية غير صحيحة أو حدث خطأ أثناء التحديث',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    _loadUserData();
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
    _currentPasswordAdminController.dispose();
    _currentPasswordCashierController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }
}
