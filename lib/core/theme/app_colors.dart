import 'package:flutter/material.dart';

import 'theme_controller.dart';

abstract final class AppColors {
  static bool get _dark => ThemeController.instance.isDark;

  static Color get surface =>
      _dark ? const Color(0xFF0E1514) : const Color(0xFFF7FAF8);
  static Color get surfaceBright =>
      _dark ? const Color(0xFF101A18) : const Color(0xFFF7FAF8);
  static Color get surfaceContainerLowest =>
      _dark ? const Color(0xFF15201E) : const Color(0xFFFFFFFF);
  static Color get surfaceContainerLow =>
      _dark ? const Color(0xFF1B2927) : const Color(0xFFF1F4F3);
  static Color get surfaceContainer =>
      _dark ? const Color(0xFF223230) : const Color(0xFFEBEFED);
  static Color get surfaceContainerHigh =>
      _dark ? const Color(0xFF2B3B39) : const Color(0xFFE5E9E7);
  static Color get surfaceContainerHighest =>
      _dark ? const Color(0xFF354643) : const Color(0xFFE0E3E1);
  static Color get surfaceVariant =>
      _dark ? const Color(0xFF354643) : const Color(0xFFE0E3E1);

  static Color get onSurface =>
      _dark ? const Color(0xFFE9F1EF) : const Color(0xFF181C1C);
  static Color get onSurfaceVariant =>
      _dark ? const Color(0xFFB8C7C3) : const Color(0xFF3E4947);
  static Color get outline =>
      _dark ? const Color(0xFF8BA09B) : const Color(0xFF6E7977);
  static Color get outlineVariant =>
      _dark ? const Color(0xFF435754) : const Color(0xFFBDC9C6);

  static Color get primary =>
      _dark ? const Color(0xFF67DED3) : const Color(0xFF005C55);
  static Color get primaryContainer =>
      _dark ? const Color(0xFF0F766E) : const Color(0xFF0F766E);
  static Color get onPrimary =>
      _dark ? const Color(0xFF00201D) : const Color(0xFFFFFFFF);
  static Color get onPrimaryContainer =>
      _dark ? const Color(0xFFA3FAEF) : const Color(0xFFA3FAEF);
  static Color get primaryFixed => const Color(0xFF9CF2E8);

  static Color get secondary =>
      _dark ? const Color(0xFF71EBD8) : const Color(0xFF006B5F);
  static Color get secondaryContainer =>
      _dark ? const Color(0xFF075C53) : const Color(0xFF6DF5E1);
  static Color get onSecondary =>
      _dark ? const Color(0xFF00201C) : const Color(0xFFFFFFFF);
  static Color get onSecondaryContainer =>
      _dark ? const Color(0xFFB9FFF3) : const Color(0xFF006F64);

  static Color get tertiary =>
      _dark ? const Color(0xFF8BDDD4) : const Color(0xFF0C5B56);
  static Color get tertiaryContainer =>
      _dark ? const Color(0xFF255E5A) : const Color(0xFF2F746F);
  static Color get onTertiary =>
      _dark ? const Color(0xFF00201E) : const Color(0xFFFFFFFF);
  static Color get onTertiaryContainer =>
      _dark ? const Color(0xFFC2FFF7) : const Color(0xFFB3F7F0);

  static Color get error =>
      _dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
  static Color get errorContainer =>
      _dark ? const Color(0xFF690005) : const Color(0xFFFFDAD6);
  static Color get onErrorContainer =>
      _dark ? const Color(0xFFFFDAD6) : const Color(0xFF93000A);
  static Color get income =>
      _dark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E);
  static Color get expense =>
      _dark ? const Color(0xFFF87171) : const Color(0xFFEF4444);
}
