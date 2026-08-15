import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:motamayez/db/db_helper.dart';

class LocalBackupService with ChangeNotifier {
  static const String _prefEnabled = 'local_backup_enabled';
  static const String _prefFolderPath = 'local_backup_folder_path';

  Timer? _timer;
  bool _isRunning = false;
  bool _initialized = false;

  bool _enabled = false;
  String? _backupFolderPath;

  bool get isEnabled =>
      _enabled && (_backupFolderPath?.trim().isNotEmpty ?? false);
  String? get backupFolderPath => _backupFolderPath;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefEnabled) ?? false;
    _backupFolderPath = prefs.getString(_prefFolderPath);
    _initialized = true;
    _startTimer();
    notifyListeners();
  }

  Future<void> refresh() async {
    _initialized = false;
    await init();
  }

  Future<void> setBackupFolderPath(String path) async {
    final cleanPath = path.trim();
    final prefs = await SharedPreferences.getInstance();
    _backupFolderPath = cleanPath;
    _enabled = cleanPath.isNotEmpty;
    await prefs.setString(_prefFolderPath, cleanPath);
    await prefs.setBool(_prefEnabled, _enabled);
    _startTimer();
    notifyListeners();
  }

  Future<void> enable() async {
    if ((_backupFolderPath?.trim().isEmpty ?? true)) {
      throw Exception('Please choose a backup folder first.');
    }
    final prefs = await SharedPreferences.getInstance();
    _enabled = true;
    await prefs.setBool(_prefEnabled, true);
    _startTimer();
    notifyListeners();
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = false;
    await prefs.setBool(_prefEnabled, false);
    _stopTimer();
    notifyListeners();
  }

  Future<void> backupNow() async {
    if (!isEnabled || _isRunning) return;
    _isRunning = true;

    File? sourceDbFile;
    File? zipFile;
    Directory? workingDir;

    try {
      final backupRoot = _backupFolderPath;
      if (backupRoot == null || backupRoot.trim().isEmpty) {
        _logLocal('Backup skipped: no destination folder selected.');
        return;
      }

      sourceDbFile = await _resolveSourceDatabaseFile();
      if (sourceDbFile == null || !await sourceDbFile.exists()) {
        _logLocal('Backup skipped: source database file not found.');
        return;
      }

      final dbHelper = DBHelper();
      await dbHelper.close();
      _logLocal('Database connection closed before backup copy.');

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');

      workingDir = Directory(
        p.join(Directory.systemTemp.path, 'local_backup_$timestamp'),
      );
      if (!await workingDir.exists()) {
        await workingDir.create(recursive: true);
      }

      final tempDbPath = p.join(workingDir.path, 'backup_copy.db');
      await sourceDbFile.copy(tempDbPath);
      final copiedDbFile = File(tempDbPath);
      _logLocal('Database copied to temp: ${copiedDbFile.path}');

      if (!await copiedDbFile.exists() || await copiedDbFile.length() <= 0) {
        throw Exception(
          'Copied DB file is missing or empty: ${copiedDbFile.path}',
        );
      }

      final backupFolder = Directory(backupRoot);
      if (!await backupFolder.exists()) {
        await backupFolder.create(recursive: true);
      }

      final dbBackupName = 'motamayez_backup_$timestamp.db';
      final zipName = 'motamayez_backup_$timestamp.zip';

      final destinationDb = File(p.join(backupFolder.path, dbBackupName));
      await sourceDbFile.copy(destinationDb.path);
      if (!await destinationDb.exists() || await destinationDb.length() <= 0) {
        throw Exception(
          'Destination DB backup is missing or empty: ${destinationDb.path}',
        );
      }

      zipFile = File(p.join(workingDir.path, zipName));
      final copiedBytes = await copiedDbFile.readAsBytes();
      final archive =
          Archive()..addFile(
            ArchiveFile(
              p.basename(copiedDbFile.path),
              copiedBytes.length,
              copiedBytes,
            ),
          );
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes.isEmpty) {
        throw Exception(
          'Failed to encode ZIP archive for: ${copiedDbFile.path}',
        );
      }
      await zipFile.writeAsBytes(zipBytes, flush: true);

      if (!await zipFile.exists() || await zipFile.length() <= 0) {
        throw Exception('ZIP file is missing or empty: ${zipFile.path}');
      }

      final destinationZip = File(p.join(backupFolder.path, zipName));
      await zipFile.copy(destinationZip.path);
      final destinationFile = File(destinationZip.path);
      if (!await destinationFile.exists() ||
          await destinationFile.length() <= 0) {
        throw Exception(
          'Destination ZIP file is missing or empty: ${destinationFile.path}',
        );
      }
      _logLocal(
        'Backup saved locally: ${destinationDb.path} and ${destinationFile.path}',
      );
    } catch (e, st) {
      _logLocal('Local backup failed: $e');
      _logLocal('StackTrace: $st');
    } finally {
      try {
        final tempDb = File(p.join(workingDir?.path ?? '', 'backup_copy.db'));
        if (await tempDb.exists()) {
          await tempDb.delete();
        }
      } catch (e) {
        _logLocal('Cleanup failed for temp DB: $e');
      }
      try {
        if (zipFile != null && await zipFile.exists()) {
          await zipFile.delete();
        }
      } catch (e) {
        _logLocal('Cleanup failed for temp ZIP: $e');
      }
      try {
        if (workingDir != null && await workingDir.exists()) {
          await workingDir.delete(recursive: true);
        }
      } catch (e) {
        _logLocal('Cleanup failed for working directory: $e');
      }
      try {
        final dbHelper = DBHelper();
        await dbHelper.db;
      } catch (e) {
        _logLocal('Reopen database after backup failed: $e');
      }
      _isRunning = false;
    }
  }

  Future<void> startOrRunEvery30Minutes() async {
    await init();
    _startTimer();
  }

  Future<File?> _resolveSourceDatabaseFile() async {
    try {
      final dbHelper = DBHelper();
      final dbPath = await dbHelper.getDatabasePath();
      final file = File(dbPath);
      if (await file.exists()) {
        _logLocal('Resolved database from DBHelper path: ${file.path}');
        return file;
      }
    } catch (e) {
      _logLocal('Unable to resolve database path from DBHelper: $e');
    }

    try {
      final supportDir = await getApplicationSupportDirectory();
      final fallbackDb = File(p.join(supportDir.path, 'data', 'motamayez.db'));
      if (await fallbackDb.exists()) {
        _logLocal('Resolved database from fallback path: ${fallbackDb.path}');
        return fallbackDb;
      }
    } catch (e) {
      _logLocal('Unable to resolve application support fallback: $e');
    }

    return null;
  }

  void _startTimer() {
    _timer?.cancel();
    if (!isEnabled) return;
    _timer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(backupNow());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _logLocal(String message) {
    debugPrint('[LocalBackupService] $message');
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
