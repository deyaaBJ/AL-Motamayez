import 'dart:io';
import 'dart:convert';

class AppConfig {
  final String configFilePath;

  AppConfig({required this.configFilePath});

  /// قراءة مسار النسخ الاحتياطي
  Future<String> getBackupFolderPath() async {
    final file = File(configFilePath);
    if (!file.existsSync()) {
      // إنشاء ملف افتراضي إذا لم يكن موجود
      await file.writeAsString(
        jsonEncode({"backup_folder_path": "H:/My Drive/ShopMate_Backups"}),
      );
    }
    final content = await file.readAsString();
    final jsonData = jsonDecode(content);
    return jsonData['backup_folder_path'] ?? "H:/My Drive/ShopMate_Backups";
  }

  /// تحديث المسار الجديد
  Future<void> setBackupFolderPath(String newPath) async {
    final file = File(configFilePath);
    final jsonData = {"backup_folder_path": newPath};
    await file.writeAsString(jsonEncode(jsonData));
  }
}
