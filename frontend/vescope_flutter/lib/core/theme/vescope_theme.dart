import 'package:flutter/material.dart';

abstract final class VescopeTheme {
  static const _seed = Color(0xFF59AEFE);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0D1928),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        surface: const Color(0xFF0D1928),
        primary: _seed,
        secondary: const Color(0xFF55D68A),
      ),
      scaffoldBackgroundColor: const Color(0xFF08111F),
      cardColor: const Color(0xFF0D1928),
      dividerColor: const Color(0xFF1D3044),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF0B1524),
        indicatorColor: Color(0xFF17304D),
        selectedIconTheme: IconThemeData(color: Color(0xFFBFE0FF)),
        unselectedIconTheme: IconThemeData(color: Color(0xFF8FA1B7)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0B1524),
        indicatorColor: const Color(0xFF17304D),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFBFE0FF)
                : const Color(0xFF8FA1B7),
          );
        }),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF0A1625),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFF26394E)),
        ),
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF3F6FA),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFD9E3EC),
    );
  }
}
