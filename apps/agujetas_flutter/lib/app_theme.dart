import 'package:flutter/material.dart';

class AgujetasTheme {
  static const lightBg = Color(0xFFF7F8F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightRaised = Color(0xFFEEF3EF);
  static const lightText = Color(0xFF17211D);
  static const lightTextSecondary = Color(0xFF5F6F68);
  static const lightDivider = Color(0xFFDCE5DF);
  static const teal = Color(0xFF156355);
  static const tealContainer = Color(0xFF357C6D);
  static const tealStrong = Color(0xFF2A6357);
  static const tealDark = Color(0xFF72B7A6);
  static const amber = Color(0xFFB8752E);
  static const amberContainer = Color(0xFFFFE1BE);
  static const danger = Color(0xFFC94C4C);

  static const darkBg = Color(0xFF0B0F0E);
  static const darkSurface = Color(0xFF141A18);
  static const darkRaised = Color(0xFF1D2522);
  static const darkText = Color(0xFFF4F7F5);
  static const darkTextSecondary = Color(0xFFAAB7B2);
  static const darkDivider = Color(0xFF2A3330);

  static ThemeData light() {
    return _base(
      brightness: Brightness.light,
      background: lightBg,
      surface: lightSurface,
      raised: lightRaised,
      primary: teal,
      text: lightText,
      textSecondary: lightTextSecondary,
      divider: lightDivider,
      primaryStrong: tealStrong,
      primaryContainer: tealContainer,
      amber: amber,
      amberContainer: amberContainer,
    );
  }

  static ThemeData dark() {
    return _base(
      brightness: Brightness.dark,
      background: darkBg,
      surface: darkSurface,
      raised: darkRaised,
      primary: tealDark,
      text: darkText,
      textSecondary: darkTextSecondary,
      divider: darkDivider,
      primaryStrong: tealDark,
      primaryContainer: const Color(0xFF1F5D51),
      amber: const Color(0xFFFFB86C),
      amberContainer: const Color(0xFF3C2A18),
    );
  }

  static ThemeData _base({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color raised,
    required Color primary,
    required Color text,
    required Color textSecondary,
    required Color divider,
    required Color primaryStrong,
    required Color primaryContainer,
    required Color amber,
    required Color amberContainer,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
      primary: primary,
      error: danger,
    );
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      fontFamily: 'Inter',
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: text,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: text, fontSize: 15, height: 1.35),
        labelMedium: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: divider),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerColor: divider,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(44, 36)),
        ),
      ),
      extensions: [
        AgujetasColors(
          background: background,
          surface: surface,
          raised: raised,
          text: text,
          textSecondary: textSecondary,
          divider: divider,
          primaryStrong: primaryStrong,
          primaryContainer: primaryContainer,
          amber: amber,
          amberContainer: amberContainer,
        ),
      ],
    );
  }
}

class AgujetasColors extends ThemeExtension<AgujetasColors> {
  const AgujetasColors({
    required this.background,
    required this.surface,
    required this.raised,
    required this.text,
    required this.textSecondary,
    required this.divider,
    required this.primaryStrong,
    required this.primaryContainer,
    required this.amber,
    required this.amberContainer,
  });

  final Color background;
  final Color surface;
  final Color raised;
  final Color text;
  final Color textSecondary;
  final Color divider;
  final Color primaryStrong;
  final Color primaryContainer;
  final Color amber;
  final Color amberContainer;

  @override
  ThemeExtension<AgujetasColors> copyWith({
    Color? background,
    Color? surface,
    Color? raised,
    Color? text,
    Color? textSecondary,
    Color? divider,
    Color? primaryStrong,
    Color? primaryContainer,
    Color? amber,
    Color? amberContainer,
  }) {
    return AgujetasColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      amber: amber ?? this.amber,
      amberContainer: amberContainer ?? this.amberContainer,
    );
  }

  @override
  ThemeExtension<AgujetasColors> lerp(
    covariant ThemeExtension<AgujetasColors>? other,
    double t,
  ) {
    if (other is! AgujetasColors) return this;
    return AgujetasColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberContainer: Color.lerp(amberContainer, other.amberContainer, t)!,
    );
  }
}

extension AgujetasThemeX on BuildContext {
  AgujetasColors get appColors => Theme.of(this).extension<AgujetasColors>()!;
}
