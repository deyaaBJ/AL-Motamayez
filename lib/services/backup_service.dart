import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'dart:developer';
import '../db/db_helper.dart';

/// خدمة النسخ الاحتياطي - تعمل في نفس الـ thread
class BackupService {
  final DBHelper _dbHelper;

  BackupService(this._dbHelper);

  /// إنشاء نسخة احتياطية (بدون Isolate)
  Future<void> createBackup({
    required String backupDirPath,
    required int maxBackups,
    required String userIdentifier,
  }) async {
    try {
      await _createBackupInternal(
        backupDirPath: backupDirPath,
        maxBackups: maxBackups,
        userIdentifier: userIdentifier,
      );

      log('✅ Backup completed successfully');
    } catch (e) {
      log('❌ Backup failed: $e');
      // لا نرمي الخطأ حتى لا نعطل تسجيل الخروج
    }
  }

  /// الدالة الداخلية للنسخ الاحتياطي
  Future<void> _createBackupInternal({
    required String backupDirPath,
    required int maxBackups,
    required String userIdentifier,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // ✅ نجلب الـ DB path مباشرة
      final db = await _dbHelper.db;
      final dbPath = db.path;

      final sourceFile = File(dbPath);
      if (!sourceFile.existsSync()) {
        throw Exception('Database file not found: $dbPath');
      }

      // إنشاء مجلد النسخ
      final backupDir = Directory(backupDirPath);
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      // اسم النسخة مع معرف المستخدم
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');

      final backupName = 'motamayez_${userIdentifier}_$timestamp';
      final tempDbPath = p.join(backupDir.path, '$backupName.db');
      final zipPath = p.join(backupDir.path, '$backupName.zip');

      log('📁 Creating backup: $backupName');
      log('📂 Source: $dbPath');
      log('📂 Target: $zipPath');

      // نسخ الملف
      await sourceFile.copy(tempDbPath);
      log('✅ Database copied');

      // ضغط
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      encoder.addFile(File(tempDbPath));
      encoder.close();
      log('✅ Database compressed');

      // حذف الملف المؤقت
      await File(tempDbPath).delete();
      log('✅ Temp file deleted');

      // تنظيف النسخ القديمة
      await _cleanupOldBackups(backupDir, maxBackups, userIdentifier);

      log('⏱️ Backup time: ${stopwatch.elapsedMilliseconds}ms');
      log('📦 Backup created: $zipPath');
    } catch (e, stackTrace) {
      log('❌ Backup error: $e');
      log('Stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> _cleanupOldBackups(
    Directory backupDir,
    int maxBackups,
    String userIdentifier,
  ) async {
    final backups =
        backupDir
            .listSync()
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.zip') &&
                  p.basename(f.path).contains('motamayez_${userIdentifier}_'),
            )
            .toList()
          ..sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
          );

    while (backups.length > maxBackups) {
      final oldest = backups.removeAt(0);
      await oldest.delete();
      log('🗑 Deleted old backup: ${p.basename(oldest.path)}');
    }
  }

  /// الحصول على قائمة النسخ الاحتياطية
  Future<List<FileSystemEntity>> getBackups(String backupDirPath) async {
    final dir = Directory(backupDirPath);
    if (!dir.existsSync()) return [];

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }
}
