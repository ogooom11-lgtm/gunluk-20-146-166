import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/core/l10n/app_strings.dart';
import 'package:gunluk/core/models/app_settings.dart';
import 'package:gunluk/core/models/plan.dart';
import 'package:gunluk/core/models/planned_reminder.dart';
import 'package:gunluk/core/models/task.dart';
import 'package:gunluk/core/utils/dates.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:gunluk/data/reminder_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حالة تطبيق نظيفة (بلا ملفات محفوظة).
AppState _freshState() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppState(useIsolates: false);
}

/// حالة جديدة تقرأ نفس التخزين (محاكاة إعادة فتح التطبيق).
AppState _restart() => AppState(useIsolates: false);

Plan _dailyPlan({int startedDaysAgo = 10}) => Plan(
      id: 'p1',
      title: 'قراءة كتاب',
      startDate: Dates.addDays(Dates.today(), -startedDaysAgo),
      repeatType: RepeatType.daily,
      startMinutes: 20 * 60,
      durationMinutes: 30,
    );

bool _hasPlanTaskOn(AppState app, DateTime day) =>
    app.tasksOn(day).any((Task t) => t.planId == 'p1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('مهام الخطط تبقى بعد إعادة فتح التطبيق', () {
    test('لا تُحذف نسخ الخطة عند الإقلاع (اليوم والأيام القادمة)', () async {
      final AppState app = _freshState();
      await app.init();
      await app.upsertPlan(_dailyPlan());
      await app.flush();

      expect(_hasPlanTaskOn(app, Dates.today()), isTrue, reason: 'وُلّدت نسخة اليوم');
      expect(_hasPlanTaskOn(app, Dates.addDays(Dates.today(), 1)), isTrue);

      // إعادة فتح التطبيق: كانت النسخ تُحذف كلها هنا.
      final AppState again = _restart();
      await again.init();

      expect(_hasPlanTaskOn(again, Dates.today()), isTrue, reason: 'نسخة اليوم باقية');
      expect(
        _hasPlanTaskOn(again, Dates.addDays(Dates.today(), 1)),
        isTrue,
        reason: 'نسخة الغد باقية',
      );
      expect(
        _hasPlanTaskOn(again, Dates.addDays(Dates.today(), 7)),
        isTrue,
        reason: 'نسخة الأسبوع القادم باقية',
      );
    });

    test('الإقلاع يعيد توليد النسخ الناقصة (علاج ما حُذف سابقًا)', () async {
      final AppState app = _freshState();
      await app.init();
      await app.upsertPlan(_dailyPlan());
      await app.flush();

      // نحذف كل المهام من التخزين لمحاكاة الضرر القديم.
      final Map<String, dynamic> data = app.repo.read();
      data['tasks'] = <dynamic>[];
      await app.repo.write(data);

      final AppState again = _restart();
      await again.init();

      expect(_hasPlanTaskOn(again, Dates.today()), isTrue);
      expect(_hasPlanTaskOn(again, Dates.addDays(Dates.today(), 1)), isTrue);
    });

    test('حذف نسخة خطة لا تعود عند إعادة التشغيل', () async {
      final AppState app = _freshState();
      await app.init();
      await app.upsertPlan(_dailyPlan());
      await app.flush();

      final Task today = app
          .tasksOn(Dates.today())
          .firstWhere((Task t) => t.planId == 'p1');
      await app.deleteTask(today.id);
      await app.flush();

      final AppState again = _restart();
      await again.init();

      expect(again.taskById(today.id), isNull, reason: 'لا تعود بعد الحذف');
      expect(_hasPlanTaskOn(again, Dates.addDays(Dates.today(), 1)), isTrue);
    });

    test('تأجيل نسخة خطة لا يُنتج نسخة مكرّرة', () async {
      final AppState app = _freshState();
      await app.init();
      await app.upsertPlan(_dailyPlan());
      await app.flush();

      final Task today = app
          .tasksOn(Dates.today())
          .firstWhere((Task t) => t.planId == 'p1');
      await app.moveTaskToTomorrow(today.id);
      await app.flush();

      final AppState again = _restart();
      await again.init();

      final DateTime tomorrow = Dates.addDays(Dates.today(), 1);
      expect(again.tasksOn(Dates.today()).any((Task t) => t.planId == 'p1'), isFalse,
          reason: 'اليوم الأصلي صار متخطّى');
      expect(_hasPlanTaskOn(again, tomorrow), isTrue, reason: 'نسخة الغد من الخطة موجودة');
      expect(
        again.tasksOn(tomorrow).where((Task t) => t.planId == 'p1').length,
        1,
        reason: 'نسخة واحدة فقط من الخطة في الغد (لا تكرار)',
      );
      final Task postponed = again.taskById(today.id)!;
      expect(postponed.planId, isNull, reason: 'المهمة المؤجَّلة صارت مستقلة');
      expect(Dates.sameDay(postponed.date, tomorrow), isTrue);
    });
  });

  group('تذكير نهاية اليوم', () {
    List<PlannedReminder> build({
      required List<Task> tasks,
      int eveningMinutes = 21 * 60,
      int nowMinutes = 8 * 60,
    }) {
      final AppSettings settings = AppSettings(
        eveningEnabled: true,
        eveningMinutes: eveningMinutes,
        morningEnabled: false,
        createdAt: DateTime.now(),
      );
      return ReminderPlanner.build(
        settings: settings,
        tasks: tasks,
        l10n: AppLocalizations.ofLocale(const Locale('ar')),
        idFor: (String key) => key.hashCode,
        categoryName: (String id) => 'عام',
        now: Dates.at(Dates.today(), nowMinutes),
        windowDays: 1,
      );
    }

    PlannedReminder reviewOf(List<PlannedReminder> list) =>
        list.firstWhere((PlannedReminder r) => r.kind == ReminderKind.review);

    test('يسرد ما لم يُنجز اليوم', () {
      final List<PlannedReminder> planned = build(tasks: <Task>[
        Task(id: 't1', title: 'مهمة منجزة', date: Dates.today(), done: true),
        Task(id: 't2', title: 'مهمة معلّقة', date: Dates.today()),
      ]);
      final PlannedReminder review = reviewOf(planned);
      expect(review.lines.any((String l) => l.contains('مهمة معلّقة')), isTrue);
      expect(review.lines.any((String l) => l.contains('مهمة منجزة')), isFalse);
      expect(review.body.contains('1'), isTrue, reason: 'المتبقي = ١');
    });

    test('يذكر المتأخّرة من الأيام السابقة (كان فرعًا ميتًا)', () {
      final List<PlannedReminder> planned = build(tasks: <Task>[
        Task(id: 't1', title: 'متأخرة أمس', date: Dates.addDays(Dates.today(), -1)),
        Task(id: 't2', title: 'متأخرة الأسبوع', date: Dates.addDays(Dates.today(), -7)),
        Task(id: 't3', title: 'قديمة جدًا', date: Dates.addDays(Dates.today(), -90)),
        Task(id: 't4', title: 'معلّقة اليوم', date: Dates.today()),
        Task(id: 't5', title: 'مستقبلية', date: Dates.addDays(Dates.today(), 3)),
      ]);
      final PlannedReminder review = reviewOf(planned);
      final String all = review.lines.join('\n');

      expect(all.contains('متأخرة أمس'), isTrue);
      expect(all.contains('متأخرة الأسبوع'), isTrue);
      expect(all.contains('متأخرة'), isTrue);
      expect(all.contains('قديمة جدًا'), isFalse, reason: 'أقدم من ٦٠ يومًا لا تُذكر');
      expect(all.contains('مستقبلية'), isFalse);
      expect(review.body.contains('3'), isTrue,
          reason: 'المتبقي = ٣ (متأخرتان + مهمة اليوم)');
    });

    test('المتأخّرة المنجزة أو المتخطّاة لا تُذكر', () {
      final List<PlannedReminder> planned = build(tasks: <Task>[
        Task(id: 't1', title: 'منجزة متأخرة', date: Dates.addDays(Dates.today(), -1), done: true),
        Task(id: 't2', title: 'متخطّاة', date: Dates.addDays(Dates.today(), -2), skipped: true),
      ]);
      final PlannedReminder review = reviewOf(planned);
      expect(review.lines.join('\n').contains('منجزة متأخرة'), isFalse);
      expect(review.lines.join('\n').contains('متخطّاة'), isFalse);
      expect(review.body, isNotEmpty);
    });
  });
}
