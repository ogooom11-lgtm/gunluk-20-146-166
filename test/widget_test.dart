import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/l10n/app_strings.dart';
import 'package:gunluk/core/models/stats.dart';
import 'package:gunluk/core/models/task.dart';
import 'package:gunluk/core/utils/dates.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:gunluk/theme/app_theme.dart';
import 'package:gunluk/theme/palettes.dart';
import 'package:gunluk/ui/app_scope.dart';
import 'package:gunluk/ui/widgets/charts.dart';
import 'package:gunluk/ui/widgets/common.dart';
import 'package:gunluk/ui/widgets/progress_ring.dart';
import 'package:gunluk/ui/widgets/task_tile.dart';

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

List<DayStat> _weekStats() => <DayStat>[
      for (int i = 6; i >= 0; i--)
        DayStat(
          day: Dates.addDays(Dates.today(), -i),
          total: 4,
          done: i.isEven ? 3 : 1,
          missed: i.isEven ? 1 : 2,
          skipped: 0,
          plannedMinutes: 120,
          doneMinutes: 90,
        ),
    ];

void main() {
  testWidgets('البطاقات والعناصر الأساسية تُرسم وتستجيب للمس', (WidgetTester tester) async {
    final AppState app = AppState();
    int taps = 0;

    await tester.pumpWidget(
      _harness(
        app,
        Column(
          children: <Widget>[
            AppCard(onTap: () => taps++, child: const Text('بطاقة')),
            const Pill(label: 'وسم'),
            EmptyState(
              icon: Icons.star_rounded,
              title: 'لا يوجد شيء',
              message: 'أضف أول عنصر',
              actionLabel: 'إضافة',
              onAction: () => taps++,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بطاقة'), findsOneWidget);
    expect(find.text('وسم'), findsOneWidget);
    expect(find.text('لا يوجد شيء'), findsOneWidget);

    await tester.tap(find.text('بطاقة'));
    await tester.tap(find.text('إضافة'));
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('صف المهمة وحلقة التقدّم يعرضان المحتوى', (WidgetTester tester) async {
    final AppState app = AppState();
    final Task task = Task(id: 't1', title: 'مراجعة الدرس', date: Dates.today());

    await tester.pumpWidget(
      _harness(
        app,
        Column(
          children: <Widget>[
            TaskTile(task: task, enableSwipe: false),
            ProgressRing(
              value: 0.4,
              size: 90,
              child: const Text('٤٠٪'),
            ),
            const AppLogomark(size: 64),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مراجعة الدرس'), findsOneWidget);
    expect(find.text('٤٠٪'), findsOneWidget);
  });

  testWidgets('الرسوم البيانية تُرسم بدون أخطاء', (WidgetTester tester) async {
    final AppState app = AppState();
    final List<DayStat> week = _weekStats();

    await tester.pumpWidget(
      _harness(
        app,
        SingleChildScrollView(
          child: Column(
            children: <Widget>[
              WeekBars(days: week, labels: <String>['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج']),
              HourBars(hourCounts: <int, int>{6: 1, 9: 3, 21: 2}),
              DonutChart(
                values: <String, int>{'study': 3, 'work': 2},
                colors: <String, Color>{'study': Colors.blue, 'work': Colors.green},
                center: const Text('٥'),
              ),
              Heatmap(days: week),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeekBars), findsOneWidget);
    expect(find.byType(DonutChart), findsOneWidget);
    expect(find.byType(Heatmap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('السمة والألوان تُبنى لكل الأوضاع', (WidgetTester tester) async {
    final AppState app = AppState();
    expect(AppTheme.light(app.settings).brightness, Brightness.light);
    expect(AppTheme.dark(app.settings).brightness, Brightness.dark);
    expect(AppTheme.palette(app.settings).seed, Palettes.all.first.seed);
    expect(Palettes.all.length, greaterThanOrEqualTo(6));

    await tester.pumpWidget(_harness(app, const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('الترجمة تعمل بالعربية والإنجليزية', (WidgetTester tester) async {
    final AppState app = AppState();
    await tester.pumpWidget(_harness(app, const Text('مرحبا')));
    await tester.pumpAndSettle();
    final BuildContext context = tester.element(find.byType(Scaffold));
    expect(context.langCode, 'ar');
    expect(context.isArabic, isTrue);
    expect(context.tr('app.name'), 'إنجازي');
    expect(context.tr('nav.home'), isNotEmpty);
    expect(context.tr('settings.title'), isNotEmpty);
    expect(context.numStr(7), isNotEmpty);
    expect(context.durStr(90), isNotEmpty);
  });
}
