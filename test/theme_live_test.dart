import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:gunluk/main.dart';
import 'package:gunluk/ui/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يتأكد أن تغيير الإعدادات (السمة/اللغة/الكثافة) يسري على الواجهة فورًا
/// دون الحاجة لإعادة تشغيل التطبيق — أي أن MaterialApp يعيد البناء عند الإشعار.
void main() {
  testWidgets('تغيير السمة واللغة يُطبَّق مباشرة على الواجهة', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState app = AppState(useIsolates: false);

    await tester.pumpWidget(InjaziApp(state: app));
    await tester.pump();

    BuildContext context = tester.element(find.byType(SplashScreen));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(Localizations.localeOf(context).languageCode, 'ar');

    // يطبّق سمة/لغة: إطار لإعادة بناء MaterialApp، ثم إطار لتكملة تحريك السمة.
    // (لا نستخدم pumpAndSettle لأن شاشة البداية تُشغّل حركة متكرّرة لا تنتهي.)
    Future<void> switchTo(AppThemeMode mode, String lang) async {
      await app.updateSettings(app.settings.copyWith(themeMode: mode, language: lang));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await switchTo(AppThemeMode.dark, 'en');

    // تحقّق مباشر: MaterialApp نفسه أُعيد بناؤه بالقيم الجديدة.
    MaterialApp appWidget = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appWidget.themeMode, ThemeMode.dark);
    expect(appWidget.locale?.languageCode, 'en');

    // ثم أن السمة الفعلية واللغة ساريتان على الواجهة.
    BuildContext darkContext = tester.element(find.byType(SplashScreen));
    expect(Theme.of(darkContext).brightness, Brightness.dark);
    expect(Localizations.localeOf(darkContext).languageCode, 'en');

    await switchTo(AppThemeMode.light, 'ar');

    appWidget = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appWidget.themeMode, ThemeMode.light);
    expect(appWidget.locale?.languageCode, 'ar');

    final BuildContext lightContext = tester.element(find.byType(SplashScreen));
    expect(Theme.of(lightContext).brightness, Brightness.light);
    expect(Localizations.localeOf(lightContext).languageCode, 'ar');

    // تنظيف المؤقّتات المعلّقة (الحفظ المؤجّل)
    await app.flush();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
