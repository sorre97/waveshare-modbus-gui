import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../services/ws_service.dart';
import '../theme.dart';
import '../widgets/update_modal.dart';

class SettingsScreen extends StatefulWidget {
  final WsService service;
  final UpdateService updateService;

  const SettingsScreen({
    super.key,
    required this.service,
    required this.updateService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipCtrl;
  late TextEditingController _portCtrl;

  // Modbus fields (stored locally, cosmetic for now)
  final TextEditingController _slaveCtrl = TextEditingController(text: '1');
  final TextEditingController _timeoutCtrl = TextEditingController(
    text: '1000',
  );
  final TextEditingController _retriesCtrl = TextEditingController(text: '3');
  String _baudRate = '19200';

  // User preferences
  bool _darkTheme = true;
  bool _notifications = true;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: widget.service.ip);
    _portCtrl = TextEditingController(text: widget.service.port);
    widget.updateService.addListener(_onUpdateChanged);
  }

  void _onUpdateChanged() => setState(() {});

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _slaveCtrl.dispose();
    _timeoutCtrl.dispose();
    _retriesCtrl.dispose();
    widget.updateService.removeListener(_onUpdateChanged);
    super.dispose();
  }

  void _save() {
    widget.service.saveSettings(_ipCtrl.text.trim(), _portCtrl.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuration saved — reconnecting to hub...'),
        backgroundColor: Color(0xFF1A3A28),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() => _testingConnection = true);
    final ok = await widget.service.testConnection(
      _ipCtrl.text.trim(),
      _portCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _testingConnection = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Connection successful — hub is reachable.'
              : 'Connection failed — check IP/port and ensure backend is running.',
        ),
        backgroundColor: ok ? const Color(0xFF1A3A28) : const Color(0xFF3A1A1A),
      ),
    );
  }

  void _discard() {
    _ipCtrl.text = widget.service.ip;
    _portCtrl.text = widget.service.port;
    _slaveCtrl.text = '1';
    _timeoutCtrl.text = '1000';
    _retriesCtrl.text = '3';
    setState(() {
      _baudRate = '19200';
      _darkTheme = true;
      _notifications = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page header ──────────────────────────────────────────────
          const Text(
            'System Settings',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: kOnSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Configure core network parameters, Modbus communication, and user preferences.',
            style: TextStyle(fontSize: 15, color: kOnSurfaceVariant),
          ),
          const SizedBox(height: 32),
          // ── Two-column layout ─────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: Network Config ──────────────────────────────────
              Expanded(
                child: _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardHeader(
                        icon: Icons.router_outlined,
                        title: 'Network Configuration',
                      ),
                      const SizedBox(height: 20),
                      _FieldLabel('HUB IP ADDRESS'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _ipCtrl,
                        style: const TextStyle(
                          color: kOnSurface,
                          fontFamily: 'SpaceGrotesk',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel('TCP PORT'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _portCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: kOnSurface,
                                fontFamily: 'SpaceGrotesk',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _OutlineButton(
                            label: _testingConnection
                                ? 'Testing...'
                                : 'Test Connection',
                            onPressed: _testingConnection
                                ? () {}
                                : _testConnection,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // ── Right: Modbus + Preferences ───────────────────────────
              Expanded(
                child: Column(
                  children: [
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CardHeader(
                            icon: Icons.memory_outlined,
                            title: 'Modbus Settings',
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _FieldLabel('SLAVE ID'),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _slaveCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        color: kOnSurface,
                                        fontFamily: 'SpaceGrotesk',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _FieldLabel('BAUD RATE'),
                                    const SizedBox(height: 6),
                                    _StyledDropdown(
                                      value: _baudRate,
                                      items: [
                                        '9600',
                                        '19200',
                                        '38400',
                                        '115200',
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _baudRate = v!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _FieldLabel('TIMEOUT (MS)'),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _timeoutCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        color: kOnSurface,
                                        fontFamily: 'SpaceGrotesk',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _FieldLabel('MAX RETRIES'),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _retriesCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        color: kOnSurface,
                                        fontFamily: 'SpaceGrotesk',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CardHeader(
                            icon: Icons.tune_outlined,
                            title: 'User Preferences',
                          ),
                          const SizedBox(height: 16),
                          _PrefToggle(
                            title: 'Dark Theme Enforcement',
                            subtitle:
                                'Lock interface to cyber-organic dark mode',
                            value: _darkTheme,
                            onChanged: (v) => setState(() => _darkTheme = v),
                          ),
                          const Divider(color: Colors.white10, height: 24),
                          _PrefToggle(
                            title: 'System Notifications',
                            subtitle: 'Alerts for node disconnections',
                            value: _notifications,
                            onChanged: (v) =>
                                setState(() => _notifications = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // ── Software Updates ──────────────────────────────────────────
          _SoftwareUpdateCard(updateService: widget.updateService),
          const SizedBox(height: 32),
          // ── Action bar ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _OutlineButton(label: 'Discard Changes', onPressed: _discard),
              const SizedBox(width: 12),
              _SaveButton(onPressed: _save),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x0DFFFFFF), Color(0x03FFFFFF)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _CardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kSurfaceVariant,
          ),
          child: Icon(icon, color: kPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: kOnSurface,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: kOnSurfaceVariant,
      ),
    );
  }
}

class _StyledDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: kSurfaceContainerHighest,
        style: const TextStyle(
          color: kOnSurface,
          fontFamily: 'SpaceGrotesk',
          fontSize: 15,
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _PrefToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kOnSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: kOnSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 32,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: value ? const Color(0x334ADE80) : kSurfaceVariant,
              border: Border.all(
                color: value ? const Color(0x664ADE80) : Colors.white10,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? kPrimary : kOutline,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _OutlineButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: kOnSurface,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SaveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.save_outlined, size: 18),
      label: const Text(
        'Save Configuration',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: const Color(0xFF003919),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 0,
      ),
    );
  }
}

// ── Software Update Card ──────────────────────────────────────────────────────

class _SoftwareUpdateCard extends StatelessWidget {
  final UpdateService updateService;
  const _SoftwareUpdateCard({required this.updateService});

  @override
  Widget build(BuildContext context) {
    final svc = updateService;
    final status = svc.status;

    final bool isAvailable = status == UpdateStatus.available;
    final bool isReady = status == UpdateStatus.readyToRestart;
    final bool isDownloading = status == UpdateStatus.downloading;
    final bool isChecking = status == UpdateStatus.checking;

    String statusText;
    Color statusColor = kOnSurfaceVariant;

    switch (status) {
      case UpdateStatus.upToDate:
        statusText = 'Up to date';
        statusColor = kPrimary;
      case UpdateStatus.available:
        statusText = 'v${svc.updateInfo?.version ?? ''} available';
        statusColor = kPrimary;
      case UpdateStatus.downloading:
        statusText = 'Downloading... ${(svc.downloadProgress * 100).toInt()}%';
      case UpdateStatus.readyToRestart:
        statusText = 'Ready to install — restart to apply';
        statusColor = kPrimary;
      case UpdateStatus.checking:
        statusText = 'Checking...';
      case UpdateStatus.error:
        statusText = 'Check failed';
        statusColor = kError;
      case UpdateStatus.idle:
        statusText = '—';
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.cloud_upload_rounded,
            title: 'Software Updates',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Version info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('INSTALLED VERSION'),
                    const SizedBox(height: 6),
                    Text(
                      svc.currentVersion.isEmpty ? '—' : svc.currentVersion,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kOnSurface,
                        fontFamily: 'SpaceGrotesk',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('STATUS'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isChecking || isDownloading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: kPrimary,
                            ),
                          )
                        else
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            color: statusColor,
                            fontWeight: (isAvailable || isReady)
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action button
              const SizedBox(width: 24),
              if (isReady)
                ElevatedButton.icon(
                  onPressed: svc.applyAndRestart,
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text(
                    'Restart Now',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: const Color(0xFF003919),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    elevation: 0,
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: isDownloading || isChecking
                      ? null
                      : () => showUpdateModal(context, svc),
                  icon: Icon(
                    Icons.cloud_upload_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isAvailable ? 'Install Update' : 'Check for Updates',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isAvailable ? kPrimary : kOnSurface,
                    side: BorderSide(
                      color: isAvailable ? kNeonGlowBorder : Colors.white24,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                ),
            ],
          ),
          // Download progress bar (visible only while downloading)
          if (isDownloading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: svc.downloadProgress,
                minHeight: 4,
                backgroundColor: kSurfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
