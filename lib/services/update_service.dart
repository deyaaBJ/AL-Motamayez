import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.tagName,
    required this.assetUrl,
    required this.assetName,
    required this.releaseNotes,
  });

  final String currentVersion;
  final String latestVersion;
  final String tagName;
  final String assetUrl;
  final String assetName;
  final String releaseNotes;

  bool get hasUpdate =>
      UpdateService.compareVersions(latestVersion, currentVersion) > 0;
}

class UpdateService {
  UpdateService({http.Client? client, String? owner, String? repo})
    : _client = client ?? http.Client(),
      owner = owner ?? 'deyaaBJ',
      repo = repo ?? 'AL-Motamayez';
  final http.Client _client;
  final String owner;
  final String repo;

  bool get isConfigured => owner.isNotEmpty && repo.isNotEmpty;

  Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isWindows || !isConfigured) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final uri = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/releases/latest',
    );

    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = data['tag_name']?.toString() ?? '';
    final releaseNotes = data['body']?.toString() ?? '';
    final assets = (data['assets'] as List<dynamic>? ?? const []);
    final asset = assets
        .cast<dynamic>()
        .map((item) => item is Map<String, dynamic> ? item : null)
        .whereType<Map<String, dynamic>>()
        .where((item) {
          final name = item['name']?.toString().toLowerCase() ?? '';
          return name.endsWith('.zip');
        })
        .cast<Map<String, dynamic>?>()
        .firstWhere((item) => item != null, orElse: () => null);

    final assetUrl = asset?['browser_download_url']?.toString() ?? '';
    final assetName = asset?['name']?.toString() ?? '';
    if (tagName.isEmpty || assetUrl.isEmpty) return null;

    final latestVersion = _normalizeVersion(tagName);
    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      tagName: tagName,
      assetUrl: assetUrl,
      assetName: assetName,
      releaseNotes: releaseNotes,
    );
  }

  Future<bool> downloadAndInstall(UpdateInfo info) async {
    if (!Platform.isWindows) return false;

    final appDir = await getApplicationSupportDirectory();
    final stagingDir = Directory(p.join(appDir.path, 'update_staging'));
    final downloadFile = File(
      p.join(
        (await getTemporaryDirectory()).path,
        'motamayez_update_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );

    if (stagingDir.existsSync()) {
      await stagingDir.delete(recursive: true);
    }
    await stagingDir.create(recursive: true);

    final downloadResponse = await _client.send(
      http.Request('GET', Uri.parse(info.assetUrl)),
    );
    if (downloadResponse.statusCode != 200) return false;
    final bytes = await downloadResponse.stream.toBytes();
    await downloadFile.writeAsBytes(bytes, flush: true);

    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = p.normalize(p.join(stagingDir.path, file.name));
      if (!p.isWithin(stagingDir.path, filename)) continue;
      if (file.isFile) {
        final content = (file as ArchiveFile).content;
        final bytes =
            content is List<int>
                ? content
                : content is Uint8List
                ? content
                : <int>[];
        File(filename)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes, flush: true);
      } else {
        Directory(filename).createSync(recursive: true);
      }
    }

    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);
    final batchFile = File(
      p.join((await getTemporaryDirectory()).path, 'motamayez_update.bat'),
    );
    final dataDir = p.join(exeDir, 'data');
    final script = _buildBatchScript(
      exeDir: exeDir,
      stagingDir: stagingDir.path,
      exePath: exePath,
      dataDir: dataDir,
    );
    await batchFile.writeAsString(script, flush: true);

    await Process.start('cmd.exe', [
      '/c',
      'start',
      '',
      '/min',
      batchFile.path,
    ], mode: ProcessStartMode.detached);

    return true;
  }

  String _buildBatchScript({
    required String exeDir,
    required String stagingDir,
    required String exePath,
    required String dataDir,
  }) {
    final safeExeDir = exeDir.replaceAll('"', '""');
    final safeStagingDir = stagingDir.replaceAll('"', '""');
    final safeExePath = exePath.replaceAll('"', '""');
    final safeDataDir = dataDir.replaceAll('"', '""');
    return '''
@echo off
setlocal
set "TARGET=$safeExeDir"
set "SOURCE=$safeStagingDir"
set "APP=$safeExePath"
set "DATA=$safeDataDir"

ping 127.0.0.1 -n 3 > nul
taskkill /IM "motamayez.exe" /F > nul 2>&1

robocopy "%SOURCE%" "%TARGET%" /E /NFL /NDL /NJH /NJS /NP /R:2 /W:1 /XF *.db *.sqlite *.sqlite3 /XD data > nul
if exist "%DATA%" (
  if not exist "%TARGET%\\data" mkdir "%TARGET%\\data"
  robocopy "%DATA%" "%TARGET%\\data" /E /NFL /NDL /NJH /NJS /NP /R:2 /W:1 > nul
)

start "" "%APP%"
endlocal
''';
  }

  String _normalizeVersion(String tagName) {
    final cleaned = tagName.trim().replaceFirst(RegExp(r'^[vV]'), '');
    return cleaned.isEmpty ? '0.0.0' : cleaned;
  }

  static int compareVersions(String a, String b) {
    final left = a.split('.').map(_safeParse).toList();
    final right = b.split('.').map(_safeParse).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final lv = i < left.length ? left[i] : 0;
      final rv = i < right.length ? right[i] : 0;
      if (lv != rv) return lv.compareTo(rv);
    }
    return 0;
  }

  static int _safeParse(String value) => int.tryParse(value) ?? 0;
}
