import 'package:flutter/material.dart';

ThemeData phoneManagerTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFA9C7FF) : const Color(0xFF2563EB),
        onPrimary: dark ? const Color(0xFF102B56) : Colors.white,
        surface: dark ? const Color(0xFF1A2332) : Colors.white,
        onSurface: dark ? const Color(0xFFE1E7F0) : const Color(0xFF202B3D),
        onSurfaceVariant: dark
            ? const Color(0xFFB1BED1)
            : const Color(0xFF526075),
        outlineVariant: dark
            ? const Color(0xFF354359)
            : const Color(0xFFE1E7F0),
      );
  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xFF111A28)
        : const Color(0xFFF7F9FC),
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        height: 1.5,
        color: colors.onSurfaceVariant,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.primaryContainer,
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
  );
}

enum Accent { blue, purple, mint, warning }

extension AccentColors on Accent {
  Color background(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      Accent.blue => Color(dark ? 0xFF203457 : 0xFFEDF3FF),
      Accent.purple => Color(dark ? 0xFF322B4E : 0xFFF1EDFF),
      Accent.mint => Color(dark ? 0xFF213C38 : 0xFFEAF7F2),
      Accent.warning => Color(dark ? 0xFF403426 : 0xFFFFF3E8),
    };
  }

  Color foreground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      Accent.blue => Color(dark ? 0xFFA9C7FF : 0xFF2455AE),
      Accent.purple => Color(dark ? 0xFFD4BEFF : 0xFF6945A5),
      Accent.mint => Color(dark ? 0xFFAADECC : 0xFF226E56),
      Accent.warning => Color(dark ? 0xFFECCB96 : 0xFF80500D),
    };
  }
}
