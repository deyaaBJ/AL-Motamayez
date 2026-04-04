import 'dart:io';

import 'package:motamayez/constant/constant.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppSupportService {
  const WhatsAppSupportService();

  String _normalizedPhone(String value) {
    return value.replaceAll(RegExp(r'[^\d]'), '');
  }

  Uri _buildPrimaryUri() {
    final phone = _normalizedPhone(AppConstants.supportWhatsAppPhone);
    final message = Uri.encodeComponent(AppConstants.supportWhatsAppMessage);
    return Uri.parse('https://wa.me/$phone?text=$message');
  }

  Uri _buildFallbackUri() {
    final phone = _normalizedPhone(AppConstants.supportWhatsAppPhone);
    final message = Uri.encodeComponent(AppConstants.supportWhatsAppMessage);
    return Uri.parse(
      'https://api.whatsapp.com/send?phone=$phone&text=$message',
    );
  }

  Future<bool> _openWithSystem(Uri uri) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('cmd', ['/c', 'start', '', '$uri']);
        return result.exitCode == 0;
      }

      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', ['$uri']);
        return result.exitCode == 0;
      }

      if (Platform.isMacOS) {
        final result = await Process.run('open', ['$uri']);
        return result.exitCode == 0;
      }
    } catch (_) {}

    return false;
  }

  Future<bool> openChat() async {
    final primaryUri = _buildPrimaryUri();
    final fallbackUri = _buildFallbackUri();

    try {
      if (await canLaunchUrl(primaryUri) &&
          await launchUrl(primaryUri, mode: LaunchMode.platformDefault)) {
        return true;
      }

      if (await canLaunchUrl(fallbackUri) &&
          await launchUrl(fallbackUri, mode: LaunchMode.platformDefault)) {
        return true;
      }

      if (await launchUrl(fallbackUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
      // ignore: empty_catches
    } on MissingPluginException {}

    if (await _openWithSystem(primaryUri)) {
      return true;
    }

    return _openWithSystem(fallbackUri);
  }
}
