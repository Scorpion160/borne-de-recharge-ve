import 'package:flutter/foundation.dart';
import 'core/network/mobile_session.dart';
import 'ui/auth/mobile_login.dart';
import 'package:flutter/material.dart';

import 'core/theme/vescope_theme.dart';
import 'state/vescope_controller.dart';
import 'ui/shell/vescope_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MobileEntry());
}

class VescopeApp extends StatefulWidget {
  const VescopeApp({super.key, this.onLogout});
  final VoidCallback? onLogout;

  @override
  State<VescopeApp> createState() => _VescopeAppState();
}

class _VescopeAppState extends State<VescopeApp> {
  late final VescopeController _controller;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _controller = VescopeController();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VE-SCOPE Supervisor',
      debugShowCheckedModeBanner: false,
      theme: VescopeTheme.light(),
      darkTheme: VescopeTheme.dark(),
      themeMode: _themeMode,
      home: VescopeShell(
        onLogout: widget.onLogout,
        controller: _controller,
        themeMode: _themeMode,
        onToggleTheme: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
          });
        },
      ),
    );
  }
}

class MobileEntry extends StatefulWidget {
  const MobileEntry({super.key});
  @override
  State<MobileEntry> createState() => _MobileEntryState();
}

class _MobileEntryState extends State<MobileEntry> {
  bool _connected = false;
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const VescopeApp();
    if (_connected) {
      return VescopeApp(onLogout: () {
        MobileSession.clear();
        setState(() => _connected = false);
      });
    }
    return MaterialApp(
      title: 'VE-SCOPE', debugShowCheckedModeBanner: false,
      theme: VescopeTheme.dark(),
      home: MobileLogin(onConnected: () => setState(() => _connected = true)),
    );
  }
}
