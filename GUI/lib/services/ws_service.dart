import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

class ConsoleEntry {
  final String time;
  final String kind; // TX, RX, INFO, ERROR
  final String hex;
  final String description;

  ConsoleEntry({
    required this.time,
    required this.kind,
    required this.hex,
    required this.description,
  });

  factory ConsoleEntry.fromJson(Map<String, dynamic> json) => ConsoleEntry(
    time: json['time'] ?? '',
    kind: json['kind'] ?? '',
    hex: json['hex'] ?? '',
    description: json['description'] ?? '',
  );
}

class WsService extends ChangeNotifier {
  String ip = '127.0.0.1';
  String port = '8192';

  WebSocketChannel? _channel;
  bool isConnected = false;
  List<bool> relayStates = List.generate(8, (_) => false);
  final List<ConsoleEntry> consoleLogs = [];
  // pending[index] = expected state after optimistic update
  final Map<int, bool> _pendingToggles = {};

  // Relay custom names (index → name); empty string = use default
  List<String> relayNames = List.generate(8, (_) => '');

  static String defaultRelayName(int index) =>
      'Relay ${(index + 1).toString().padLeft(2, '0')}';

  String relayLabel(int index) {
    final n = relayNames[index].trim();
    return n.isEmpty ? defaultRelayName(index) : n;
  }

  WsService() {
    _loadAndConnect();
  }

  Future<void> _loadAndConnect() async {
    final prefs = await SharedPreferences.getInstance();
    ip = prefs.getString('hub_ip') ?? '127.0.0.1';
    // hub_port_v2 key avoids collisions with previously cached '8000'
    port = prefs.getString('hub_port_v2') ?? '8192';
    for (int i = 0; i < 8; i++) {
      relayNames[i] = prefs.getString('relay_name_$i') ?? '';
    }
    notifyListeners();
    connect();
  }

  Future<void> setRelayName(int index, String name) async {
    relayNames[index] = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('relay_name_$index', relayNames[index]);
    notifyListeners();
  }

  Future<void> saveSettings(String newIp, String newPort) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hub_ip', newIp);
    await prefs.setString('hub_port_v2', newPort);
    ip = newIp;
    port = newPort;
    notifyListeners();
    connect();
  }

  void connect() {
    _channel?.sink.close();
    isConnected = false;
    notifyListeners();
    try {
      final wsUrl = Uri.parse('ws://$ip:$port/ws');
      _channel = WebSocketChannel.connect(wsUrl);
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message as String);
          if (data['type'] == 'state') {
            final incoming = List<bool>.from(data['data'] as List);
            // Check for mismatches with pending optimistic updates
            _pendingToggles.forEach((idx, expected) {
              if (incoming[idx] != expected) {
                // Server disagrees — will be corrected by incoming state
              }
            });
            _pendingToggles.clear();
            relayStates = incoming;
            if (!isConnected) {
              isConnected = true;
            }
          } else if (data['type'] == 'log') {
            final entry = ConsoleEntry.fromJson(
              data['entry'] as Map<String, dynamic>,
            );
            // On ERROR, revert any pending optimistic toggles
            if (entry.kind == 'ERROR' && _pendingToggles.isNotEmpty) {
              _pendingToggles.forEach((idx, expected) {
                relayStates[idx] = !expected; // revert
              });
              _pendingToggles.clear();
            }
            consoleLogs.insert(0, entry);
            if (consoleLogs.length > 200) consoleLogs.removeLast();
          }
          notifyListeners();
        },
        onDone: () {
          isConnected = false;
          notifyListeners();
          Future.delayed(const Duration(seconds: 5), connect);
        },
        onError: (_) {
          isConnected = false;
          notifyListeners();
          Future.delayed(const Duration(seconds: 5), connect);
        },
      );
    } catch (_) {
      isConnected = false;
      notifyListeners();
    }
  }

  void toggleRelay(int index) {
    if (!isConnected) return;
    final newState = !relayStates[index];
    _channel!.sink.add(
      jsonEncode({
        'command': 'write',
        'relay': index,
        'value': newState ? 'on' : 'off',
      }),
    );
    relayStates[index] = newState; // optimistic update
    _pendingToggles[index] = newState; // track for potential revert
    notifyListeners();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  /// Non-destructive ping: opens a temporary WS to [testIp]:[testPort],
  /// waits for the first 'state' message, then closes it.
  /// Returns true on success, false on failure.
  Future<bool> testConnection(String testIp, String testPort) async {
    try {
      final wsUrl = Uri.parse('ws://$testIp:$testPort/ws');
      final ch = WebSocketChannel.connect(wsUrl);
      final completer = Completer<bool>();
      late StreamSubscription sub;
      sub = ch.stream.listen(
        (message) {
          final data = jsonDecode(message as String);
          if (data['type'] == 'state' && !completer.isCompleted) {
            completer.complete(true);
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
      );
      final result = await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
      sub.cancel();
      ch.sink.close(ws_status.goingAway);
      return result;
    } catch (_) {
      return false;
    }
  }
}
