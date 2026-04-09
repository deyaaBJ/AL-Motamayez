import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:motamayez/constant/constant.dart';
import 'package:motamayez/db/db_helper.dart';
import 'package:motamayez/services/encryption_service.dart';

class ActivationException implements Exception {
  final String message;
  final String? storedSignature;
  final String? expectedSignature;

  ActivationException(
    this.message, {
    this.storedSignature,
    this.expectedSignature,
  });

  @override
  String toString() => message;
}

class ActivationService {
  ActivationService({http.Client? client}) : _client = client ?? http.Client();

  final DBHelper _dbHelper = DBHelper();
  final http.Client _client;

  static const String _secretKey = AppConstants.secretKey;
  static const String _requestIdKey = 'activation_request_id';
  static const String _requestStatusKey = 'activation_request_status';
  static const String _requestCodeKey = 'activation_request_code';

  static final String _activationBaseUrl = AppConstants.activationBaseUrl;

  String? _maskValue(String? value) {
    if (value == null || value.isEmpty) return value;
    if (value.length <= 8) return '***';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }

  String _networkErrorMessage(String action) {
    return 'تعذر $action بسبب مشكلة في الاتصال. يرجى التحقق من الإنترنت والمحاولة مرة أخرى.';
  }

  Future<String> _getOrCreateFallbackDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId != null && deviceId.isNotEmpty) {
      return deviceId;
    }

    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
    return deviceId;
  }

  String? _normalizeHardwareValue(String? value) {
    if (value == null) return null;

    final normalized =
        value.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();

    if (normalized.isEmpty) return null;
    if (normalized == 'TO BE FILLED BY O.E.M.') return null;
    if (normalized == 'DEFAULT STRING') return null;
    if (normalized == 'SYSTEM SERIAL NUMBER') return null;

    return normalized;
  }

  Future<String?> _runPowerShellValue(String command) async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        command,
      ]);

      if (result.exitCode != 0) {
        return null;
      }

      final output = result.stdout?.toString();
      return _normalizeHardwareValue(output);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getWindowsDeviceFingerlog() async {
    final values = await Future.wait([
      _runPowerShellValue(
        r"(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography').MachineGuid",
      ),
      _runPowerShellValue(
        r"(Get-CimInstance Win32_BIOS).SerialNumber",
      ),
      _runPowerShellValue(
        r"(Get-CimInstance Win32_BaseBoard).SerialNumber",
      ),
    ]);

    final machineGuid = values[0];
    final biosSerial = values[1];
    final boardSerial = values[2];

    final parts =
        [
          machineGuid,
          biosSerial,
          boardSerial,
        ].whereType<String>().where((value) => value.isNotEmpty).toList();

    if (parts.isEmpty) {
      return null;
    }

    final rawFingerlog = parts.join('|');
    return sha256.convert(utf8.encode(rawFingerlog)).toString();
  }

  Future<String> getDeviceId() async {
    if (Platform.isWindows) {
      final fingerlog = await _getWindowsDeviceFingerlog();
      if (fingerlog != null && fingerlog.isNotEmpty) {
        return fingerlog;
      }
    }

    return _getOrCreateFallbackDeviceId();
  }

  String _generateSignature(String deviceId) {
    final raw = '$deviceId|$_secretKey';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<void> _ensureActivationTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activation (
        id INTEGER PRIMARY KEY,
        signature TEXT,
        activation_code TEXT
      )
    ''');
  }

  Future<void> _saveSignature(String signature) async {
    final encrypted = EncryptionService.encrypt(signature);
    final db = await _dbHelper.db;
    await _ensureActivationTable(db);
    await db.delete('activation');
    await db.insert('activation', {
      'id': 1,
      'signature': encrypted,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activation_signature', encrypted);
  }

  Future<void> _saveActivationCode(String code) async {
    final db = await _dbHelper.db;
    await _ensureActivationTable(db);
    await db.update('activation', {'activation_code': code}, where: 'id = 1');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activation_code', code);
  }

  Future<String?> _getStoredSignature() async {
    try {
      final db = await _dbHelper.db;
      await _ensureActivationTable(db);

      final result = await db.query('activation', limit: 1);
      if (result.isNotEmpty) {
        final encrypted = result.first['signature'] as String?;
        if (encrypted == null || encrypted.isEmpty) return null;
        return EncryptionService.decrypt(encrypted);
      }

      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('activation_signature');
      if (encrypted == null || encrypted.isEmpty) return null;

      await db.insert('activation', {
        'id': 1,
        'signature': encrypted,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return EncryptionService.decrypt(encrypted);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getStoredActivationCode() async {
    try {
      final db = await _dbHelper.db;
      await _ensureActivationTable(db);
      final result = await db.query('activation', limit: 1);
      if (result.isNotEmpty && result.first.containsKey('activation_code')) {
        return result.first['activation_code'] as String?;
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('activation_code');
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePendingRequest({
    required String requestId,
    required String status,
    String? assignedCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_requestIdKey, requestId);
    await prefs.setString(_requestStatusKey, status);

    if (assignedCode != null && assignedCode.isNotEmpty) {
      await prefs.setString(_requestCodeKey, assignedCode);
    } else {
      await prefs.remove(_requestCodeKey);
    }
  }

  Future<void> clearPendingRequest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestIdKey);
    await prefs.remove(_requestStatusKey);
    await prefs.remove(_requestCodeKey);
  }

  Future<Map<String, dynamic>?> getSavedPendingRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final requestId = prefs.getString(_requestIdKey);

    if (requestId == null || requestId.isEmpty) {
      return null;
    }

    return {
      'requestId': requestId,
      'status': prefs.getString(_requestStatusKey) ?? 'pending',
      'assignedCode': prefs.getString(_requestCodeKey),
    };
  }

  Future<void> _completeLocalActivation(String activationCode) async {
    final deviceId = await getDeviceId();
    final signature = _generateSignature(deviceId);
    await _saveSignature(signature);
    await _saveActivationCode(activationCode);
    await clearPendingRequest();
  }

  Future<Map<String, dynamic>> createActivationRequest() async {
    try {
      final deviceId = await getDeviceId();
      final response = await _client
          .post(
            Uri.parse('$_activationBaseUrl/request'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'deviceId': deviceId}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 && response.statusCode != 201) {
        return {
          'success': false,
          'message': data['message']?.toString() ?? 'فشل إرسال طلب التفعيل',
        };
      }

      if (data['status'] == 'already_activated') {
        final activation = data['activation'] as Map<String, dynamic>?;
        final code = activation?['code']?.toString();

        return {
          'success': true,
          'status': 'already_activated',
          'message': data['message']?.toString() ?? 'هذا الجهاز مفعّل مسبقًا',
          'assignedCode': code,
          'alreadyActivated': true,
        };
      }

      final request = data['request'] as Map<String, dynamic>?;
      final requestId = request?['id']?.toString();
      final status = request?['status']?.toString() ?? 'pending';
      final assignedCode = request?['assignedCode']?.toString();

      if (requestId == null || requestId.isEmpty) {
        return {
          'success': false,
          'message': 'لم يتم استلام رقم الطلب من الخادم',
        };
      }

      await _savePendingRequest(
        requestId: requestId,
        status: status,
        assignedCode: assignedCode,
      );

      return {
        'success': true,
        'status': status,
        'requestId': requestId,
        'assignedCode': assignedCode,
        'message': data['message']?.toString() ?? 'تم إرسال طلب التفعيل',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'تعذر إرسال طلب التفعيل بسبب انتهاء مهلة الاتصال. يرجى التحقق من الإنترنت والمحاولة مرة أخرى.',
      };
    } on SocketException {
      return {
        'success': false,
        'message': _networkErrorMessage('إرسال طلب التفعيل'),
      };
    } on http.ClientException {
      return {
        'success': false,
        'message': _networkErrorMessage('إرسال طلب التفعيل'),
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'تعذر إرسال طلب التفعيل حاليًا. يرجى المحاولة مرة أخرى.',
      };
    }
  }

  Future<Map<String, dynamic>> getRequestStatus({String? requestId}) async {
    try {
      final savedRequest = await getSavedPendingRequest();
      final effectiveRequestId =
          requestId ?? savedRequest?['requestId']?.toString();

      if (effectiveRequestId == null || effectiveRequestId.isEmpty) {
        return {'success': false, 'message': 'لا يوجد طلب تفعيل محفوظ'};
      }

      final deviceId = await getDeviceId();
      final uri = Uri.parse(
        '$_activationBaseUrl/request/$effectiveRequestId',
      ).replace(queryParameters: {'deviceId': deviceId});

      final response = await _client
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': data['message']?.toString() ?? 'فشل التحقق من حالة الطلب',
        };
      }

      final request = data['request'] as Map<String, dynamic>?;
      final status = request?['status']?.toString() ?? 'pending';
      final assignedCode = request?['assignedCode']?.toString();

      if (status == 'rejected') {
        await clearPendingRequest();
      } else {
        await _savePendingRequest(
          requestId: effectiveRequestId,
          status: status,
          assignedCode: assignedCode,
        );
      }

      return {
        'success': true,
        'requestId': effectiveRequestId,
        'status': status,
        'assignedCode': assignedCode,
        'rejectionReason': request?['rejectionReason']?.toString(),
        'message': data['message']?.toString(),
      };
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'تعذر التحقق من حالة الطلب بسبب انتهاء مهلة الاتصال. يرجى التحقق من الإنترنت والمحاولة مرة أخرى.',
      };
    } on SocketException {
      return {
        'success': false,
        'message': _networkErrorMessage('التحقق من حالة الطلب'),
      };
    } on http.ClientException {
      return {
        'success': false,
        'message': _networkErrorMessage('التحقق من حالة الطلب'),
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'تعذر التحقق من حالة الطلب حاليًا. يرجى المحاولة مرة أخرى.',
      };
    }
  }

  Future<Map<String, dynamic>> activateWithRequest({
    required String activationCode,
    String? requestId,
  }) async {
    try {
      final savedRequest = await getSavedPendingRequest();
      final effectiveRequestId =
          requestId ?? savedRequest?['requestId']?.toString();

      if (effectiveRequestId == null || effectiveRequestId.isEmpty) {
        return {
          'success': false,
          'message': 'أرسل طلب التفعيل أولًا قبل إدخال الكود',
        };
      }

      final deviceId = await getDeviceId();
      final response = await _client
          .post(
            Uri.parse(_activationBaseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'requestId': effectiveRequestId,
              'code': activationCode,
              'deviceId': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        return {
          'success': false,
          'message': data['message']?.toString() ?? 'فشل التفعيل',
        };
      }

      await _completeLocalActivation(activationCode);
      return {
        'success': true,
        'message': data['message']?.toString() ?? 'تم التفعيل بنجاح',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'تعذر تنفيذ التفعيل بسبب انتهاء مهلة الاتصال. يرجى التحقق من الإنترنت والمحاولة مرة أخرى.',
      };
    } on SocketException {
      return {
        'success': false,
        'message': _networkErrorMessage('تنفيذ التفعيل'),
      };
    } on http.ClientException {
      return {
        'success': false,
        'message': _networkErrorMessage('تنفيذ التفعيل'),
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'تعذر تنفيذ التفعيل حاليًا. يرجى المحاولة مرة أخرى.',
      };
    }
  }

  Future<bool> activate(String activationCode) async {
    final result = await activateWithRequest(activationCode: activationCode);
    return result['success'] == true;
  }

  Future<bool> isActivated() async {
    final storedSignature = await _getStoredSignature();
    if (storedSignature == null) {
      return false;
    }

    final deviceId = await getDeviceId();
    final expectedSignature = _generateSignature(deviceId);

    if (storedSignature != expectedSignature) {
      throw ActivationException(
        'Activation signature mismatch.',
        storedSignature: _maskValue(storedSignature),
        expectedSignature: _maskValue(expectedSignature),
      );
    }

    return true;
  }

  Future<bool> checkActivationSilently() async {
    try {
      final storedSignature = await _getStoredSignature();
      if (storedSignature == null) return false;
      final deviceId = await getDeviceId();
      return storedSignature == _generateSignature(deviceId);
    } catch (_) {
      return false;
    }
  }

  Future<void> clearActivation() async {
    try {
      final db = await _dbHelper.db;
      await _ensureActivationTable(db);
      await db.delete('activation');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('activation_signature');
      await prefs.remove('activation_code');
      await prefs.remove('device_id');
      await clearPendingRequest();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getActivationInfo() async {
    try {
      final storedSignature = await _getStoredSignature();
      final storedCode = await getStoredActivationCode();

      final hasActivation = storedSignature != null && storedCode != null;

      if (!hasActivation) {
        return {'has_activation': false, 'status': 'not_activated'};
      }

      try {
        final isValid = await isActivated();

        if (isValid) {
          return {
            'has_activation': true,
            'status': 'valid',
            'activation_code': storedCode,
            'signature': storedSignature,
          };
        } else {
          return {
            'has_activation': true,
            'status': 'invalid',
            'activation_code': storedCode,
            'signature': storedSignature,
          };
        }
      } on ActivationException catch (e) {
        return {
          'has_activation': true,
          'status': 'invalid',
          'activation_code': storedCode,
          'signature': storedSignature,
          'stored_signature': e.storedSignature,
          'expected_signature': e.expectedSignature,
        };
      }
    } catch (e) {
      return {
        'has_activation': false,
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  Future<void> checkDatabase() async {
    final db = await _dbHelper.db;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    for (final table in tables) {
      final tableName = table['name'];
      if (tableName == null) continue;
      try {
        await db.rawQuery("SELECT COUNT(*) as count FROM $tableName");
      } catch (_) {}
    }
  }
}
