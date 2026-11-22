import 'package:flutter/material.dart';

/// Dark look of the mock-ups (`docs/maquettes.html`): video reads best on a
/// near-black ground, as in surveillance apps. A light theme can be added
/// later as an option without touching the screens, which only use
/// [Theme.of] and [AppColors].
abstract final class AppColors {
  static const background = Color(0xFF0B0E12);
  static const surface = Color(0xFF151A21);
  static const surfaceHigh = Color(0xFF1D242D);
  static const accent = Color(0xFF3D9BFF);
  static const textDim = Color(0xFF8B98A6);

  /// Dot of the "LIVE" badge.
  static const live = Color(0xFFFF5A4E);

  /// Timeline marks, shared by every screen that draws them.
  static const recording = Color(0xFF2B3540);
  static const motion = Color(0xFF5F7386);
  static const person = Color(0xFFFF5A4E);
  static const vehicle = Color(0xFFFFB020);
  static const face = Color(0xFFC77DFF);
}

ThemeData buildDarkTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.accent,
        surface: AppColors.background,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.surfaceHigh,
      );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.background,
      indicatorColor: AppColors.surfaceHigh,
    ),
    useMaterial3: true,
  );
}
