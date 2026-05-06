import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme.dart';
import '../services/ws_service.dart';
import 'relay_toggle.dart';

const int _kMaxNameLength = 20;

class RelayCard extends StatefulWidget {
  final int index;
  final bool isOn;
  final VoidCallback onToggle;
  final WsService service;

  const RelayCard({
    super.key,
    required this.index,
    required this.isOn,
    required this.onToggle,
    required this.service,
  });

  @override
  State<RelayCard> createState() => _RelayCardState();
}

class _RelayCardState extends State<RelayCard> {
  bool _editing = false;
  late TextEditingController _ctrl;
  final FocusNode _focusNode = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        _commit();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing(String currentLabel) {
    // Pre-fill with custom name if set, else empty (placeholder shows default)
    _ctrl.text = widget.service.relayNames[widget.index];
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
    _error = null;
    setState(() => _editing = true);
    Future.microtask(() => _focusNode.requestFocus());
  }

  void _commit() {
    final raw = _ctrl.text.trim();
    if (raw.isNotEmpty && raw.length > _kMaxNameLength) {
      setState(() => _error = 'Max $_kMaxNameLength chars');
      return;
    }
    widget.service.setRelayName(widget.index, raw);
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  void _reset() {
    widget.service.setRelayName(widget.index, '');
    _ctrl.clear();
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.service.relayLabel(widget.index);
    final statusLabel = widget.isOn ? 'ACTIVE' : 'STANDBY';
    final ledColor = widget.isOn ? kPrimary : const Color(0xFFFFD700);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isOn
              ? [const Color(0x144ADE80), const Color(0x03FFFFFF)]
              : [const Color(0x0DFFFFFF), const Color(0x03FFFFFF)],
        ),
        border: Border.all(
          color: widget.isOn
              ? const Color(0x664ADE80)
              : (_editing ? kPrimary.withValues(alpha: 0.5) : Colors.white12),
          width: _editing ? 1.5 : 1,
        ),
        boxShadow: widget.isOn
            ? [
                BoxShadow(
                  color: kPrimary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final pad = (h * 0.12).clamp(8.0, 18.0);
          final titleSize = (h * 0.18).clamp(12.0, 20.0);
          final subSize = (h * 0.10).clamp(9.0, 11.0);
          final loadSize = (h * 0.10).clamp(9.0, 13.0);
          final iconSize = (h * 0.20).clamp(14.0, 24.0);
          final ledSize = (h * 0.09).clamp(6.0, 11.0);

          return Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: label/edit + bolt icon ──────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Name row ────────────────────────────────
                          if (_editing)
                            _NameField(
                              ctrl: _ctrl,
                              focusNode: _focusNode,
                              titleSize: titleSize,
                              error: _error,
                              onCommit: _commit,
                              onReset: _reset,
                              onCancel: _cancel,
                              defaultName: WsService.defaultRelayName(
                                widget.index,
                              ),
                            )
                          else
                            GestureDetector(
                              onDoubleTap: () => _startEditing(label),
                              child: Tooltip(
                                message: 'Double-click to rename',
                                waitDuration: const Duration(milliseconds: 800),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'SpaceGrotesk',
                                    color: kOnSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          SizedBox(height: (h * 0.03).clamp(2.0, 5.0)),
                          // ── status + LED ────────────────────────────
                          Row(
                            children: [
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: subSize,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: widget.isOn
                                      ? kPrimary
                                      : const Color(0xFFFFD700),
                                ),
                              ),
                              SizedBox(width: ledSize * 0.7),
                              _Led(color: ledColor, size: ledSize * 0.85),
                            ],
                          ),
                        ],
                      ),
                    ),
                    FaIcon(
                      FontAwesomeIcons.bolt,
                      color: widget.isOn
                          ? const Color(0xFFFFD700)
                          : kOnSurfaceVariant,
                      size: iconSize,
                    ),
                  ],
                ),
                const Spacer(),
                // ── Bottom row: load + toggle ─────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Load: 0.0A',
                      style: TextStyle(
                        fontSize: loadSize,
                        color: widget.isOn
                            ? kOnSurfaceVariant
                            : kOnSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    RelayToggle(
                      value: widget.isOn,
                      onTap: widget.onToggle,
                      scale: (h / 130.0).clamp(0.55, 1.0),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Inline name editor ─────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final double titleSize;
  final String? error;
  final VoidCallback onCommit;
  final VoidCallback onReset;
  final VoidCallback onCancel;
  final String defaultName;

  const _NameField({
    required this.ctrl,
    required this.focusNode,
    required this.titleSize,
    required this.error,
    required this.onCommit,
    required this.onReset,
    required this.onCancel,
    required this.defaultName,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (e) {
        if (e is KeyDownEvent) {
          if (e.logicalKey == LogicalKeyboardKey.enter) onCommit();
          if (e.logicalKey == LogicalKeyboardKey.escape) onCancel();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: titleSize + 10,
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              maxLength: _kMaxNameLength,
              style: TextStyle(
                fontSize: titleSize * 0.9,
                fontWeight: FontWeight.w600,
                fontFamily: 'SpaceGrotesk',
                color: kOnSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: defaultName,
                hintStyle: TextStyle(
                  color: kOnSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: titleSize * 0.9,
                  fontFamily: 'SpaceGrotesk',
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: kPrimary.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: kPrimary, width: 1.5),
                ),
                // Reset-to-default button inside field
                suffixIcon: Tooltip(
                  message: 'Reset to default',
                  child: InkWell(
                    onTap: onReset,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.restart_alt_rounded,
                        size: titleSize * 0.85,
                        color: kOnSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(_kMaxNameLength),
                // Disallow leading spaces
                FilteringTextInputFormatter.deny(RegExp(r'^\s')),
              ],
              onSubmitted: (_) => onCommit(),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }
}

/// Glowing LED dot.
class _Led extends StatelessWidget {
  final Color color;
  final double size;

  const _Led({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.85),
            blurRadius: size * 1.6,
            spreadRadius: size * 0.3,
          ),
        ],
      ),
    );
  }
}
