import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class UpdateInfo {
  final String tagName;      // e.g. "v0.1.42"
  final String version;      // e.g. "0.1.42"
  final String downloadUrl;  // direct asset URL
  final String body;         // release notes

  const UpdateInfo({
    required this.tagName,
    required this.version,
    required this.downloadUrl,
    required this.body,
  });
}

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  readyToRestart,
  upToDate,
  error,
}

// ── Service ───────────────────────────────────────────────────────────────────

class UpdateService extends ChangeNotifier {
  static const String _repoOwner = 'sorre97';
  static const String _repoName = 'waveshare-modbus-gui';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  UpdateStatus _status = UpdateStatus.idle;
  UpdateInfo? _updateInfo;
  double _downloadProgress = 0.0; // 0.0 – 1.0
  String _errorMessage = '';
  String _currentVersion = '';

  // Path of the staged update file (AppImage on Linux, extracted dir on Windows)
  String? _stagedPath;

  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  double get downloadProgress => _downloadProgress;
  String get errorMessage => _errorMessage;
  String get currentVersion => _currentVersion;

  // True once a download is staged and the app can be restarted to apply it
  bool get isReadyToRestart => _status == UpdateStatus.readyToRestart;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final info = await PackageInfo.fromPlatform();
    _currentVersion = info.version; // "0.1.N" baked in at build time
  }

  Future<void> checkForUpdate() async {
    if (_status == UpdateStatus.checking ||
        _status == UpdateStatus.downloading) {
      return;
    }
    _set(UpdateStatus.checking);

    try {
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _setError('GitHub API returned ${response.statusCode}');
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final body = json['body'] as String? ?? '';
      // tag is "v0.1.N" → version is "0.1.N"
      final version =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;

      if (!_isNewer(version, _currentVersion)) {
        _set(UpdateStatus.upToDate);
        return;
      }

      // Find the right asset for this platform
      final assets = (json['assets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final assetName = _platformAssetName();
      final asset = assets.firstWhere(
        (a) => (a['name'] as String).contains(assetName),
        orElse: () => {},
      );

      if (asset.isEmpty) {
        _setError('No asset found for this platform ($assetName)');
        return;
      }

      _updateInfo = UpdateInfo(
        tagName: tagName,
        version: version,
        downloadUrl: asset['browser_download_url'] as String,
        body: body,
      );
      _set(UpdateStatus.available);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> downloadUpdate() async {
    final info = _updateInfo;
    if (info == null) return;
    if (_status == UpdateStatus.downloading) return;

    _downloadProgress = 0.0;
    _set(UpdateStatus.downloading);

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = info.downloadUrl.split('/').last;
      final destFile = File('${tempDir.path}${Platform.pathSeparator}$fileName');

      // Streaming download with progress
      final request = http.Request('GET', Uri.parse(info.downloadUrl));
      final response = await request.send();
      final total = response.contentLength ?? 0;
      var received = 0;

      final sink = destFile.openWrite();
      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _downloadProgress = received / total;
          notifyListeners();
        }
      }).asFuture<void>();
      await sink.close();

      _downloadProgress = 1.0;
      notifyListeners();

      // Platform-specific staging
      if (Platform.isWindows) {
        await _stageWindows(destFile, tempDir);
      } else if (Platform.isLinux) {
        await _stageLinux(destFile);
      }

      _set(UpdateStatus.readyToRestart);
    } catch (e) {
      _setError('Download failed: $e');
    }
  }

  /// Restart and apply the staged update.
  void applyAndRestart() {
    if (_status != UpdateStatus.readyToRestart) return;

    if (Platform.isWindows) {
      _applyWindows();
    } else if (Platform.isLinux) {
      _applyLinux();
    }
  }

  // ── Windows ────────────────────────────────────────────────────────────────

  Future<void> _stageWindows(File zipFile, Directory tempDir) async {
    // Extract zip into a temp staging dir
    final stagingDir =
        Directory('${tempDir.path}${Platform.pathSeparator}relayctrl_update');
    if (stagingDir.existsSync()) stagingDir.deleteSync(recursive: true);
    stagingDir.createSync();

    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final outPath =
          '${stagingDir.path}${Platform.pathSeparator}${file.name}';
      if (file.isFile) {
        final outFile = File(outPath);
        outFile.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }
    _stagedPath = stagingDir.path;
  }

  void _applyWindows() {
    final staged = _stagedPath;
    if (staged == null) return;

    // The exe path: e.g. C:\...\RelayCtrlPro-Windows-x64-Portable\RelayCtrlPro.exe
    final exePath = Platform.resolvedExecutable;
    final installDir = File(exePath).parent.path;
    final exeName = File(exePath).uri.pathSegments.last;

    // Write a .bat that:
    //  1. Waits for this process to exit
    //  2. Robocopy staged dir over install dir
    //  3. Restarts the app
    final batPath =
        '${File(exePath).parent.path}${Platform.pathSeparator}_update.bat';

    // The zip contains a top-level folder (RelayCtrlPro-Windows-x64-Portable\)
    // Find the first directory inside staged
    final stagedDir = Directory(staged);
    final topLevel = stagedDir
        .listSync()
        .whereType<Directory>()
        .firstOrNull;
    final sourceDir = topLevel?.path ?? staged;

    final bat = '''@echo off
:: Wait for the app to exit
:wait
tasklist /FI "IMAGENAME eq $exeName" 2>NUL | find /I "$exeName" >NUL
if not errorlevel 1 (
  timeout /t 1 /nobreak >NUL
  goto wait
)
:: Copy new files over install dir
robocopy "$sourceDir" "$installDir" /E /IS /IT /NFL /NDL /NJH /NJS >NUL
:: Relaunch
start "" "$exePath"
:: Self-delete
del "%~f0"
''';

    File(batPath).writeAsStringSync(bat);
    Process.start(
      'cmd.exe',
      ['/c', 'start', '', '/min', batPath],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  // ── Linux ──────────────────────────────────────────────────────────────────

  Future<void> _stageLinux(File appImageFile) async {
    // Make executable and store path; we'll replace on restart
    final currentExe = Platform.resolvedExecutable;
    final backupPath = '$currentExe.bak';

    // chmod +x the downloaded AppImage
    await Process.run('chmod', ['+x', appImageFile.path]);

    _stagedPath = appImageFile.path;

    // Keep backup of current
    try {
      await File(currentExe).copy(backupPath);
    } catch (_) {}
  }

  void _applyLinux() {
    final staged = _stagedPath;
    if (staged == null) return;

    final currentExe = Platform.resolvedExecutable;

    // Replace current AppImage and relaunch
    try {
      File(staged).copySync(currentExe);
      Process.run('chmod', ['+x', currentExe]);
    } catch (e) {
      _setError('Failed to replace AppImage: $e');
      return;
    }

    Process.start(
      currentExe,
      [],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _platformAssetName() {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return '';
  }

  /// Returns true if [remote] is strictly newer than [local].
  /// Compares as "major.minor.patch" numeric tuples.
  bool _isNewer(String remote, String local) {
    final r = _parseVersion(remote);
    final l = _parseVersion(local);
    for (var i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  List<int> _parseVersion(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  void _set(UpdateStatus s) {
    _status = s;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _status = UpdateStatus.error;
    notifyListeners();
  }
}
