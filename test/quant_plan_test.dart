import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/core/l10n/app_strings.dart';
import 'package:gunluk/core/models/plan.dart';
import 'package:gunluk/core/models/task.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خطة كمّية: ٥٠٠ صفحة خلال أسبوع (٧ أيام) تبدأ يوم الخميس ٢٠٢٦/٩/١٧.
Plan _book({double target = 500, Set<int> rest = const <int>{}}) => Plan(
      id: 'p1',
      title: 'قراءة كتاب',
      startDate: DateTime(2026, 9, 17),
      endDate: DateTime(2026, 9, 23),
      target: target,
      unit: 'صفحة',
      restWeekdays: rest,
    );

AppState _state(DateTime now) {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppState(useIsolates: false, pinIterations: 500, clock: () => now);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('توزيع الهدف الكمّي', () {
    test('٥٠٠ صفحة في ٧ أيام = ٧٢ صفحة يوميًا (الباقي في آخر يوم)', () {
      final Plan plan = _book();
      final List<PlanDayAmount> days = plan.schedule(from: DateTime(2026, 9, 17), maxDays: 7);
      expect(days.length, 7);
      expect(days.first.amount, 72);
      expect(days.every((PlanDayAmount d) => d.amount > 0), isTrue);
      final double sum = days.fold<double>(0, (double a, PlanDayAmount d) => a + d.amount);
      expect(sum, closeTo(500, 0.001), reason: 'مجموع المطلوب = الهدف الكلي');
    });

    test('أيام الراحة تُستثنى من التوزيع', () {
      final Plan plan = _book(rest: <int>{DateTime.friday});
      final List<PlanDayAmount> days = plan.schedule(from: DateTime(2026, 9, 17), maxDays: 7);
      expect(
        days.any((PlanDayAmount d) => d.day.weekday == DateTime.friday),
        isFalse,
        reason: 'الجمعة يوم راحة',
      );
      expect(days.length, 6);
      expect(days.first.amount, 84, reason: '٥٠٠ ÷ ٦ = ٨٤');
    });

    test('أنجزت أكثر ⇒ يقلّ المطلوب، أنجزت أقل ⇒ يرتفع', () {
      final Plan plan = _book();
      expect(plan.requiredOn(DateTime(2026, 9, 17)), 72);

      // أنجزت ١٤٤ (ضعف المطلوب) في اليوم الأول.
      plan.progress['2026-09-17'] = 144;
      expect(plan.requiredOn(DateTime(2026, 9, 18)), 60, reason: '٣٥٦ ÷ ٦ = ٥٩٫٣٣ ⇒ ٦٠');

      // لم تُنجز شيئًا قبل اليوم الثالث ⇒ يرتفع المطلوب أكثر.
      expect(plan.requiredOn(DateTime(2026, 9, 19)), 72, reason: '٣٥٦ ÷ ٥ = ٧١٫٢ ⇒ ٧٢');
    });

    test('تسجيل الكمّية يُحدّث المطلوب ويُنجز مهمة اليوم', () async {
      final AppState app = _state(DateTime(2026, 9, 17, 9, 0));
      await app.repo.ensure();
      final Plan plan = _book();
      await app.upsertPlan(plan);

      expect(app.planRequiredToday(plan), 72);
      final Task? today = app.taskFor('p1', DateTime(2026, 9, 17));
      expect(today, isNotNull);
      expect(today!.amountTarget, 72);
      expect(today.amountUnit, 'صفحة');

      // أنجزت ٧٢ ⇒ تُكتمل مهمة اليوم ويصبح المطلوب أعلى غدًا.
      await app.logPlanAmount('p1', DateTime(2026, 9, 17), 72);
      expect(plan.progress['2026-09-17'], 72);
      expect(today.done, isTrue, reason: 'بلغ المطلوب');
      final Task? tomorrow = app.taskFor('p1', DateTime(2026, 9, 18));
      expect(tomorrow?.amountTarget, 72, reason: '٤٢٨ ÷ ٦ = ٧٢');

      // أنجزت أكثر بكثير في اليوم الأول ⇒ يقلّ المطلوب، وتُخفى المطالبة عند
      // اكتمال الهدف كله.
      await app.logPlanAmount('p1', DateTime(2026, 9, 17), 428);
      expect(plan.remainingAmount, 0);
      expect(plan.requiredOn(DateTime(2026, 9, 18)), 0, reason: 'اكتمل الهدف');
      expect(app.taskFor('p1', DateTime(2026, 9, 18))?.amountTarget, 0);
      app.dispose();
    });

    test('التقدّم والنسبة والكمّية المتبقية', () async {
      final AppState app = _state(DateTime(2026, 9, 17, 9, 0));
      await app.repo.ensure();
      final Plan plan = _book();
      await app.upsertPlan(plan);
      await app.logPlanAmount('p1', DateTime(2026, 9, 17), 250);
      expect(plan.doneAmount, 250);
      expect(plan.remainingAmount, 250);
      expect(plan.amountRatio, closeTo(0.5, 0.001));
      await app.logPlanAmount('p1', DateTime(2026, 9, 18), 250);
      expect(plan.remainingAmount, 0);
      expect(plan.amountRatio, 1.0);
      app.dispose();
    });

    test('الحفظ والاسترجاع (JSON) يحافظ على الهدف والكمّيات', () {
      final Plan plan = _book(rest: <int>{DateTime.friday});
      plan.progress['2026-09-17'] = 60;
      plan.progress['2026-09-18'] = 12.5;
      final Plan restored = Plan.fromJson(plan.toJson());

      expect(restored.target, 500);
      expect(restored.unit, 'صفحة');
      expect(restored.restWeekdays, <int>{DateTime.friday});
      expect(restored.progress['2026-09-17'], 60);
      expect(restored.progress['2026-09-18'], 12.5);
      expect(restored.doneAmount, 72.5);
      expect(restored.isQuantified, isTrue);
    });

    test('الخطة الكمّية تُنفَّذ كل يوم ما عدا أيام الراحة', () {
      final Plan plan = _book(rest: <int>{DateTime.friday});
      expect(plan.occursOn(DateTime(2026, 9, 17)), isTrue);
      expect(plan.occursOn(DateTime(2026, 9, 18)), isFalse, reason: 'الجمعة راحة');
      expect(plan.occursOn(DateTime(2026, 9, 24)), isFalse, reason: 'بعد النهاية');
      expect(plan.occurrences(DateTime(2026, 9, 17), DateTime(2026, 9, 23)).length, 6);
    });

    test('لم تسجّل شيئًا في اليوم الأول ⇒ يرتفع المطلوب في اليوم التالي', () async {
      final AppState app = _state(DateTime(2026, 9, 18, 9, 0));
      await app.repo.ensure();
      final Plan plan = _book();
      await app.upsertPlan(plan);
      expect(app.planRequiredToday(plan), 84, reason: '٥٠٠ ÷ ٦ = ٨٣٫٣ ⇒ ٨٤');
      expect(app.taskFor('p1', DateTime(2026, 9, 18))?.amountTarget, 84);
      app.dispose();
    });

    test('معلومة كاملة: الخطة العادية ليست كمّية', () {
      final Plan normal = Plan(id: 'p2', title: 'رياضة', startDate: DateTime(2026, 9, 17));
      expect(normal.isQuantified, isFalse);
      expect(normal.requiredOn(DateTime(2026, 9, 17)), 0);
      expect(normal.schedule(from: DateTime(2026, 9, 17)), isEmpty);
    });
  });

  group('مهمة اليوم الكمّية', () {
    test('نصّ الكمّية يظهر في المهمة ويُخزَّن', () {
      final Task task = Task(
        id: 't1',
        title: 'قراءة',
        date: DateTime(2026, 9, 17),
        amountTarget: 72,
        amountDone: 30,
        amountUnit: 'صفحة',
      );
      expect(task.hasAmount, isTrue);
      expect(task.amountRatio, closeTo(30 / 72, 0.001));
      expect(task.progress, closeTo(30 / 72, 0.001), reason: 'شريط التقدّم يعتمد الكمّية');
      final Task copy = Task.fromJson(task.toJson());
      expect(copy.amountTarget, 72);
      expect(copy.amountDone, 30);
      expect(copy.amountUnit, 'صفحة');
    });

    test('إيقاف الإكمال التلقائي يترك المهمة كما هي', () async {
      final AppState app = _state(DateTime(2026, 9, 17, 9, 0));
      await app.repo.ensure();
      await app.upsertPlan(_book().copyWith(autoComplete: false));
      await app.logPlanAmount('p1', DateTime(2026, 9, 17), 100);
      final Task? today = app.taskFor('p1', DateTime(2026, 9, 17));
      expect(today?.done, isFalse, reason: 'الإكمال التلقائي موقوف');
      expect(today?.amountDone, 100);
      app.dispose();
    });
  });

  group('سلامة الحفظ والتذكيرات', () {
    test('حفظ الخطة الكمّية يبني تذكيرات مهام الأيام', () async {
      final AppState app = _state(DateTime(2026, 9, 17, 9, 0));
      await app.repo.ensure();
      Plan plan = _book();
      await app.upsertPlan(plan);
      expect(app.tasks.where((Task t) => t.planId == 'p1').length, greaterThanOrEqualTo(7));

      // تسجيل كمّية لا يُنشئ مهامًا مكرّرة ولا يحذف شيئًا.
      final int before = app.tasks.length;
      await app.logPlanAmount('p1', DateTime(2026, 9, 17), 40);
      expect(app.tasks.length, before, reason: 'لا تكرار للمهام');
      await app.flush();
      final List<Map<String, dynamic>> stored =
          (await app.repo.takeOps());
      expect(stored, isEmpty);
      plan = app.planById('p1')!;
      expect(plan.progress['2026-09-17'], 40);
      app.dispose();
    });
  });

  group('نصوص الخطة الكمّية', () {
    test('كل مفاتيح quant موجودة بالعربية والإنجليزية', () {
      const List<String> keys = <String>[
        'quant.title',
        'quant.enabled',
        'quant.total',
        'quant.unit',
        'quant.needTotal',
        'quant.needEnd',
        'quant.needUnit',
        'quant.restDays',
        'quant.restDaysHint',
        'quant.autoComplete',
        'quant.preview',
        'quant.perDay',
        'quant.repeatAll',
        'quant.overview',
        'quant.remaining',
        'quant.todayRequired',
        'quant.dailyTarget',
        'quant.doneToday',
        'quant.valueUnit',
        'quant.ofPair',
        'quant.log',
        'quant.logged',
        'quant.markDoneFull',
        'quant.nothing',
        'quant.nextAfter',
        'quant.saved',
        'quant.schedule',
        'quant.scheduleHint',
        'quant.dayDone',
        'quant.dayPartial',
        'quant.allDone',
        'quant.noDays',
      ];
      final AppLocalizations ar = AppLocalizations.ofLocale(const Locale('ar'));
      final AppLocalizations en = AppLocalizations.ofLocale(const Locale('en'));
      for (final String key in keys) {
        expect(ar.t(key), isNot(key), reason: 'نص عربي ناقص: $key');
        expect(en.t(key), isNot(key), reason: 'نص إنجليزي ناقص: $key');
      }
      expect(
        ar.t('quant.ofPair', <String, String>{'done': '٣٠', 'total': '٧٢', 'unit': 'صفحة'}),
        '٣٠ من ٧٢ صفحة',
      );
    });
  });

  group('المنبّه داخل التطبيق', () {
    test('checkDueAlarm تعيد false بلا مهمة عاجلة', () async {
      final AppState app = _state(DateTime(2026, 9, 17, 9, 0));
      await app.repo.ensure();
      expect(app.checkDueAlarm(), isFalse);
      app.dispose();
    });
  });

  group('تذكير نهاية اليوم لا يتأثر بالخطط الكمّية', () {
    test('الخطة العادية لم تتغيّر', () {
      final Plan weekly = Plan(
        id: 'p3',
        title: 'روتين',
        startDate: DateTime(2026, 9, 1),
        repeatType: RepeatType.weekly,
        weekdays: <int>{DateTime.thursday},
      );
      expect(weekly.repeatType, RepeatType.weekly);
      expect(weekly.occursOn(DateTime(2026, 9, 17)), isTrue);
      expect(weekly.occursOn(DateTime(2026, 9, 18)), isFalse);
    });
  });
}
