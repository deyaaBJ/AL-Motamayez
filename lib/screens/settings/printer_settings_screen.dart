// screens/settings/printer_settings_screen.dart (المصحح)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motamayez/providers/settings_provider.dart';
import 'package:motamayez/widgets/settings/settings_detail_card.dart';

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
    // ✅ الـ context متوفر هنا
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
          builder:
              (context, settings, child) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SettingsDetailCard(
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildIPField(),
                      const SizedBox(height: 20),
                      _buildPortField(),
                      const SizedBox(height: 20),
                      _buildPaperSizeDropdown(settings),
                      const SizedBox(height: 32),
                      _buildSaveButton(
                        context,
                        settings,
                      ), // ✅ تمرير الـ context
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF009688), Color(0xFF26A69A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.print, size: 50, color: Colors.white),
    );
  }

  Widget _buildIPField() {
    return TextField(
      controller: ipController,
      decoration: InputDecoration(
        labelText: 'عنوان IP للطابعة',
        prefixIcon: const Icon(Icons.network_wifi, color: Color(0xFF009688)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPortField() {
    return TextField(
      controller: portController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'منفذ الطابعة (مثال: 9100)',
        prefixIcon: const Icon(Icons.usb, color: Color(0xFF009688)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPaperSizeDropdown(SettingsProvider settings) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: settings.paperSize,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          items: const [
            DropdownMenuItem(value: '58mm', child: Text('58mm (فاتورة صغيرة)')),
            DropdownMenuItem(value: '80mm', child: Text('80mm (فاتورة كبيرة)')),
          ],
          onChanged: (v) => settings.updatePaperSize(v!),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, SettingsProvider settings) {
    // ✅ إضافة BuildContext
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _saveSettings(context, settings),
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
    );
  }

  void _saveSettings(BuildContext context, SettingsProvider settings) {
    // ✅ إضافة BuildContext
    final ip = ipController.text.trim();
    final portText = portController.text.trim();

    if (ip.isEmpty || portText.isEmpty) {
      _showError(context, 'الرجاء إدخال جميع البيانات');
      return;
    }

    final port = int.tryParse(portText);
    if (port == null) {
      _showError(context, 'رقم المنفذ غير صحيح');
      return;
    }

    settings.updatePrinterSettings(
      ip: ip,
      port: port,
      size: settings.paperSize ?? '58mm',
    );

    _showSuccess(context, 'تم حفظ الإعدادات بنجاح');
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}
