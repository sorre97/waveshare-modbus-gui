import 'package:flutter/material.dart';
import '../services/ws_service.dart';
import '../theme.dart';
import '../widgets/sidebar.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class MainLayout extends StatefulWidget {
  final WsService service;
  const MainLayout({super.key, required this.service});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() => setState(() {});

  @override
  void dispose() {
    widget.service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBody,
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
            ip: widget.service.ip,
            isConnected: widget.service.isConnected,
          ),
          Expanded(
            child: Container(
              // Subtle dot-grid background like the mockup
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF0D1020), kBgBody],
                ),
              ),
              child: _selectedIndex == 0
                  ? DashboardScreen(service: widget.service)
                  : SettingsScreen(service: widget.service),
            ),
          ),
        ],
      ),
    );
  }
}
