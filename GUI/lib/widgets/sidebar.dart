import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/update_service.dart';
import '../widgets/update_modal.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String ip;
  final bool isConnected;
  final UpdateService updateService;
  final String appVersion;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.ip,
    required this.isConnected,
    required this.updateService,
    required this.appVersion,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  bool _collapsed = false;

  static const double _expandedWidth = 280;
  static const double _collapsedWidth = 64;

  @override
  void initState() {
    super.initState();
    widget.updateService.addListener(_onUpdateChanged);
  }

  @override
  void dispose() {
    widget.updateService.removeListener(_onUpdateChanged);
    super.dispose();
  }

  void _onUpdateChanged() => setState(() {});

  void _handleUpdateTap() {
    final status = widget.updateService.status;
    if (status == UpdateStatus.readyToRestart) {
      widget.updateService.applyAndRestart();
      return;
    }
    showUpdateModal(context, widget.updateService);
  }

  @override
  Widget build(BuildContext context) {
    final w = _collapsed ? _collapsedWidth : _expandedWidth;
    final updateStatus = widget.updateService.status;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: w,
      decoration: const BoxDecoration(
        color: Color(0xE6050505),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top: brand + hamburger ──────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              _collapsed ? 12 : 24,
              32,
              _collapsed ? 12 : 16,
              0,
            ),
            child: Row(
              children: [
                if (!_collapsed) ...[
                  const Text(
                    'RelayCtrl Pro',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                  const Spacer(),
                ],
                if (_collapsed) const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _collapsed = !_collapsed),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _collapsed ? Icons.menu : Icons.menu_open,
                      color: kOnSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Node info (hidden when collapsed) ──────────────────────
          if (!_collapsed) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kSurfaceVariant,
                      border: Border.all(
                        color: kPrimary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.memory, color: kPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Controller Node 01',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: kOnSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.ip,
                          style: const TextStyle(
                            fontSize: 12,
                            color: kOnSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Divider(color: Colors.white10, height: 1),
            ),
          ] else ...[
            // Collapsed: show just the icon
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kSurfaceVariant,
                    border: Border.all(
                      color: kPrimary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.memory, color: kPrimary, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
          ],

          const SizedBox(height: 8),

          // ── Nav Items ──────────────────────────────────────────────
          _NavItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            selected: widget.selectedIndex == 0,
            collapsed: _collapsed,
            onTap: () => widget.onSelect(0),
          ),
          _NavItem(
            icon: Icons.settings,
            label: 'Settings',
            selected: widget.selectedIndex == 1,
            collapsed: _collapsed,
            onTap: () => widget.onSelect(1),
          ),

          const Spacer(),

          // ── Update item (above divider) ────────────────────────────
          _UpdateNavItem(
            status: updateStatus,
            collapsed: _collapsed,
            onTap: _handleUpdateTap,
          ),

          // ── Bottom links ───────────────────────────────────────────
          if (!_collapsed) ...[
            const Divider(
              color: Colors.white10,
              height: 1,
              indent: 24,
              endIndent: 24,
            ),
            _NavItem(
              icon: Icons.help_outline,
              label: 'Support',
              selected: false,
              collapsed: _collapsed,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.description_outlined,
              label: 'Documentation',
              selected: false,
              collapsed: _collapsed,
              onTap: () {},
            ),
          ] else ...[
            const Divider(color: Colors.white10, height: 1),
            _NavItem(
              icon: Icons.help_outline,
              label: 'Support',
              selected: false,
              collapsed: _collapsed,
              onTap: () {},
            ),
          ],

          // ── Connection indicator + version ────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              _collapsed ? 0 : 24,
              12,
              _collapsed ? 0 : 24,
              _collapsed ? 28 : 16,
            ),
            child: _collapsed
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isConnected ? kPrimary : kError,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.isConnected ? kPrimary : kError,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isConnected ? 'Hub Connected' : 'Hub Offline',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isConnected ? kPrimary : kError,
                            ),
                          ),
                        ],
                      ),
                      if (widget.appVersion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'v${widget.appVersion}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: kOutline,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          if (!_collapsed) const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Update nav item ───────────────────────────────────────────────────────────

class _UpdateNavItem extends StatelessWidget {
  final UpdateStatus status;
  final bool collapsed;
  final VoidCallback onTap;

  const _UpdateNavItem({
    required this.status,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = status == UpdateStatus.readyToRestart;
    final isAvailable = status == UpdateStatus.available;
    final isChecking = status == UpdateStatus.checking;
    final isDownloading = status == UpdateStatus.downloading;
    final hasAlert = isReady || isAvailable;

    final Color iconColor;
    final IconData icon;
    final String label;

    if (isReady) {
      icon = Icons.restart_alt_rounded;
      iconColor = kPrimary;
      label = 'Restart to Update';
    } else if (isAvailable) {
      icon = Icons.cloud_upload_rounded;
      iconColor = kPrimary;
      label = 'Update Available';
    } else if (isChecking || isDownloading) {
      icon = Icons.cloud_sync_rounded;
      iconColor = kOnSurfaceVariant;
      label = isDownloading ? 'Downloading...' : 'Checking...';
    } else {
      icon = Icons.cloud_upload_rounded;
      iconColor = kOnSurfaceVariant;
      label = 'Check for Updates';
    }

    final itemContent = collapsed
        ? Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: iconColor, size: 22),
                if (hasAlert)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: kPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          )
        : Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  if (hasAlert)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: kPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        hasAlert ? FontWeight.w600 : FontWeight.w400,
                    color: hasAlert ? kPrimary : kOnSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isReady)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: kNeonGlowBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: kNeonGlowBorder),
                  ),
                  child: const Text(
                    'READY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: kPrimary,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                ),
            ],
          );

    return Tooltip(
      message: collapsed ? label : '',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 24,
            vertical: 12,
          ),
          child: itemContent,
        ),
      ),
    );
  }
}

// ── Standard nav item ─────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      color: selected ? kPrimary : kOnSurfaceVariant,
      size: 22,
    );

    return Tooltip(
      message: collapsed ? label : '',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 24,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1A6BFB9A) : Colors.transparent,
            border: selected
                ? const Border(right: BorderSide(color: kPrimary, width: 2))
                : null,
          ),
          child: collapsed
              ? Center(child: iconWidget)
              : Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected ? kPrimary : kOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
