import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/services/local_backup_service.dart';
import 'package:motamayez/widgets/settings/settings_section.dart';
import 'package:motamayez/widgets/settings/settings_text_field.dart';

class StoreSettingsScreen extends StatelessWidget {
  final TextEditingController marketNameController;
  final TextEditingController backupFolderController;
  final Function(String) onSaveMarketName;

  const StoreSettingsScreen({
    super.key,
    required this.marketNameController,
    required this.backupFolderController,
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
          builder:
              (context, settings, child) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildStoreInfoSection(),
                    const SizedBox(height: 24),
                    _buildCurrencySection(settings),
                    const SizedBox(height: 24),
                    _buildTaxSection(settings),
                    const SizedBox(height: 24),
                    _buildStockSection(settings),
                    const SizedBox(height: 24),
                    _buildAlertsSection(settings),
                    const SizedBox(height: 24),
                    _buildLocalBackupSection(context),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildStoreInfoSection() {
    return SettingsSection(
      title: 'معلومات المتجر',
      icon: Icons.store,
      color: const Color(0xFF9C27B0),
      child: Column(
        children: [
          TextField(
            controller: marketNameController,
            decoration: InputDecoration(
              labelText: 'اسم السوبر ماركت',
              prefixIcon: const Icon(Icons.store, color: Color(0xFF9C27B0)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onSaveMarketName(marketNameController.text),
              icon: const Icon(Icons.save),
              label: const Text(
                'حفظ الاسم',
                style: TextStyle(color: Colors.white),
              ),
              style: _buttonStyle(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySection(SettingsProvider settings) {
    return SettingsSection(
      title: 'إعدادات العملة',
      icon: Icons.currency_exchange,
      color: const Color(0xFF9C27B0),
      child: _buildDropdown<String>(
        value: settings.currency ?? 'USD',
        items: const [
          DropdownMenuItem(value: 'USD', child: Text('🇺🇸 الدولار الأمريكي')),
          DropdownMenuItem(value: 'JOD', child: Text('🇯🇴 الدينار الأردني')),
          DropdownMenuItem(value: 'ILS', child: Text('🇮🇱 الشيكل الإسرائيلي')),
        ],
        onChanged: (v) => settings.updateCurrency(v!),
      ),
    );
  }

  Widget _buildTaxSection(SettingsProvider settings) {
    return SettingsSection(
      title: 'إعدادات الضريبة',
      icon: Icons.receipt,
      color: const Color(0xFF9C27B0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المبيعات مضمونة الضريبة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                settings.defaultTaxSetting == 1
                    ? '✓ المبيعات الجديدة ستكون مضمونة الضريبة'
                    : '✗ المبيعات الجديدة ستكون غير مضمونة الضريبة',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      settings.defaultTaxSetting == 1
                          ? Colors.green
                          : Colors.orange,
                ),
              ),
            ],
          ),
          Switch(
            value: settings.defaultTaxSetting == 1,
            onChanged:
                (value) => settings.updateDefaultTaxSetting(value ? 1 : 0),
            activeThumbColor: const Color(0xFF9C27B0),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection(SettingsProvider settings) {
    return SettingsSection(
      title: 'إعدادات المخزون',
      icon: Icons.inventory_2,
      color: const Color(0xFF9C27B0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الحد الأدنى الافتراضي للمخزون: ${settings.lowStockThreshold}'),
          const SizedBox(height: 4),
          Text(
            'يُستخدم هذا الرقم إذا لم يتم تخصيص حد خاص داخل المنتج.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Slider(
            value: settings.lowStockThreshold.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            activeColor: const Color(0xFF9C27B0),
            onChanged: (v) => settings.updateLowStockThreshold(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(SettingsProvider settings) {
    return SettingsSection(
      title: 'تنبيهات الواردات',
      icon: Icons.notifications_active,
      color: const Color(0xFF9C27B0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اعتبر الواردات قريبة إذا كانت تنتهي خلال ${settings.nearExpiryAlertDays} يوم',
          ),
          const SizedBox(height: 4),
          Text(
            'هذه القيمة هي التي تعتمد عليها تنبيهات الصفحة الرئيسية.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Slider(
            value: settings.nearExpiryAlertDays.toDouble(),
            min: 1,
            max: 90,
            divisions: 89,
            activeColor: const Color(0xFF9C27B0),
            label: settings.nearExpiryAlertDays.toString(),
            onChanged: (v) => settings.updateNearExpiryAlertDays(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalBackupSection(BuildContext context) {
    return Consumer<LocalBackupService>(
      builder: (context, backup, child) {
        final isEnabled = backup.isEnabled;
        return SettingsSection(
          title: 'النسخ المحلي',
          icon: Icons.backup,
          color: const Color(0xFF9C27B0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الحالة:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEnabled
                              ? 'مفعل — سيتم إنشاء نسخ تلقائية كل ساعة'
                              : 'غير مفعل — اختر مجلدًا لتفعيل النسخ',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isEnabled
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isEnabled,
                    onChanged: (value) async {
                      if (value) {
                        final selected = backupFolderController.text.trim();
                        if (selected.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('اختر مجلد النسخ أولًا'),
                            ),
                          );
                          return;
                        }
                        await backup.setBackupFolderPath(selected);
                      } else {
                        await backup.disable();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SettingsTextField(
                controller: backupFolderController,
                label: 'مجلد النسخ المحلي',
                icon: Icons.folder_open,
                color: const Color(0xFF9C27B0),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final selected = await FilePicker.platform.getDirectoryPath(
                      dialogTitle: 'اختر مجلد النسخ الاحتياطي',
                    );
                    if (selected == null || selected.isEmpty) return;
                    backupFolderController.text = selected;
                    await backup.setBackupFolderPath(selected);
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text(
                    'اختيار مجلد',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: _buttonStyle(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final selected = backupFolderController.text.trim();
                    if (selected.isEmpty) return;
                    await backup.setBackupFolderPath(selected);
                    await backup.backupNow();
                  },
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'تشغيل نسخة الآن',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: _buttonStyle(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                backup.backupFolderPath == null ||
                        backup.backupFolderPath!.isEmpty
                    ? 'لم يتم اختيار مجلد للنسخ بعد.'
                    : 'سيتم حفظ النسخ داخل: ${backup.backupFolderPath}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم النسخ تلقائيًا كل ساعة وعند تسجيل الخروج من التطبيق.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF9C27B0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
