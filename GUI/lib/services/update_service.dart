import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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
    // Strip build metadata suffix (e.g. "0.1.24+24" → "0.1.24")
    _currentVersion = info.version.split('+').first;
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
      // Stage everything next to the running exe — never in %TEMP% which
      // can be wiped by cleaners between download and apply.
      final installDir = File(Platform.resolvedExecutable).parent.path;
      final stagingDir = Directory(
          '$installDir${Platform.pathSeparator}_update_staging');

      // Clean any leftover staging dir from a previous failed attempt
      if (stagingDir.existsSync()) stagingDir.deleteSync(recursive: true);
      stagingDir.createSync(recursive: true);

      final fileName = info.downloadUrl.split('/').last;
      final destFile = File(
          '${stagingDir.path}${Platform.pathSeparator}$fileName');

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
        await _stageWindows(destFile, stagingDir);
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

  Future<void> _stageWindows(File zipFile, Directory stagingDir) async {
    // Extract zip into _update_staging\extracted\
    final extractDir = Directory(
        '${stagingDir.path}${Platform.pathSeparator}extracted');
    if (extractDir.existsSync()) extractDir.deleteSync(recursive: true);
    extractDir.createSync();

    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final outPath =
          '${extractDir.path}${Platform.pathSeparator}${file.name}';
      if (file.isFile) {
        final outFile = File(outPath);
        outFile.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }
    // _stagedPath points to the extracted content dir
    // (top-level folder inside the zip, or extractDir itself if flat)
    final topLevel = extractDir
        .listSync()
        .whereType<Directory>()
        .firstOrNull;
    _stagedPath = topLevel?.path ?? extractDir.path;
  }

  void _applyWindows() {
    final sourceDir = _stagedPath;
    if (sourceDir == null) return;

    final exePath = Platform.resolvedExecutable;
    final installDir = File(exePath).parent.path;
    // The whole staging folder (parent of extracted\) to delete after copy
    final stagingDir =
        '${installDir}${Platform.pathSeparator}_update_staging';
    final batPath =
        '${installDir}${Platform.pathSeparator}_update.bat';

    // Robocopy exits 0-7 for various success states (0=nothing to do,
    // 1=files copied, etc.). Only 8+ are real errors.
    // After copy: delete the staging folder, relaunch, self-delete bat.
    final bat = '@echo off\r\n'
        'timeout /t 3 /nobreak >NUL\r\n'
        'robocopy "$sourceDir" "$installDir" /E /IS /IT /NFL /NDL /NJH /NJS\r\n'
        'if %errorlevel% leq 7 (\r\n'
        '  rmdir /s /q "$stagingDir"\r\n'
        '  start "" "$exePath"\r\n'
        ')\r\n'
        '(goto) 2>NUL & del "%~f0"\r\n';

    File(batPath).writeAsStringSync(bat);

    // Flutter is a GUI subsystem process (no console).
    // cmd.exe /c silently fails from a consoleless parent.
    // Solution: PowerShell -EncodedCommand (base64 UTF-16LE) sidesteps
    // ALL quoting/space issues and works from any process type.
    final psCommand = 'Start-Process -FilePath cmd.exe -ArgumentList @(\'/c\',\'$batPath\') -WindowStyle Hidden';
    // Encode as UTF-16LE bytes then base64 (what PowerShell -EncodedCommand expects)
    final utf16Bytes = <int>[];
    for (final codeUnit in psCommand.codeUnits) {
      utf16Bytes.add(codeUnit & 0xFF);
      utf16Bytes.add((codeUnit >> 8) & 0xFF);
    }
    final encoded = base64Encode(utf16Bytes);

    Process.start(
      'powershell.exe',
      ['-WindowStyle', 'Hidden', '-NonInteractive', '-EncodedCommand', encoded],
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
    // Strip build metadata (e.g. "0.1.24+24" → "0.1.24") and leading "v"
    final clean = v.split('+').first.replaceFirst(RegExp(r'^v'), '');
    final parts = clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
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
