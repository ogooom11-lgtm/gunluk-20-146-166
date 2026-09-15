import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/l10n/date_names.dart';
import '../core/models/app_settings.dart';
import '../core/utils/dates.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/palettes.dart';

/// إتاحة حالة التطبيق لكل الواجهات (بدون حزم خارجية).
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
      assert(scope != null, 'AppScope غير موجود في شجرة الواجهات');
      return scope!.notifier!;
    }
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope غير موجود في شجرة الواجهات');
    return scope!.notifier!;
  }
}

/// اختصارات مفيدة: الوصول للحالة، الإعدادات، وتنسيق النصوص.
extension AppX on BuildContext {
  AppState get app => AppScope.of(this);

  AppState get appRead => AppScope.of(this, listen: false);

  AppSettings get st => AppScope.of(this).settings;

  AppPalette get palette => AppTheme.palette(AppScope.of(this).settings);

  Spacing get gap => Spacing.of(AppScope.of(this).settings.density);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ===== تنسيقات جاهزة =====

  String timeStr(int minutes) => DateNames.time(
        minutes,
        use24: st.use24Hour,
        lang: langCode,
        arabicDigits: st.arabicDigits,
      );

  String hourStr(int hour) => DateNames.hourLabel(
        hour,
        use24: st.use24Hour,
        lang: langCode,
        arabicDigits: st.arabicDigits,
      );

  String dateStr(DateTime date, {bool withWeekday = true}) => DateNames.fullDate(
        date,
        langCode,
        arabicDigits: st.arabicDigits,
        withWeekday: withWeekday,
      );

  String shortDateStr(DateTime date) => DateNames.shortDate(date, langCode, arabicDigits: st.arabicDigits);

  String weekdayStr(DateTime date, {bool short = false}) =>
      DateNames.weekday(date, langCode, short: short);

  String monthStr(int month, {bool short = false}) => DateNames.month(month, langCode, short: short);

  String durStr(int minutes) => DateNames.duration(minutes, langCode, arabicDigits: st.arabicDigits);

  String numStr(Object value) => DateNames.digits('$value', st.arabicDigits);

  String hijriStr(DateTime date) => DateNames.hijri(date, langCode, arabicDigits: st.arabicDigits);

  /// وصف ودّي لليوم: اليوم / غدًا / أمس / التاريخ
  String relativeDay(DateTime date) {
    final int diff = Dates.diffDays(Dates.today(), date);
    switch (diff) {
      case 0:
        return tr('common.today');
      case 1:
        return tr('common.tomorrow');
      case -1:
        return tr('common.yesterday');
      default:
        return dateStr(date);
    }
  }
}
