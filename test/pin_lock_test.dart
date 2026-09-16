import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/models/app_settings.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:gunluk/theme/app_theme.dart';
import 'package:gunluk/ui/app_scope.dart';
import 'package:gunluk/ui/screens/lock_screen.dart';
import 'package:gunluk/ui/widgets/pin_pad.dart';
import 'package:gunluk/ui/widgets/pin_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppState _state() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppState(useIsolates: false, pinIterations: 500);
}

/// حالة مقفلة جاهزة للاختبارات الرسومية.
///
/// لا نستدعي `init()` هنا: داخل `testWidgets` لا تُجيب قنوات النظام (بلا محرّك)
/// فينتظر `init` إلى الأبد — بينما منطق القفل نفسه لا يحتاج التخزين أو الإشعارات.
Future<AppState> _lockedApp({
  String pin = '1234',
  int length = 4,
  bool autoUnlock = true,
}) async {
  final AppState app = _state();
  await app.repo.ensure();
  await app.setLockPassword(pin, pinLength: length);
  await app.updateLockOptions(autoUnlock: autoUnlock);
  // سقف زمني: لو تعلّقت أي قناة نظام لا يتعلّق الاختبار معها.
  await app.flush().timeout(const Duration(seconds: 10));
  app.lockNow();
  return app;
}

/// يجهّز شاشة القفل داخل نطاق التطبيق.
///
/// TickerMode مغلق: يوقف كل حركات الواجهة (نبض الشعار مثلًا) فلا تبقى إطارات
/// مجدولة تُبقي الاختبار معلّقًا — منطق الإدخال نفسه لا يعتمد على الحركة.
Widget _harness(AppState app) => AppScope(
      state: app,
      child: ListenableBuilder(
        listenable: app,
        builder: (BuildContext context, Widget? _) => MaterialApp(
          theme: AppTheme.light(app.settings),
          locale: const Locale('ar'),
          home: const TickerMode(enabled: false, child: LockScreen()),
        ),
      ),
    );

/// يضغط أرقامًا على لوحة الأرقام المخصّصة.
Future<void> _tapDigits(WidgetTester tester, String digits) async {
  for (int i = 0; i < digits.length; i++) {
    await tester.tap(find.byKey(ValueKey<String>('pin_key_${digits[i]}')));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('رمز الدخول (إعدادات + منطق)', () {
    test('تعيين الرمز يحفظ عدد الأرقام ويُفتح به', () async {
      final AppState app = _state();
      await app.init();
      await app.setLockPassword('4821', pinLength: 4);

      expect(app.lockEnabled, isTrue);
      expect(app.settings.lockPinLength, 4);
      expect(app.settings.lockHash, isNotEmpty);
      expect(app.settings.lockHash.contains('4821'), isFalse, reason: 'لا يُحفظ الرمز نفسه');

      app.lockNow();
      expect(app.locked, isTrue);

      expect(await app.verifyLockPin('0000'), isFalse);
      expect(await app.verifyLockPin('4821'), isTrue);
      expect(await app.unlock('1111'), isFalse);
      expect(app.locked, isTrue, reason: 'يبقى مقفلًا مع رمز خاطئ');
      expect(await app.unlock('4821'), isTrue);
      expect(app.locked, isFalse);
    });

    test('طول الرمز يُحفظ ويُقرأ بعد إعادة التشغيل', () async {
      final AppState app = _state();
      await app.init();
      await app.setLockPassword('135790', pinLength: 6);
      await app.flush();

      final AppState again = AppState(useIsolates: false, pinIterations: 500);
      await again.init();
      expect(again.settings.lockPinLength, 6);
      expect(again.settings.lockAutoUnlock, isTrue, reason: 'الافتراضي: فتح تلقائي');
      expect(await again.verifyLockPin('135790'), isTrue);
    });

    test('خيار الفتح التلقائي يُحفظ ويُعدّل', () async {
      final AppState app = _state();
      await app.init();
      await app.setLockPassword('1234');

      expect(app.settings.lockAutoUnlock, isTrue);
      await app.updateLockOptions(autoUnlock: false);
      expect(app.settings.lockAutoUnlock, isFalse);

      await app.flush();
      final AppState again = AppState(useIsolates: false, pinIterations: 500);
      await again.init();
      expect(again.settings.lockAutoUnlock, isFalse);
    });

    test('تعديل عدد الأرقام لا يُبطل الرمز', () async {
      final AppState app = _state();
      await app.init();
      await app.setLockPassword('5555', pinLength: 4);
      await app.updateLockOptions(pinLength: 6);

      expect(app.settings.lockPinLength, 6);
      expect(await app.verifyLockPin('5555'), isTrue, reason: 'الرمز نفسه ما زال صحيحًا');
    });

    test('إلغاء القفل يمسح البصمة والطول', () async {
      final AppState app = _state();
      await app.init();
      await app.setLockPassword('9999');
      await app.removeLock();

      expect(app.lockEnabled, isFalse);
      expect(app.settings.lockPinLength, 0);
      expect(app.locked, isFalse);
    });

    test('الإعدادات تُرمّز وتُفكّ مع الحقول الجديدة', () {
      final AppSettings settings = AppSettings(lockPinLength: 5, lockAutoUnlock: false);
      final AppSettings back = AppSettings.fromJson(settings.toJson());
      expect(back.lockPinLength, 5);
      expect(back.lockAutoUnlock, isFalse);
      // إعدادات قديمة بلا الحقول الجديدة: لا رمز رقمي + فتح تلقائي افتراضي.
      final AppSettings legacy = AppSettings.fromJson(<String, dynamic>{'lk': true, 'lh': 'x'});
      expect(legacy.lockPinLength, 0);
      expect(legacy.lockAutoUnlock, isTrue);
    });
  });

  group('شاشة القفل التفاعلية', () {
    testWidgets('نقاط بعدد أرقام الرمز ولوحة أرقام كاملة', (WidgetTester tester) async {
      final AppState app = await _lockedApp();

      await tester.pumpWidget(_harness(app));
      await tester.pump(const Duration(milliseconds: 300));

      for (final String digit in <String>['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(find.byKey(ValueKey<String>('pin_key_$digit')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey<String>('pin_key_back')), findsOneWidget);
      // الفتح التلقائي مفعّل ⇒ لا يظهر زر التأكيد.
      expect(find.byKey(const ValueKey<String>('pin_key_confirm')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    testWidgets('الرمز الصحيح يفتح التطبيق تلقائيًا', (WidgetTester tester) async {
      final AppState app = await _lockedApp();

      await tester.pumpWidget(_harness(app));
      await tester.pump(const Duration(milliseconds: 300));

      await _tapDigits(tester, '1234');
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(app.locked, isFalse, reason: 'فُتح تلقائيًا بعد اكتمال الرمز');
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    testWidgets('الرمز الخاطئ يُظهر رسالة خطأ ولا يفتح', (WidgetTester tester) async {
      final AppState app = await _lockedApp();

      await tester.pumpWidget(_harness(app));
      await tester.pump(const Duration(milliseconds: 300));

      await _tapDigits(tester, '9999');
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(app.locked, isTrue);
      expect(find.text('كلمة السر غير صحيحة'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    testWidgets('عند إيقاف الفتح التلقائي يظهر زر التأكيد ✓', (WidgetTester tester) async {
      final AppState app = await _lockedApp(autoUnlock: false);

      await tester.pumpWidget(_harness(app));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey<String>('pin_key_confirm')), findsOneWidget);

      // كتابة الرمز لا تفتح تلقائيًا.
      await _tapDigits(tester, '1234');
      await tester.pump(const Duration(milliseconds: 200));
      expect(app.locked, isTrue, reason: 'ينتظر زر التأكيد');

      await tester.tap(find.byKey(const ValueKey<String>('pin_key_confirm')));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(app.locked, isFalse, reason: 'فُتح بزر التأكيد');
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    testWidgets('الحذف يتراجع رقمًا واحدًا', (WidgetTester tester) async {
      final AppState app = await _lockedApp(pin: '4821');

      await tester.pumpWidget(_harness(app));
      await tester.pump(const Duration(milliseconds: 300));

      await _tapDigits(tester, '482');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byKey(const ValueKey<String>('pin_key_back')));
      await tester.pump(const Duration(milliseconds: 80));
      await _tapDigits(tester, '21');
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(app.locked, isFalse, reason: 'الرمز بعد الحذف صار 4821');
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    testWidgets('الترتيب من اليسار: ١ أقصى اليسار و٣ على يمينه', (WidgetTester tester) async {
      final AppState app = await _lockedApp();

      await tester.pumpWidget(_harness(app));
      await tester.pump(const Duration(milliseconds: 300));

      final double one = tester.getCenter(find.byKey(const ValueKey<String>('pin_key_1'))).dx;
      final double three = tester.getCenter(find.byKey(const ValueKey<String>('pin_key_3'))).dx;
      expect(one, lessThan(three), reason: '١ يبدأ من اليسار');

      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    testWidgets('زر كيبورد الجهاز متاح ويكتب الرمز ويفتح', (WidgetTester tester) async {
      final AppState app = await _lockedApp();

      await tester.pumpWidget(_harness(app));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('كيبورد الجهاز'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey<String>('pin_keyboard_field')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pin_key_1')), findsNothing, reason: 'لوحة الأرقام اختفت');

      await tester.enterText(find.byKey(const ValueKey<String>('pin_keyboard_field')), '1234');
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(app.locked, isFalse, reason: 'كُتب الرمز من الكيبورد وفُتح');
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    testWidgets('لا يُذكر «بصمة كلمة السر» تحت الشاشة', (WidgetTester tester) async {
      final AppState app = await _lockedApp();

      await tester.pumpWidget(_harness(app));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('بصمة'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });
  });

  group('كلمة مرور طويلة حتى ٦٤ خانة', () {
    testWidgets('٦٤ خانة تُقبل على لوحة الأرقام', (WidgetTester tester) async {
      final String pin64 = List<String>.generate(64, (int i) => '${i % 10}').join();
      final AppState app = await _lockedApp(pin: pin64, length: 64);

      await tester.pumpWidget(_harness(app));
      await tester.pump(const Duration(milliseconds: 300));

      // ٦٤ نقطة موزّعة على صفوف (١٦ في الصف).
      expect(PinDots.perRowFor(64), 16);
      expect(PinDots.dotSizeFor(64, 18), lessThan(18));

      final String prefix = pin64.substring(0, 60);
      await _tapDigits(tester, prefix);
      expect(app.locked, isTrue, reason: 'لم يكتمل الطول بعد');
      await _tapDigits(tester, pin64.substring(60));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(app.locked, isFalse, reason: 'فُتح بكلمة مرور من ٦٤ رقمًا');
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    test('الطول يُضبط بين ٤ و٦٤', () {
      expect(AppSettings.clampPinLength(0), 0, reason: '٠ = رمز قديم نصّي');
      expect(AppSettings.clampPinLength(2), 4);
      expect(AppSettings.clampPinLength(4), 4);
      expect(AppSettings.clampPinLength(37), 37);
      expect(AppSettings.clampPinLength(64), 64);
      expect(AppSettings.clampPinLength(200), 64);
    });

    test('يُحفظ ويُقرأ الحد الأقصى ٦٤ من الإعدادات', () async {
      final AppState app = _state();
      await app.init();
      await app.updateLockOptions(pinLength: 100);
      expect(app.settings.lockPinLength, 64);

      final AppSettings back = AppSettings.fromJson(app.settings.toJson());
      expect(back.lockPinLength, 64);
    });

    testWidgets('ورقة اختيار الطول تعرض الخيارات حتى ٦٤ وتعيد المختار', (WidgetTester tester) async {
      final AppState app = await _lockedApp();
      int? picked;
      // النطاق مطلوب لأن الورقة تقرأ كثافة الواجهة من الإعدادات.
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            theme: AppTheme.light(app.settings),
            locale: const Locale('ar'),
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      picked = await showPinLengthSheet(context, current: 4);
                    },
                    child: const Text('فتح'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('4'), findsOneWidget);
      expect(find.text('64'), findsOneWidget);

      await tester.tap(find.text('64'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(picked, 64);

      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });
  });
}
