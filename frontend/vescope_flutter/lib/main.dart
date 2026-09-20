import 'package:flutter/material.dart';

import 'core/theme/vescope_theme.dart';
import 'state/vescope_controller.dart';
import 'ui/shell/vescope_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VescopeApp());
}

class VescopeApp extends StatefulWidget {
  const VescopeApp({super.key});

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
