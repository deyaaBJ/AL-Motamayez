// screens/settings/store_settings_screen.dart (المصحح)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/widgets/settings/settings_section.dart';

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
          builder:
              (context, settings, child) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildStoreInfoSection(settings),
                    const SizedBox(height: 24),
                    _buildCurrencySection(settings),
                    const SizedBox(height: 24),
                    _buildStockSection(settings),
                    const SizedBox(height: 24),
                    _buildBackupSection(settings),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildStoreInfoSection(SettingsProvider settings) {
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
              label: const Text('حفظ الاسم'),
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
        value: settings.currency ?? 'USD', // ✅ تم التصليح هنا
        items: const [
          DropdownMenuItem(value: 'USD', child: Text("🇺🇸 الدولار الأمريكي")),
          DropdownMenuItem(value: 'JOD', child: Text("🇯🇴 الدينار الأردني")),
          DropdownMenuItem(value: 'ILS', child: Text("🇮🇱 الشيكل الإسرائيلي")),
        ],
        onChanged: (v) => settings.updateCurrency(v!),
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
          Text('الحد الأدنى: ${settings.lowStockThreshold}'),
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

  Widget _buildBackupSection(SettingsProvider settings) {
    return SettingsSection(
      title: 'النسخ الاحتياطي',
      icon: Icons.backup,
      color: const Color(0xFF9C27B0),
      child: Column(
        children: [
          _buildBackupPathDisplay(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSelectBackupFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('اختيار المجلد'),
              style: _buttonStyle(),
            ),
          ),
          const SizedBox(height: 16),
          _buildDropdown<int>(
            value: settings.numberOfCopies ?? 1,
            items: List.generate(
              7,
              (i) =>
                  DropdownMenuItem(value: i + 1, child: Text('${i + 1} نسخة')),
            ),
            onChanged: (v) => settings.updateNumberOfCopies(v!),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupPathDisplay() {
    return Container(
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
            color: backupFolderPath != null ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              backupFolderPath ?? 'لم يتم تحديد مكان',
              style: TextStyle(
                color: backupFolderPath != null ? Colors.green : Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
