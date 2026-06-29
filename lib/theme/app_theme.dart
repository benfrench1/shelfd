import 'package:flutter/material.dart';

// ─── Theme enum ───────────────────────────────────────────────────────────────

enum ShelfdTheme {
  defaultTheme,
  highContrast,
  batman,
  darkAutumnal,
}

extension ShelfdThemeExt on ShelfdTheme {
  String get displayName => switch (this) {
        ShelfdTheme.defaultTheme => 'Default',
        ShelfdTheme.highContrast => 'High Contrast',
        ShelfdTheme.batman => 'Batman (Dark)',
        ShelfdTheme.darkAutumnal => 'Dark Autumnal',
      };

  /// Three representative swatches shown in the theme picker tile.
  List<Color> get swatches => switch (this) {
        ShelfdTheme.defaultTheme => const [
            Color(0xffF5F2ED),
            Color(0xff5C3A1E),
            Color(0xFFFF5722),
          ],
        ShelfdTheme.highContrast => const [
            Color(0xFF000000),
            Color(0xFFFF9800),
            Color(0xFFFFFFFF),
          ],
        ShelfdTheme.batman => const [
            Color(0xFF16181C),
            Color(0xFFE67E22),
            Color(0xFF23272E),
          ],
        ShelfdTheme.darkAutumnal => const [
            Color(0xFF1A1008),
            Color(0xFFD2691E),
            Color(0xFFD4863A),
          ],
      };
}

// ─── Color palette ────────────────────────────────────────────────────────────

class AppColors {
  /// Scaffold / page background.
  final Color scaffoldBg;

  /// Card & modal container backgrounds.
  final Color cardBg;

  /// Slightly-off-white containers (e.g. grey.shade100 equivalents).
  final Color subtleBg;

  /// App's signature brown / brand colour.
  final Color brandColor;

  /// Avatar circle background tint.
  final Color avatarBg;

  /// Primary accent (deepOrange equivalent).
  final Color primaryAccent;

  /// Default body text (replaces Colors.black87).
  final Color textPrimary;

  /// Subtle / secondary text (replaces Colors.grey).
  final Color textSecondary;

  /// Hint / placeholder text (replaces Colors.black38).
  final Color textSubtle;

  /// Muted descriptive text (replaces Colors.black45).
  final Color textMuted;

  /// Quote of the Day box background (distinct from general subtleBg).
  final Color quoteBoxBg;

  final bool isDark;

  /// Applied to book-cover images when non-null (High Contrast only).
  final ColorFilter? bookCoverFilter;

  /// Applied to avatar images when non-null.
  final ColorFilter? avatarFilter;

  const AppColors({
    required this.scaffoldBg,
    required this.cardBg,
    required this.subtleBg,
    required this.brandColor,
    required this.avatarBg,
    required this.primaryAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textSubtle,
    required this.textMuted,
    required this.quoteBoxBg,
    required this.isDark,
    this.bookCoverFilter,
    this.avatarFilter,
  });
}

// ─── Theme definitions ────────────────────────────────────────────────────────

abstract final class AppThemeData {
  // Greyscale colour matrix (used in High Contrast for images).
  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  // ── Default ─────────────────────────────────────────────────────────────────
  // Precisely matches every hardcoded colour currently in the app.
  static final AppColors defaultColors = AppColors(
    scaffoldBg: const Color(0xffF5F2ED),
    cardBg: const Color(0xFFFFFFFF),
    subtleBg: const Color(0xFFF5F5F5), // grey.shade100
    brandColor: const Color(0xff5C3A1E),
    avatarBg: const Color(0xff5C3A1E).withValues(alpha: 0.15),
    primaryAccent: const Color(0xFFFF5722), // Colors.deepOrange
    textPrimary: const Color(0xDD000000), // Colors.black87
    textSecondary: const Color(0xFF9E9E9E), // Colors.grey
    textSubtle: const Color(0x61000000), // Colors.black38
    textMuted: const Color(0x73000000), // Colors.black45
    quoteBoxBg: const Color(0xffd6d9d6), // original quote box colour
    isDark: false,
  );

  // ── High Contrast ────────────────────────────────────────────────────────────
  // Pure black background, bright yellow accent
  static final AppColors highContrastColors = AppColors(
    scaffoldBg: const Color(0xFF000000),
    cardBg: const Color(0xFF202020),
    subtleBg: const Color(0xFF2C2C2C),
    quoteBoxBg: const Color(0xFF202020),
    brandColor: const Color(0xFFFF9800),
    primaryAccent: const Color(0xFFFF9800),
    avatarBg: const Color(0xFF303030),
    textPrimary: const Color(0xFFFFFFFF),
    textSecondary: const Color(0xFFD6D6D6),
    textSubtle: const Color(0xFFC0C0C0),
    textMuted: const Color(0xFFA8A8A8),
    isDark: true,
    bookCoverFilter: _greyscale,
    avatarFilter: null,
    );

  // ── Batman (Dark) ────────────────────────────────────────────────────────────
  // Near-black with gold/amber accent.
  static final AppColors batmanColors = AppColors(
    scaffoldBg: const Color(0xFF16181C),
    cardBg: const Color(0xFF23272E),
    subtleBg: const Color(0xFF2F343C),
    quoteBoxBg: const Color(0xFF23272E),
    brandColor: const Color(0xFFE67E22),
    primaryAccent: const Color(0xFFE67E22),
    avatarBg: const Color(0xFF323842),
    textPrimary: const Color(0xFFF2F4F8),
    textSecondary: const Color(0xFFC5CBD5),
    textSubtle: const Color(0xFFAAB2BD),
    textMuted: const Color(0xFF8E959F),
    isDark: true,
    bookCoverFilter: null,
    avatarFilter: _greyscale,
  );

  // ── Dark Autumnal ────────────────────────────────────────────────────────────
  // Deep warm browns, burnt-orange/amber accent.
  static final AppColors darkAutumnalColors = AppColors(
    scaffoldBg: const Color(0xFF1A1008),
    cardBg: const Color(0xFF2D1C0C),
    subtleBg: const Color(0xFF3A2510),
    brandColor: const Color(0xFFD4863A),
    avatarBg: const Color(0xFF3D2010),
    primaryAccent: const Color(0xFFD2691E),
    textPrimary: const Color(0xFFF5DEB3),
    textSecondary: const Color(0xFFB8956A),
    textSubtle: const Color(0xFF8A6040),
    textMuted: const Color(0xFF9A7050),
    quoteBoxBg: const Color(0xFF3A2510),
    isDark: true,
    avatarFilter:
        const ColorFilter.mode(Color(0x28D2691E), BlendMode.srcATop),
  );

  static AppColors colorsFor(ShelfdTheme t) => switch (t) {
        ShelfdTheme.defaultTheme => defaultColors,
        ShelfdTheme.highContrast => highContrastColors,
        ShelfdTheme.batman => batmanColors,
        ShelfdTheme.darkAutumnal => darkAutumnalColors,
      };

  static ThemeData themeDataFor(ShelfdTheme t) {
    final c = colorsFor(t);

    if (!c.isDark) {
      // Default — preserve existing ThemeData exactly.
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: c.scaffoldBg,
        appBarTheme: AppBarTheme(
          backgroundColor: c.scaffoldBg,
          foregroundColor: const Color(0xDD000000),
          elevation: 0,
        ),
        // No backgroundColor set — preserves the original M3 default (white surface).
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: c.primaryAccent,
        ),
      );
    }

    // Shared dark-theme base.
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: c.scaffoldBg,
      colorScheme: ColorScheme.dark(
        primary: c.primaryAccent,
        secondary: c.brandColor,
        surface: c.cardBg,
      ),
      cardTheme: CardThemeData(
        color: c.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.scaffoldBg,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.scaffoldBg,
        selectedItemColor: c.primaryAccent,
        unselectedItemColor: c.textSecondary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primaryAccent,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: c.primaryAccent,
      ),
      dividerColor: c.brandColor.withValues(alpha: 0.3),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: c.textPrimary),
        bodyMedium: TextStyle(color: c.textPrimary),
        bodySmall: TextStyle(color: c.textSecondary),
        titleLarge: TextStyle(color: c.textPrimary),
        titleMedium: TextStyle(color: c.textPrimary),
        titleSmall: TextStyle(color: c.textPrimary),
        labelLarge: TextStyle(color: c.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: c.cardBg,
        filled: true,
        hintStyle: TextStyle(color: c.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.brandColor.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.brandColor.withValues(alpha: 0.4)),
        ),
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
      dialogTheme: DialogThemeData(backgroundColor: c.cardBg),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.cardBg,
        modalBackgroundColor: c.cardBg,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.subtleBg,
        labelStyle: TextStyle(color: c.textPrimary),
      ),
      listTileTheme: ListTileThemeData(
        textColor: c.textPrimary,
        iconColor: c.textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primaryAccent,
          foregroundColor: c.isDark ? c.scaffoldBg : Colors.white,
        ),
      ),
    );
  }
}

// ─── InheritedWidget scope ────────────────────────────────────────────────────

class ShelfdThemeScope extends InheritedWidget {
  final ShelfdTheme theme;
  final AppColors colors;
  final ValueChanged<ShelfdTheme> onThemeChanged;

  const ShelfdThemeScope({
    super.key,
    required this.theme,
    required this.colors,
    required this.onThemeChanged,
    required super.child,
  });

  static ShelfdThemeScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShelfdThemeScope>()!;

  static AppColors colorsOf(BuildContext context) => of(context).colors;

  @override
  bool updateShouldNotify(ShelfdThemeScope old) => theme != old.theme;
}

// ─── Utility widget helpers ───────────────────────────────────────────────────

/// Wraps [child] in a [ColorFiltered] when the theme requires it for book
/// covers (High Contrast only). Otherwise returns [child] unchanged.
Widget themedBookCover({
  required AppColors colors,
  required Widget child,
}) {
  if (colors.bookCoverFilter == null) return child;
  return ColorFiltered(colorFilter: colors.bookCoverFilter!, child: child);
}

/// Wraps [child] in a [ColorFiltered] when the theme applies an avatar tint.
Widget themedAvatar({
  required AppColors colors,
  required Widget child,
}) {
  if (colors.avatarFilter == null) return child;
  return ColorFiltered(colorFilter: colors.avatarFilter!, child: child);
}
