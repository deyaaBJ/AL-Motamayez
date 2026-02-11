// screens/settings/cashiers_management_screen.dart (المصحح)
import 'dart:developer' show log;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/auth_provider.dart';
import 'package:motamayez/helpers/helpers.dart';
import 'package:motamayez/widgets/settings/settings_detail_card.dart';
import 'package:motamayez/widgets/settings/settings_text_field.dart';
import 'package:motamayez/widgets/settings/settings_password_field.dart';

class CashiersManagementScreen extends StatefulWidget {
  const CashiersManagementScreen({super.key});

  @override
  State<CashiersManagementScreen> createState() =>
      _CashiersManagementScreenState();
}

class _CashiersManagementScreenState extends State<CashiersManagementScreen> {
  List<Map<String, dynamic>> _cashiers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCashiers();
  }

  Future<void> _loadCashiers() async {
    setState(() => _isLoading = true); // ✅ إظهار التحميل
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final data = await auth.getUsersByRole('cashier');
      log('تم جلب ${data.length} كاشير'); // ✅ للتأكد
      setState(() {
        _cashiers = data;
        _isLoading = false;
      });
    } catch (e) {
      log('خطأ في جلب الكاشيرز: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'إضافة كاشير جديد',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        labelText: 'اسم الكاشير *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني *',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      enabled: !isLoading,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور *',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // ✅ زر فحص القاعدة
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.red),
                  ),
                ),

                ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            if (nameController.text.trim().isEmpty ||
                                emailController.text.trim().isEmpty ||
                                passwordController.text.isEmpty) {
                              showAppToast(
                                context,
                                'الرجاء ملء جميع الحقول',
                                ToastType.error,
                              );
                              return;
                            }

                            setDialogState(() => isLoading = true);

                            final auth = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );

                            print('');
                            print('═' * 60);
                            print('🚀 بدء إضافة كاشير جديد');
                            print('═' * 60);

                            final success = await auth.createUser(
                              role: 'cashier',
                              name: nameController.text.trim(),
                              email: emailController.text.trim(),
                              password: passwordController.text,
                            );

                            print('═' * 60);
                            print(
                              '🏁 النتيجة النهائية: ${success ? "نجاح" : "فشل"}',
                            );
                            print('═' * 60);

                            if (!dialogContext.mounted) return;

                            setDialogState(() => isLoading = false);

                            if (success) {
                              Navigator.pop(dialogContext);
                              showAppToast(
                                context,
                                'تم الإضافة بنجاح',
                                ToastType.success,
                              );
                              await _loadCashiers();
                            } else {
                              showAppToast(
                                context,
                                'فشل: الإيميل موجود أو خطأ - شاهد الـ Console',
                                ToastType.error,
                              );
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'إضافة',
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToCashierDetail(Map<String, dynamic> cashier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CashierDetailScreen(
              cashier: cashier,
              onSave: _loadCashiers, // ✅ إعادة التحميل بعد الحفظ
            ),
      ),
    );
  }

  void _deleteCashier(Map<String, dynamic> cashier) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'تأكيد الحذف',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text('هل أنت متأكد من حذف "${cashier['name']}"؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final success = await auth.deleteUser(
                    cashier['id'].toString(),
                  );

                  if (success && mounted) {
                    Navigator.pop(context);
                    showAppToast(context, 'تم الحذف بنجاح', ToastType.success);
                    await _loadCashiers(); // ✅ إعادة التحميل
                  } else if (mounted) {
                    showAppToast(context, 'فشل الحذف', ToastType.error);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف', style: TextStyle(color: Colors.white)),
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
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          backgroundColor: const Color(0xFF4A90E2),
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة كاشير'),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  // ✅ سحب للتحديث
                  onRefresh: _loadCashiers,
                  child:
                      _cashiers.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _cashiers.length,
                            itemBuilder:
                                (context, index) =>
                                    _buildCashierCard(_cashiers[index]),
                          ),
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
            onPressed: _showAddDialog,
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
    return GestureDetector(
      onTap: () => _navigateToCashierDetail(cashier),
      child: Container(
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
          leading: _buildAvatar(),
          title: Text(
            cashier['name'] ?? 'غير معروف',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Text(
            cashier['email'] ?? '',
            style: TextStyle(color: Colors.grey[600]),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteCashier(cashier),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF5BA0F2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 30),
    );
  }
}

// ==================== شاشة تفاصيل الكاشير ====================
class CashierDetailScreen extends StatefulWidget {
  final Map<String, dynamic> cashier;
  final VoidCallback onSave;

  const CashierDetailScreen({
    super.key,
    required this.cashier,
    required this.onSave,
  });

  @override
  State<CashierDetailScreen> createState() => _CashierDetailScreenState();
}

class _CashierDetailScreenState extends State<CashierDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.cashier['name']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.cashier['email']?.toString() ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.cashier['password']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      showAppToast(context, 'الرجاء ملء جميع الحقول', ToastType.error);
      return;
    }

    setState(() => _isSaving = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);

    final success = await auth.updateUserDataByRole(
      userId: widget.cashier['id'].toString(),
      role: 'cashier',
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      setState(() => _isEditing = false);
      widget.onSave(); // ✅ إعادة تحميل القائمة السابقة
      showAppToast(context, 'تم التحديث بنجاح', ToastType.success);
    } else if (mounted) {
      showAppToast(context, 'فشل التحديث', ToastType.error);
    }
  }

  void _showChangePassword() {
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock, color: Color(0xFF6A3093)),
                SizedBox(width: 8),
                Text(
                  'تغيير كلمة المرور',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    border: OutlineInputBorder(),
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
                  if (newPassController.text != confirmPassController.text) {
                    showAppToast(
                      context,
                      'كلمات المرور غير متطابقة',
                      ToastType.error,
                    );
                    return;
                  }

                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );

                  final success = await auth.changePasswordByRole(
                    userId: widget.cashier['id'].toString(),
                    role: 'cashier',
                    newPassword: newPassController.text,
                  );

                  if (success && mounted) {
                    Navigator.pop(context);
                    showAppToast(
                      context,
                      'تم تغيير كلمة المرور',
                      ToastType.success,
                    );
                  } else if (mounted) {
                    showAppToast(context, 'فشل التغيير', ToastType.error);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A3093),
                ),
                child: const Text(
                  'تغيير',
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
            'تفاصيل الكاشير',
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
                    colors: [Color(0xFF4A90E2), Color(0xFF5BA0F2)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 32),
              SettingsDetailCard(
                child: Column(
                  children: [
                    SettingsTextField(
                      controller: _nameController,
                      label: 'اسم الكاشير',
                      icon: Icons.person_outline,
                      enabled: _isEditing,
                      color: const Color(0xFF4A90E2),
                    ),
                    const SizedBox(height: 20),
                    SettingsTextField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                      enabled: _isEditing,
                      color: const Color(0xFF4A90E2),
                    ),
                    const SizedBox(height: 20),
                    SettingsPasswordField(
                      controller: _passwordController,
                      label: 'كلمة المرور الحالية',
                      enabled: false,
                      color: const Color(0xFF4A90E2),
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
                        onPressed: _isSaving ? null : _saveChanges,
                        icon:
                            _isSaving
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.check),
                        label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ'),
                        style: _buttonStyle(Colors.green),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isSaving
                                ? null
                                : () => setState(() => _isEditing = false),
                        icon: const Icon(Icons.close),
                        label: const Text('إلغاء'),
                        style: _buttonStyle(Colors.red),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showChangePassword,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('تغيير كلمة المرور'),
                    style: _buttonStyle(const Color(0xFF6A3093)),
                  ),
                ),
            ],
          ),
        ),
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
}
