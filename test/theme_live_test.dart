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
    final AppState app = AppState();

    await tester.pumpWidget(InjaziApp(state: app));
    await tester.pump();

    BuildContext context = tester.element(find.byType(SplashScreen));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(Localizations.localeOf(context).languageCode, 'ar');

    await app.updateSettings(
      app.settings.copyWith(themeMode: AppThemeMode.dark, language: 'en'),
    );
    await tester.pump();

    // يتحقق من أن MaterialApp نفسه أُعيد بناؤه بالقيم الجديدة.
    MaterialApp appWidget = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appWidget.themeMode, ThemeMode.dark);
    expect(appWidget.locale?.languageCode, 'en');

    // ثم أن السمة الفعلية سارية (بعد انتهاء تحريك السمة).
    await tester.pumpAndSettle();
    context = tester.element(find.byType(SplashScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Localizations.localeOf(context).languageCode, 'en');

    await app.updateSettings(
      app.settings.copyWith(themeMode: AppThemeMode.light, language: 'ar'),
    );
    await tester.pumpAndSettle();

    appWidget = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appWidget.themeMode, ThemeMode.light);
    context = tester.element(find.byType(SplashScreen));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(Localizations.localeOf(context).languageCode, 'ar');

    // تنظيف المؤقّتات المعلّقة (الحفظ المؤجّل)
    await app.flush();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
