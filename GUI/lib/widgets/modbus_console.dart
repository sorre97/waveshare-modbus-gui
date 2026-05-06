import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ws_service.dart';
import '../theme.dart';

class ModbusConsole extends StatefulWidget {
  final WsService service;

  const ModbusConsole({super.key, required this.service});

  @override
  State<ModbusConsole> createState() => _ModbusConsoleState();
}

class _ModbusConsoleState extends State<ModbusConsole> {
  Color _kindColor(String kind) {
    switch (kind) {
      case 'TX':
        return const Color(0xFF64B5F6); // light blue
      case 'RX':
        return kSecondary;
      case 'INFO':
        return kPrimary;
      case 'ERROR':
        return kError;
      default:
        return kOnSurfaceVariant;
    }
  }

  /// Backend sends full ISO timestamp; extract HH:MM:SS.mmm for live display.
  String _displayTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      final ms = (dt.millisecond).toString().padLeft(3, '0');
      return '$h:$m:$s.$ms';
    } catch (_) {
      return raw; // fallback: show as-is
    }
  }

  Future<void> _exportLog() async {
    final logs = widget.service.consoleLogs;
    if (logs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No log entries to export.'),
            backgroundColor: Color(0xFF2A2A2A),
          ),
        );
      }
      return;
    }

    final buf = StringBuffer();
    for (final e in logs.reversed) {
      final hex = e.hex.isNotEmpty ? '  ${e.hex}' : '';
      final desc = e.description.isNotEmpty ? '  (${e.description})' : '';
      buf.writeln('[${e.time}] ${e.kind}$hex$desc');
    }

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    final suggestedName = 'relayctrl_log_$ts.log';

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Modbus Log',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: ['log'],
    );

    if (path == null) return; // user cancelled

    await File(path).writeAsString(buf.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log exported to $path'),
          backgroundColor: const Color(0xFF1A3A28),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.service.consoleLogs;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x0DFFFFFF), Color(0x03FFFFFF)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: kPrimary, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'LIVE MODBUS CONSOLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: kOnSurface,
                  ),
                ),
                const Spacer(),
                // Three dots → Save As dialog
                GestureDetector(
                  onTap: _exportLog,
                  child: Tooltip(
                    message: 'Export log…',
                    child: Row(
                      children: [
                        _dot(kError.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        _dot(kSecondary.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        _dot(kPrimary.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Log entries (fills remaining height) ──────
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Waiting for Modbus activity...',
                      style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    itemBuilder: (context, i) {
                      final entry = logs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[${_displayTime(entry.time)}]',
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'SpaceGrotesk',
                                color: kPrimary.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'SpaceGrotesk',
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${entry.kind}: ',
                                      style: TextStyle(
                                        color: _kindColor(entry.kind),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (entry.hex.isNotEmpty)
                                      TextSpan(
                                        text: entry.hex,
                                        style: TextStyle(
                                          color: _kindColor(entry.kind),
                                        ),
                                      ),
                                    if (entry.description.isNotEmpty)
                                      TextSpan(
                                        text: entry.hex.isNotEmpty
                                            ? '  (${entry.description})'
                                            : entry.description,
                                        style: const TextStyle(
                                          color: kOnSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
