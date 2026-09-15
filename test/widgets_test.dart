import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/core/l10n/app_strings.dart';
import 'package:gunluk/core/models/task.dart';
import 'package:gunluk/core/utils/dates.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:gunluk/theme/app_theme.dart';
import 'package:gunluk/ui/app_scope.dart';
import 'package:gunluk/ui/widgets/common.dart';
import 'package:gunluk/ui/widgets/confetti.dart';
import 'package:gunluk/ui/widgets/day_timeline.dart';
import 'package:gunluk/ui/widgets/month_calendar.dart';
import 'package:gunluk/ui/widgets/quick_add_sheet.dart';
import 'package:gunluk/ui/widgets/settings_tiles.dart';

/// غلاف اختبار: تطبيق مصغّر بالعربية مع مزوّد النصوص وحالة التطبيق.
Widget _harness(AppState app, Widget child) => AppScope(
      // مثل main.dart: النطاق أعلى MaterialApp حتى تراه المسارات المنبثقة (الأوراق والحوارات).
      state: app,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(app.settings),
        home: Scaffold(body: child),
      ),
    );

Task _timed(String id, String title, int start, {int duration = 60, bool done = false}) => Task(
      id: id,
      title: title,
      date: Dates.today(),
      startMinutes: start,
      durationMinutes: duration,
      priority: TaskPriority.high,
      done: done,
    );

void main() {
  testWidgets('التقويم الشهري وشريط الأسبوع يُرسمان ويسجّلان النقر', (WidgetTester tester) async {
    final AppState app = AppState();
    DateTime? selected;

    await tester.pumpWidget(
      _harness(
        app,
        SingleChildScrollView(
          child: Column(
            children: <Widget>[
              MonthCalendar(
                month: DateTime(Dates.today().year, Dates.today().month),
                selectedDay: Dates.today(),
                onSelectDay: (DateTime day) => selected = day,
              ),
              WeekStrip(
                selectedDay: Dates.today(),
                onSelectDay: (DateTime day) => selected = day,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MonthCalendar), findsOneWidget);
    expect(find.byType(WeekStrip), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(of: find.byType(WeekStrip), matching: find.byType(GestureDetector)).first,
    );
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
  });

  testWidgets('الخط الزمني يعرض المهام الموقوتة بدون أخطاء', (WidgetTester tester) async {
    final AppState app = AppState();
    final List<Task> tasks = <Task>[
      _timed('t1', 'اجتماع الفريق', 9 * 60, duration: 60),
      _timed('t2', 'قراءة', 21 * 60, duration: 30, done: true),
      Task(id: 't3', title: 'مهمة بلا وقت', date: Dates.today()),
    ];

    await tester.pumpWidget(
      _harness(
        app,
        SizedBox(
          height: 500,
          child: DayTimeline(day: Dates.today(), tasks: tasks),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DayTimeline), findsOneWidget);
    expect(find.text('اجتماع الفريق'), findsOneWidget);
    expect(find.text('مهمة بلا وقت'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('عناصر الإعدادات والعناصر المشتركة تعمل', (WidgetTester tester) async {
    final AppState app = AppState();
    bool switched = false;

    await tester.pumpWidget(
      _harness(
        app,
        ListView(
          children: <Widget>[
            const SectionHeader(title: 'قسم', subtitle: 'وصف', icon: Icons.list_rounded),
            const StatTile(label: 'عدد', value: '٧', caption: 'هذا الأسبوع'),
            const ThinProgress(value: 0.5),
            SettingsGroup(
              title: 'مجموعة',
              children: <Widget>[
                SettingsSwitchTile(
                  title: 'تذكير',
                  subtitle: 'وصف المفتاح',
                  value: false,
                  onChanged: (bool value) => switched = value,
                ),
                SettingsValueTile(title: 'الوقت', value: '٩:٠٠ م', onTap: () {}),
                SettingsTile(title: 'عنصر', trailing: const Icon(Icons.chevron_left_rounded)),
                DangerTile(title: 'حذف المهمة', onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مجموعة'), findsOneWidget);
    expect(find.text('٩:٠٠ م'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(switched, isTrue);
  });

  testWidgets('ورقة الإضافة السريعة تُفتح وتُغلق', (WidgetTester tester) async {
    final AppState app = AppState();

    await tester.pumpWidget(
      _harness(
        app,
        Builder(
          builder: (BuildContext context) => Center(
            child: FilledButton(
              onPressed: () => showQuickAddSheet(context, day: Dates.today()),
              child: const Text('إضافة'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('إضافة'), findsWidgets);
  });

  testWidgets('قصاصات الاحتفال تُرسم وتنتهي بدون أخطاء', (WidgetTester tester) async {
    final AppState app = AppState();
    bool finished = false;

    await tester.pumpWidget(
      _harness(
        app,
        ConfettiOverlay(play: true, pieces: 12, onDone: () => finished = true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(finished, isTrue);
  });
}
