import 'package:flutter/material.dart';
import '../services/ws_service.dart';
import '../theme.dart';
import '../widgets/relay_card.dart';
import '../widgets/modbus_console.dart';

class DashboardScreen extends StatelessWidget {
  final WsService service;

  const DashboardScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compact mode when height is tight
        final compact = constraints.maxHeight < 680;
        final hPad = 28.0;
        final vPad = compact ? 16.0 : 24.0;
        final titleSize = compact ? 30.0 : 38.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page header ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control Matrix',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          color: kOnSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 3),
                        const Text(
                          'Manage 8-Channel Modbus Interface',
                          style: TextStyle(
                            fontSize: 14,
                            color: kOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  // ── SYS badge ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1A6BFB9A),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x4D6BFB9A)),
                    ),
                    child: Row(
                      children: [
                        _PulsingDot(isConnected: service.isConnected),
                        const SizedBox(width: 8),
                        Text(
                          service.isConnected ? 'SYS_ONLINE' : 'SYS_OFFLINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: service.isConnected ? kPrimary : kError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                compact ? 12 : 16,
                hPad,
                compact ? 12 : 16,
              ),
              child: const Divider(color: Colors.white10),
            ),

            // ── Relay grid — 4 cols, landscape/rectangular cards ──────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  // Wider than tall → rectangular
                  childAspectRatio: 1.55,
                ),
                itemCount: 8,
                itemBuilder: (context, i) => RelayCard(
                  index: i,
                  isOn: service.relayStates[i],
                  onToggle: () => service.toggleRelay(i),
                  service: service,
                ),
              ),
            ),

            SizedBox(height: compact ? 12 : 16),

            // ── Modbus console (flex 1 — takes all remaining space) ────
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, compact ? 16 : 24),
                child: ModbusConsole(service: service),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A small dot that pulses green when connected.
class _PulsingDot extends StatefulWidget {
  final bool isConnected;
  const _PulsingDot({required this.isConnected});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isConnected ? kPrimary : kError;
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
