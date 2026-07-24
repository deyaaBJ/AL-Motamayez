import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ActivationApiClient {
  ActivationApiClient({required http.Client client, required String baseUrl})
    : _client = client,
      _baseUrl = baseUrl;

  final http.Client _client;
  final String _baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> createActivationRequest({
    required String deviceId,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/activate/request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'deviceId': deviceId}),
        )
        .timeout(_requestTimeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> getRequestStatus({
    required String requestId,
    required String deviceId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/activate/request/$requestId',
    ).replace(queryParameters: {'deviceId': deviceId});
    final response = await _client
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(_requestTimeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> getDeviceActivationStatus({
    required String deviceId,
    required String deviceFingerprint,
  }) async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/activate/device/status').replace(
            queryParameters: {
              'deviceId': deviceId,
            },
          ),
          headers: {
            'Content-Type': 'application/json',
            if (deviceFingerprint.isNotEmpty) 'X-Device-Fingerprint': deviceFingerprint,
          },
        )
        .timeout(_requestTimeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> activate({
    required String activationCode,
    required String deviceId,
    required String deviceFingerprint,
    required String requestId,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/activate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requestId': requestId,
            'code': activationCode,
            'deviceId': deviceId,
            'deviceFingerprint': deviceFingerprint,
          }),
        )
        .timeout(_requestTimeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> validateLicense({
    required String licenseToken,
    required String deviceId,
    required String deviceFingerprint,
    required String clientTime,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/activate/license/validate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'licenseToken': licenseToken,
            'deviceId': deviceId,
            'deviceFingerprint': deviceFingerprint,
            'clientTime': clientTime,
          }),
        )
        .timeout(_requestTimeout);
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return {
        'statusCode': response.statusCode,
        'body': <String, dynamic>{
          'success': false,
          'message': 'Server returned a non-JSON response.',
        },
      };
    }

    return {
      'statusCode': response.statusCode,
      'body': decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
    };
  }

  static bool isConnectivityError(Object error) {
    return error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException;
  }
}
