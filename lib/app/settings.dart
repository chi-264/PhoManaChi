import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = AsyncNotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends AsyncNotifier<ThemeMode> {
  final _preferences = SharedPreferencesAsync();
  @override
  Future<ThemeMode> build() async {
    final name = await _preferences.getString('theme');
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setTheme(ThemeMode mode) async {
    await _preferences.setString('theme', mode.name);
    state = AsyncData(mode);
  }
}
