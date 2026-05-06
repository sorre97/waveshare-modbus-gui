import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'services/ws_service.dart';
import 'screens/main_layout.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(900, 620),
    center: true,
    title: 'RelayCtrl Pro',
    backgroundColor: Color(0xFF050505),
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const RelayCtrlApp());
}

class RelayCtrlApp extends StatefulWidget {
  const RelayCtrlApp({super.key});

  @override
  State<RelayCtrlApp> createState() => _RelayCtrlAppState();
}

class _RelayCtrlAppState extends State<RelayCtrlApp> {
  final WsService _service = WsService();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RelayCtrl Pro',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: MainLayout(service: _service),
    );
  }
}
