import 'package:flutter/material.dart';

const campusPurple = Color(0xFF5B2DFF);
const campusNavy = Color(0xFF1F1F28);
const campusBackground = Color(0xFFFCFAF6);

@immutable
class CampusPalette extends ThemeExtension<CampusPalette> {
  const CampusPalette({
    required this.canvas,
    required this.surface,
    required this.soft,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.hero,
    required this.sidebar,
  });
  static const light = CampusPalette(
    canvas: campusBackground,
    surface: Color(0xFFFFFDFC),
    soft: Color(0xFFF1EBFC),
    ink: campusNavy,
    muted: Color(0xFF6D6678),
    line: Color(0xFFEAE5ED),
    accent: campusPurple,
    hero: Color(0xFFF0E9FC),
    sidebar: Color(0xFFF7F3FA),
  );
  static const dark = CampusPalette(
    canvas: Color(0xFF191A25),
    surface: Color(0xFF242533),
    soft: Color(0xFF333047),
    ink: Color(0xFFF7F2FF),
    muted: Color(0xFFB9B2CA),
    line: Color(0xFF3B384D),
    accent: Color(0xFFC8B4FF),
    hero: Color(0xFF302B46),
    sidebar: Color(0xFF20212F),
  );
  final Color canvas, surface, soft, ink, muted, line, accent, hero, sidebar;
  @override
  CampusPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? soft,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? hero,
    Color? sidebar,
  }) => CampusPalette(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    soft: soft ?? this.soft,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    accent: accent ?? this.accent,
    hero: hero ?? this.hero,
    sidebar: sidebar ?? this.sidebar,
  );
  @override
  CampusPalette lerp(covariant CampusPalette? other, double t) {
    if (other == null) return this;
    return CampusPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      hero: Color.lerp(hero, other.hero, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
    );
  }
}

extension CampusContext on BuildContext {
  CampusPalette get campus => Theme.of(this).extension<CampusPalette>()!;
}

ThemeData campusTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final p = dark ? CampusPalette.dark : CampusPalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: campusPurple,
        brightness: brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: dark ? const Color(0xFF28164B) : Colors.white,
        surface: p.surface,
        onSurface: p.ink,
        onSurfaceVariant: p.muted,
        outline: p.line,
        primaryContainer: p.soft,
        onPrimaryContainer: p.accent,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'DM Sans',
  );
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: p.line),
  );
  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.canvas,
    textTheme: base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontFamily: 'DM Serif Display',
        fontSize: 40,
        height: 1.12,
        color: p.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'DM Serif Display',
        fontSize: 32,
        height: 1.2,
        color: p.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: 'DM Serif Display',
        fontSize: 25,
        color: p.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 14,
        height: 1.5,
        color: p.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 12,
        height: 1.45,
        color: p.muted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.canvas,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.canvas,
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      hintStyle: TextStyle(color: p.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        textStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(color: p.line),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: const StadiumBorder(),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: p.sidebar,
    ),
  );
}

class CampusPanel extends StatelessWidget {
  const CampusPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? context.campus.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: context.campus.line),
      boxShadow: Theme.of(context).brightness == Brightness.light
          ? [
              BoxShadow(
                color: const Color(0xFF3E275B).withValues(alpha: .035),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    ),
    child: child,
  );
}

class CampusEmptyState extends StatelessWidget {
  const CampusEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });
  final IconData icon;
  final String title, detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => CampusPanel(
    padding: const EdgeInsets.all(30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: context.campus.soft,
          foregroundColor: context.campus.accent,
          child: Icon(icon, size: 26),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.campus.muted, height: 1.5),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}
