import 'package:flutter/material.dart';
import '../theme.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String ip;
  final bool isConnected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.ip,
    required this.isConnected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  bool _collapsed = false;

  static const double _expandedWidth = 280;
  static const double _collapsedWidth = 64;

  @override
  Widget build(BuildContext context) {
    final w = _collapsed ? _collapsedWidth : _expandedWidth;

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

          // ── Connection indicator ───────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              _collapsed ? 0 : 24,
              12,
              _collapsed ? 0 : 24,
              28,
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
                : Row(
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
          ),
        ],
      ),
    );
  }
}

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
