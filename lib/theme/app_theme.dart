import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/models/app_settings.dart';
import 'palettes.dart';

/// ألوان وسمة التطبيق (فاتح/غامق) + مقاسات مشتركة.
class AppTheme {
  AppTheme._();

  static const Color surfaceLight = Color(0xFFF5F6FB);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0E1117);
  static const Color cardDark = Color(0xFF171B24);

  static AppPalette palette(AppSettings settings) => Palettes.of(settings.accentIndex);

  static ThemeData light(AppSettings settings) => _build(settings, Brightness.light);

  static ThemeData dark(AppSettings settings) => _build(settings, Brightness.dark);

  static ThemeData _build(AppSettings settings, Brightness brightness) {
    final AppPalette p = palette(settings);
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme base = ColorScheme.fromSeed(seedColor: p.seed, brightness: brightness);
    final double radius = settings.radiusScale;

    final ColorScheme scheme = base.copyWith(
      surface: isDark ? surfaceDark : surfaceLight,
      surfaceContainerLowest: isDark ? const Color(0xFF0A0D13) : Colors.white,
      surfaceContainerLow: isDark ? cardDark : Colors.white,
      surfaceContainer: isDark ? const Color(0xFF1E2330) : const Color(0xFFEDEFF7),
      surfaceContainerHigh: isDark ? const Color(0xFF242A38) : const Color(0xFFE5E8F3),
      onSurface: isDark ? const Color(0xFFE9ECF5) : const Color(0xFF1B1E28),
    );

    final TextTheme text = _textTheme(scheme, isDark);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Cairo',
      textTheme: text,
      primaryTextTheme: text,
      visualDensity: settings.density == UiDensity.compact
          ? VisualDensity.compact
          : settings.density == UiDensity.comfortable
              ? VisualDensity.comfortable
              : VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: isDark ? cardDark : cardLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * radius)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withAlpha(isDark ? 40 : 90),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1B2029) : const Color(0xFFF0F2F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16 * radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16 * radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16 * radius),
          borderSide: BorderSide(color: p.seed.withAlpha(160), width: 1.6),
        ),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurface.withAlpha(110)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1D222C) : const Color(0xFFEEF0F8),
        selectedColor: p.seed.withAlpha(isDark ? 70 : 45),
        side: BorderSide.none,
        labelStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * radius)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.seed,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22 * radius)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.seed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * radius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: scheme.outlineVariant.withAlpha(140)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * radius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.seed,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF151922) : Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28 * radius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF171B24) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24 * radius)),
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        contentTextStyle: text.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF12151C) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: p.seed.withAlpha(isDark ? 70 : 42),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF242A38) : const Color(0xFF232838),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * radius)),
        insetPadding: const EdgeInsets.all(16),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.seed,
        unselectedLabelColor: scheme.onSurface.withAlpha(150),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * radius)),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.seed,
        thumbColor: p.seed,
        inactiveTrackColor: p.seed.withAlpha(50),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return p.seed;
          return null;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.seed,
        linearTrackColor: p.seed.withAlpha(50),
        circularTrackColor: p.seed.withAlpha(50),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface.withAlpha(200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * radius)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A303D) : const Color(0xFF2A303D),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Cairo'),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18 * radius)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18 * radius)),
        iconColor: p.seed,
        textColor: scheme.onSurface,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6 * radius)),
        side: BorderSide(color: scheme.outline.withAlpha(160), width: 1.6),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme, bool isDark) {
    final Color main = scheme.onSurface;
    final Color muted = main.withAlpha(170);
    return TextTheme(
      displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: main, height: 1.2),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: main, height: 1.2),
      displaySmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: main, height: 1.25),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: main, height: 1.3),
      headlineSmall: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: main, height: 1.3),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: main, height: 1.35),
      titleMedium: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: main, height: 1.35),
      titleSmall: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: main, height: 1.35),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: main, height: 1.55),
      bodyMedium: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, color: main, height: 1.55),
      bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: muted, height: 1.5),
      labelLarge: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: main, height: 1.3),
      labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted, height: 1.3),
      labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: muted, height: 1.3),
    );
  }

  /// خط الأرقام والعناوين الفرعية (Readex Pro) — يمنح شكلاً هندسيًا حديثًا.
  static TextStyle numeric(BuildContext context, {double factor = 1, FontWeight weight = FontWeight.w700, Color? color}) {
    final TextStyle base = Theme.of(context).textTheme.titleLarge ?? const TextStyle();
    return base.copyWith(
      fontFamily: 'ReadexPro',
      fontWeight: weight,
      fontSize: (base.fontSize ?? 19) * factor,
      color: color,
      letterSpacing: 0,
    );
  }
}

/// مقاسات ومسافات تعتمد على كثافة العرض المختارة.
class Spacing {
  const Spacing(this.screenPadding, this.gap, this.cardPadding);

  final double screenPadding;
  final double gap;
  final double cardPadding;

  static Spacing of(UiDensity density) {
    switch (density) {
      case UiDensity.compact:
        return const Spacing(14, 10, 14);
      case UiDensity.cozy:
        return const Spacing(18, 14, 16);
      case UiDensity.comfortable:
        return const Spacing(22, 18, 20);
    }
  }
}

/// أدوات ألوان بسيطة (بدل withOpacity المهجورة).
extension ColorX on Color {
  Color op(double factor) => withAlpha((factor * 255).round().clamp(0, 255));
}

/// تدرّج جاهز للبطاقات المميزة.
extension GradientX on AppPalette {
  LinearGradient get linearGradient => LinearGradient(
        colors: gradient,
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      );

  LinearGradient darkLinearGradient({bool isDark = false}) => LinearGradient(
        colors: isDark ? darkGradient : gradient,
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      );
}
