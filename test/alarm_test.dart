import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/core/l10n/app_strings.dart';
import 'package:gunluk/core/models/app_settings.dart';
import 'package:gunluk/core/models/day_note.dart';
import 'package:gunluk/core/models/planned_reminder.dart';
import 'package:gunluk/core/models/task.dart';
import 'package:gunluk/data/app_repository.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:gunluk/data/reminder_planner.dart';
import 'package:gunluk/services/notification_service.dart';
import 'package:gunluk/theme/app_theme.dart';
import 'package:gunluk/ui/app_scope.dart';
import 'package:gunluk/ui/screens/alarm_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الآن المرجعي: يوم ثابت الساعة ٠٨:٠٠ حتى تكون النتائج قابلة للتكرار.
final DateTime _now = DateTime(2026, 9, 17, 8, 0);

AppState _state() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppState(useIsolates: false, pinIterations: 500, clock: () => _now);
}

Task _urgent({String id = 't1', int? start = 600, String title = 'تسليم التقرير'}) => Task(
      id: id,
      title: title,
      date: DateTime(2026, 9, 17),
      priority: TaskPriority.urgent,
      startMinutes: start,
      notes: 'ملاحظات سرية عن التسليم',
    );

List<PlannedReminder> _plan(
  AppSettings settings,
  List<Task> tasks, {
  List<DayNote> notes = const <DayNote>[],
}) =>
    ReminderPlanner.build(
      settings: settings,
      tasks: tasks,
      notes: notes,
      l10n: AppLocalizations.ofLocale(const Locale('ar')),
      idFor: (String key) => key.hashCode & 0x3FFFFFF,
      categoryName: (String _) => 'عام',
      now: _now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('منبّه المهام العاجلة (الجدولة)', () {
    test('المهمة العاجلة تُنتج منبّهًا في وقتها بشاشة كاملة', () {
      final List<PlannedReminder> list = _plan(AppSettings(), <Task>[_urgent()]);
      final PlannedReminder alarm =
          list.firstWhere((PlannedReminder r) => r.kind == ReminderKind.alarm);

      expect(alarm.when, DateTime(2026, 9, 17, 10, 0));
      expect(alarm.fullScreen, isTrue, reason: 'المنبّه يفتح شاشة كاملة');
      expect(alarm.taskId, 't1');
      expect(alarm.payload, contains('"o":"alarm"'));
    });

    test('الخصوصية: الإشعار لا يكشف اسم المهمة', () {
      final List<PlannedReminder> list = _plan(AppSettings(), <Task>[_urgent()]);
      final PlannedReminder alarm =
          list.firstWhere((PlannedReminder r) => r.kind == ReminderKind.alarm);

      expect(alarm.title, 'منبّه');
      expect(alarm.title.contains('تسليم'), isFalse);
      expect(alarm.body.contains('تسليم'), isFalse);
      expect(alarm.body.contains('ملاحظات'), isFalse);
    });

    test('إظهار التفاصيل عند إيقاف الإخفاء يعرض الاسم', () {
      final List<PlannedReminder> list = _plan(
        AppSettings()..alarmHideDetails = false,
        <Task>[_urgent()],
      );
      final PlannedReminder alarm =
          list.firstWhere((PlannedReminder r) => r.kind == ReminderKind.alarm);
      expect(alarm.title, 'تسليم التقرير');
    });

    test('المهمة غير العاجلة لا تُنتج منبّهًا', () {
      final Task normal = Task(
        id: 't2',
        title: 'مهمة عادية',
        date: DateTime(2026, 9, 17),
        priority: TaskPriority.high,
        startMinutes: 600,
      );
      final List<PlannedReminder> list = _plan(AppSettings(), <Task>[normal]);
      expect(list.where((PlannedReminder r) => r.kind == ReminderKind.alarm), isEmpty);
    });

    test('إيقاف المنبّه من الإعدادات يمنع جدولته', () {
      final List<PlannedReminder> list = _plan(
        AppSettings()..alarmEnabled = false,
        <Task>[_urgent()],
      );
      expect(list.where((PlannedReminder r) => r.kind == ReminderKind.alarm), isEmpty);
    });

    test('مدد التأجيل المتاحة تشمل ١ و٥ و١٠ و١٥ و٣٠', () {
      expect(AppSettings.alarmSnoozeOptions, <int>[1, 5, 10, 15, 30]);
      expect(AppSettings().alarmSnoozeMinutes, 5);
    });

    test('الإعدادات الجديدة تُرمَّز وتُفكّ', () {
      final AppSettings s = AppSettings()
        ..alarmEnabled = false
        ..alarmHideDetails = false
        ..alarmRequireUnlock = false
        ..alarmSnoozeMinutes = 15;
      final AppSettings back = AppSettings.fromJson(s.toJson());
      expect(back.alarmEnabled, isFalse);
      expect(back.alarmHideDetails, isFalse);
      expect(back.alarmRequireUnlock, isFalse);
      expect(back.alarmSnoozeMinutes, 15);
      // الإعدادات القديمة: المنبّه مفعّل والتفاصيل مخفية افتراضيًا.
      final AppSettings legacy = AppSettings.fromJson(<String, dynamic>{});
      expect(legacy.alarmEnabled, isTrue);
      expect(legacy.alarmHideDetails, isTrue);
    });
  });

  group('حالة التطبيق مع المنبّه', () {
    test('الفتح والإغلاق والإنجاز', () async {
      final AppState app = _state();
      await app.repo.ensure();
      final Task task = _urgent();
      app.tasks.add(task);

      app.openAlarm(task.id);
      expect(app.activeAlarmTaskId, task.id);
      expect(app.activeAlarmTask?.title, 'تسليم التقرير');

      await app.completeAlarm();
      expect(app.activeAlarmTaskId, isNull, reason: 'أُغلقت شاشة المنبّه');
      expect(task.done, isTrue, reason: 'المهمة أُنجزت من المنبّه');
    });

    test('فتح منبّه لمهمة غير موجودة لا يفعل شيئًا', () async {
      final AppState app = _state();
      await app.repo.ensure();
      app.openAlarm('missing');
      expect(app.activeAlarmTaskId, isNull);
    });
  });

  group('شاشة المنبّه', () {
    Widget harness(AppState app, String taskId) => AppScope(
          state: app,
          child: MaterialApp(
            theme: AppTheme.light(app.settings),
            locale: const Locale('ar'),
            home: TickerMode(enabled: false, child: AlarmScreen(taskId: taskId)),
          ),
        );

    testWidgets('قبل التحقّق: «منبّه» فقط بلا اسم ولا وصف', (WidgetTester tester) async {
      final AppState app = _state();
      await app.repo.ensure();
      final Task task = _urgent();
      app.tasks.add(task);

      await tester.pumpWidget(harness(app, task.id));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('منبّه'), findsWidgets);
      expect(find.text('إظهار التفاصيل'), findsOneWidget);
      expect(find.text('تأجيل'), findsOneWidget);
      expect(find.text('إنجاز'), findsNothing, reason: 'الإنجاز بعد التحقّق فقط');
      expect(find.text('تسليم التقرير'), findsNothing, reason: 'الاسم مخفي');
      expect(find.textContaining('ملاحظات سرية'), findsNothing, reason: 'الوصف مخفي');

      app.dispose();
    });

    testWidgets('بعد إيقاف الإخفاء وإظهار التفاصيل يظهر الاسم والوصف والإنجاز',
        (WidgetTester tester) async {
      final AppState app = _state();
      await app.repo.ensure();
      // إيقاف اشتراط التحقّق: زر «إظهار التفاصيل» يكشف مباشرة.
      await app.updateSettings(app.settings.copyWith(alarmRequireUnlock: false));
      final Task task = _urgent();
      app.tasks.add(task);

      await tester.pumpWidget(harness(app, task.id));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey<String>('alarm_reveal')));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      // الاسم يظهر في العنوان وفي البطاقة معًا بعد الكشف.
      expect(find.text('تسليم التقرير'), findsWidgets);
      expect(find.textContaining('ملاحظات سرية'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('alarm_done')), findsOneWidget);

      app.dispose();
    });

    testWidgets('زر التأجيل يفتح مدد التأجيل', (WidgetTester tester) async {
      final AppState app = _state();
      await app.repo.ensure();
      final Task task = _urgent();
      app.tasks.add(task);

      await tester.pumpWidget(harness(app, task.id));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey<String>('alarm_snooze')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('تأجيل المنبّه'), findsOneWidget);
      // كل مدد التأجيل معروضة كأزرار (النص يتغيّر مع الأرقام العربية/اللاتينية).
      expect(find.byType(ActionChip), findsNWidgets(AppSettings.alarmSnoozeOptions.length));
      expect(find.text('دقيقة واحدة'), findsOneWidget);
      expect(find.textContaining('دقيقة'), findsWidgets);

      app.dispose();
    });
  });

  group('تقييم اليوم', () {
    test('التقييم يُحفظ ويُقرأ (مع الحفاظ على الملاحظة)', () async {
      final AppState app = _state();
      await app.repo.ensure();
      final DateTime day = DateTime(2026, 9, 17);

      expect(app.ratingFor(day), -1, reason: 'لا تقييم بعد');
      await app.saveNote(day, 'ملاحظة اليوم', 3);
      expect(app.ratingFor(day), 3);
      expect(app.noteFor(day)?.text, 'ملاحظة اليوم');

      // تقييم بلا مساس بالملاحظة.
      await app.rateDay(day, 1);
      expect(app.ratingFor(day), 1);
      expect(app.noteFor(day)?.text, 'ملاحظة اليوم');
    });

    test('متوسط الشهر وعدد الأيام المُقيَّمة', () async {
      final AppState app = _state();
      await app.repo.ensure();
      await app.rateDay(DateTime(2026, 9, 1), 4);
      await app.rateDay(DateTime(2026, 9, 2), 2);
      await app.rateDay(DateTime(2026, 8, 20), 4);
      await app.saveNote(DateTime(2026, 9, 3), 'بلا تقييم', -1);

      // المتوسط بمقياس ١..٥: (٥ + ٣) / 2 = 4.0
      expect(app.averageRating(2026, 9), 4.0);
      expect(app.ratedCountIn(2026, 9), 2);
      expect(app.averageRating(2026, 8), 5.0);
      expect(app.averageRating(2026, 7), isNull);
    });

    test('تذكير «قيّم يومك» يُجدول مرة واحدة يوميًا', () {
      final List<PlannedReminder> list = _plan(AppSettings(), <Task>[]);
      final Iterable<PlannedReminder> ratings =
          list.where((PlannedReminder r) => r.kind == ReminderKind.rating);
      expect(ratings.length, 16, reason: 'يوم واحد لكل يوم في نافذة الجدولة');
      final PlannedReminder first = ratings.first;
      expect(first.when.hour, 21);
      expect(first.when.minute, 30);
      expect(first.payload, contains('"o":"rate"'));
    });

    test('لا تذكير إن كان اليوم مُقيَّمًا أو الخيار موقوفًا', () async {
      final List<PlannedReminder> withRating = _plan(
        AppSettings(),
        <Task>[],
        notes: <DayNote>[DayNote(day: '2026-09-17', mood: 4)],
      );
      expect(
        withRating.firstWhere((PlannedReminder r) => r.kind == ReminderKind.rating).when.day,
        18,
        reason: 'اليوم المُقيَّم لا يُذكَّر فيه',
      );

      final AppSettings off = AppSettings()..ratingEnabled = false;
      final List<PlannedReminder> none = _plan(off, <Task>[]);
      expect(none.where((PlannedReminder r) => r.kind == ReminderKind.rating), isEmpty);
    });

    test('تقييم سريع من أزرار الإشعار يُطبَّق على اليوم', () async {
      final AppState app = _state();
      await app.repo.ensure();
      final AppRepository repo = app.repo;
      await repo.pushOp(<String, dynamic>{
        'op': 'rate',
        'value': 4,
        'day': '2026-09-17',
      });
      await app.applyPendingOps();
      expect(app.ratingFor(DateTime(2026, 9, 17)), 4);
      expect(NotifAction.ratingFor(NotifAction.rate5), 4);
      expect(NotifAction.ratingFor(NotifAction.rate1), 0);
      expect(NotifAction.ratingFor(NotifAction.rate3), 2);
    });
  });

  group('القفل عند مغادرة التطبيق', () {
    test('يقفل بعد انتهاء مهلة السماح', () async {
      final AppState app = _state();
      await app.repo.ensure();
      await app.setLockPassword('1234');
      await app.updateSettings(app.settings.copyWith(
        lockWhenBackground: true,
        lockGraceSeconds: 0,
      ));
      expect(app.locked, isFalse, reason: 'الفتح بعد التعيين مباشرة');

      app.handleBackgrounded();
      expect(app.locked, isTrue, reason: 'مهلة صفر ⇒ قفل فوري');

      app.handleResumed();
      expect(app.locked, isTrue);
    });

    test('مهلة ٣٠ ثانية: لا يقفل قبل انتهائها', () async {
      final AppState app = _state();
      await app.repo.ensure();
      await app.setLockPassword('1234');
      await app.updateSettings(app.settings.copyWith(
        lockWhenBackground: true,
        lockGraceSeconds: 30,
      ));

      app.handleBackgrounded();
      expect(app.locked, isFalse);
      // عودة سريعة ⇒ يبقى مفتوحًا.
      app.handleResumed();
      expect(app.locked, isFalse);
    });

    test('مؤقّت القفل يعمل حتى لو لم يعد التطبيق للواجهة', () async {
      final AppState app = _state();
      await app.repo.ensure();
      await app.setLockPassword('1234');
      await app.updateSettings(app.settings.copyWith(
        lockWhenBackground: true,
        lockGraceSeconds: 1,
      ));

      app.handleBackgrounded();
      expect(app.locked, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(app.locked, isTrue, reason: 'المؤقّت الداخلي قفل التطبيق');
      app.dispose();
    });

    test('حالة inactive القصيرة لا تقفل', () async {
      final AppState app = _state();
      await app.repo.ensure();
      await app.setLockPassword('1234');
      await app.updateSettings(app.settings.copyWith(
        lockWhenBackground: true,
        lockGraceSeconds: 0,
      ));

      app.handlePossiblyLeaving();
      expect(app.locked, isFalse, reason: 'لم يمضِ ٣ ثوانٍ بعد');
      app.handleResumed();
      await Future<void>.delayed(const Duration(milliseconds: 3500));
      expect(app.locked, isFalse, reason: 'العودة تُلغي العدّاد');
      app.dispose();
    });
  });

  group('منبّه التطبيق الداخلي', () {
    test('يرصد المهمة العاجلة التي حان وقتها مرة واحدة', () async {
      final AppState app = _state();
      await app.repo.ensure();
      app.tasks.add(_urgent(start: 480)); // 08:00 والآن 08:00

      final Task? due = app.dueAlarmTask();
      expect(due?.id, 't1');
      app.checkDueAlarm();
      expect(app.activeAlarmTaskId, 't1', reason: 'فُتح المنبّه داخل التطبيق');
      app.closeAlarm();
      app.checkDueAlarm();
      expect(app.activeAlarmTaskId, isNull, reason: 'لا يتكرّر في نفس اليوم');
    });

    test('لا منبّه لمهمة لم يحن وقتها أو غير عاجلة', () async {
      final AppState app = _state();
      await app.repo.ensure();
      app.tasks.add(_urgent(start: 900)); // 15:00
      expect(app.dueAlarmTask(), isNull);

      app.tasks.clear();
      final Task normal = Task(
        id: 't3',
        title: 'عادية',
        date: DateTime(2026, 9, 17),
        priority: TaskPriority.high,
        startMinutes: 480,
      );
      app.tasks.add(normal);
      expect(app.dueAlarmTask(), isNull);
    });
  });
}
