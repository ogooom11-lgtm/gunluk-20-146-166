import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/core/l10n/app_strings.dart';
import 'package:gunluk/core/models/app_settings.dart';
import 'package:gunluk/core/models/planned_reminder.dart';
import 'package:gunluk/core/models/task.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:gunluk/data/reminder_planner.dart';
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

List<PlannedReminder> _plan(AppSettings settings, List<Task> tasks) => ReminderPlanner.build(
      settings: settings,
      tasks: tasks,
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
}
