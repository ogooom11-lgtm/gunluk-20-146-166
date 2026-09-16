import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/models/day_note.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ساعة وهمية للتحكّم في مرور الوقت داخل الاختبارات.
class _Clock {
  _Clock(this.now);
  DateTime now;
  void advance(Duration d) => now = now.add(d);
  DateTime call() => now;
}

/// كل الحالات المُنشأة — تُغلق في النهاية لإيقاف مؤقّتاتها.
final List<AppState> _made = <AppState>[];

AppState _state(_Clock clock) {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return _track(AppState(useIsolates: false, clock: clock.call));
}

AppState _track(AppState state) {
  _made.add(state);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    for (final AppState state in _made) {
      state.dispose();
    }
    _made.clear();
  });

  group('مؤقّت التركيز', () {
    test('البدء يحسب الوقت المتبقي والتقدّم ويبقى بعد مغادرة الشاشة', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();

      await app.startFocus(25, taskId: 't1', label: 'قراءة');

      expect(app.focusRunning, isTrue);
      expect(app.focusPaused, isFalse);
      expect(app.focusTotalSeconds, 25 * 60);
      expect(app.focusRemainingSeconds, 25 * 60);
      expect(app.focusProgress, 0);
      expect(app.focusLabel, 'قراءة');

      // مرور ١٠ دقائق: الوقت محسوب من الساعة لا من عدّاد داخلي.
      clock.advance(const Duration(minutes: 10));
      expect(app.focusRemainingSeconds, 15 * 60);
      expect(app.focusElapsedSeconds, 10 * 60);
      expect(app.focusProgress, closeTo(0.4, 0.001));
      expect(app.focusRunning, isTrue);
    });

    test('الإيقاف المؤقت يجمّد الوقت والمتابعة تُكمل من حيث توقّفت', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();

      await app.startFocus(30);
      clock.advance(const Duration(minutes: 12));
      await app.pauseFocus();

      expect(app.focusPaused, isTrue);
      expect(app.focusRemainingSeconds, 18 * 60);

      // الوقت يمرّ والمؤقّت متوقّف: لا يتغيّر شيء.
      clock.advance(const Duration(minutes: 45));
      expect(app.focusRemainingSeconds, 18 * 60);
      expect(app.focusRunning, isTrue);

      await app.resumeFocus();
      expect(app.focusPaused, isFalse);
      expect(app.focusRemainingSeconds, 18 * 60);
      clock.advance(const Duration(minutes: 18));
      expect(app.focusRemainingSeconds, 0);
    });

    test('الإنهاء اليدوي يسجّل الدقائق المنقضية فقط', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();

      await app.startFocus(25, label: 'مذاكرة');
      clock.advance(const Duration(minutes: 7));
      await app.stopFocus();

      expect(app.focusRunning, isFalse);
      expect(app.sessions.length, 1);
      expect(app.sessions.first.minutes, 7);
      expect(app.sessions.first.label, 'مذاكرة');
      expect(app.focusMinutesToday, 7);
    });

    test('الإيقاف قبل دقيقة لا يسجّل جلسة', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();

      await app.startFocus(25);
      clock.advance(const Duration(seconds: 20));
      await app.stopFocus();

      expect(app.sessions, isEmpty);
      expect(app.focusRunning, isFalse);
    });

    test('الراحة لا تُحتسب ضمن دقائق التركيز', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();

      await app.startFocus(25);
      clock.advance(const Duration(minutes: 25));
      await app.stopFocus(); // تُسجّل ٢٥ دقيقة تركيز

      await app.startFocus(5, isBreak: true);
      expect(app.focusIsBreak, isTrue);
      clock.advance(const Duration(minutes: 5));
      await app.stopFocus();

      expect(app.sessions.length, 1, reason: 'جلسة التركيز فقط');
      expect(app.focusMinutesToday, 25);
    });

    test('الجلسة تستمر بعد إعادة فتح التطبيق', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();
      await app.startFocus(45, label: 'كتابة');
      await app.flush();

      // إعادة تشغيل التطبيق بعد ٢٠ دقيقة.
      clock.advance(const Duration(minutes: 20));
      final AppState again = _track(AppState(useIsolates: false, clock: clock.call));
      await again.init();

      expect(again.focusRunning, isTrue, reason: 'الجلسة محفوظة وتُستعاد');
      expect(again.focusRemainingSeconds, 25 * 60);
      expect(again.focusLabel, 'كتابة');
      expect(again.focusTotalSeconds, 45 * 60);
    });

    test('جلسة منتهية أثناء إغلاق التطبيق تُسجّل كاملة عند الإقلاع', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();
      await app.startFocus(25, label: 'حفظ');
      await app.flush();

      clock.advance(const Duration(minutes: 40)); // انتهت ونحن في الخارج
      final AppState again = _track(AppState(useIsolates: false, clock: clock.call));
      await again.init();

      expect(again.focusRunning, isFalse);
      expect(again.sessions.length, 1);
      expect(again.sessions.first.minutes, 25);
      expect(again.focusMinutesToday, 25);
      expect(again.focusCompletedCount, 1);
    });

    test('استرجاع جلسة متوقّفة مؤقتًا بعد إعادة التشغيل', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();
      await app.startFocus(20);
      clock.advance(const Duration(minutes: 8));
      await app.pauseFocus();
      await app.flush();

      clock.advance(const Duration(hours: 3));
      final AppState again = _track(AppState(useIsolates: false, clock: clock.call));
      await again.init();

      expect(again.focusRunning, isTrue);
      expect(again.focusPaused, isTrue);
      expect(again.focusRemainingSeconds, 12 * 60);
    });

    test('إنهاء كل شيء يوقف المؤقّت ويمسح الجلسة', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();
      await app.startFocus(25);
      await app.resetAll();

      expect(app.focusRunning, isFalse);
      expect(app.focusRemainingSeconds, 0);
      expect(app.focusTotalSeconds, 0);
    });

    test('الجلسة المنتهية تُنهي التركيز وتظهر في الإحصاءات', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();
      // جلسة انتهت قبل ساعتين (كأنها استُعيدت من تخزين قديم).
      await app.startFocus(25, label: 'مراجعة');
      clock.advance(const Duration(minutes: 30));
      // انقضى وقتها: أي قراءة تُظهر صفرًا متبقّيًا.
      expect(app.focusRemainingSeconds, 0);
      expect(app.focusProgress, 1.0);

      await app.stopFocus();
      expect(app.sessions.first.minutes, 25, reason: 'المتاح هو كامل المدة');
      expect(app.focusMinutesTotal, greaterThanOrEqualTo(25));
    });

    test('الجلسات تُحسب في سلسلة الأيام والإحصاءات', () async {
      final _Clock clock = _Clock(DateTime(2026, 5, 4, 9));
      final AppState app = _state(clock);
      await app.init();
      await app.startFocus(30);
      clock.advance(const Duration(minutes: 30));
      await app.stopFocus();

      final List<FocusSession> today = app.sessionsOn(clock.now);
      expect(today.length, 1);
      expect(today.first.minutes, 30);
      expect(app.focusMinutesTotal, 30);
    });
  });
}
