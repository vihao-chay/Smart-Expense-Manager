import 'package:flutter/material.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.light);

  static final ThemeController instance = ThemeController._();

  bool get isDark => value == ThemeMode.dark;

  String get firestoreValue => isDark ? 'dark' : 'light';

  void setDarkMode(bool enabled) {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (value == nextMode) return;
    value = nextMode;
  }

  void applyFirestoreValue(String value) {
    setDarkMode(value == 'dark');
  }
}
