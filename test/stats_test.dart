import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/core/models/day_note.dart';
import 'package:gunluk/core/models/plan.dart';
import 'package:gunluk/core/models/stats.dart';
import 'package:gunluk/core/models/task.dart';
import 'package:gunluk/core/utils/dates.dart';

Task _task({
  required String id,
  required DateTime date,
  String categoryId = 'general',
  bool done = false,
  bool skipped = false,
  DateTime? completedAt,
  int? startMinutes,
  int durationMinutes = 0,
  String planId = '',
}) =>
    Task(
      id: id,
      title: 'مهمة $id',
      date: date,
      categoryId: categoryId,
      done: done,
      skipped: skipped,
      completedAt: completedAt,
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      planId: planId.isEmpty ? null : planId,
    );

void main() {
  group('إحصاء اليوم', () {
    test('يجمع المنفَّذ والمُتخطّى والمتأخر والدقائق', () {
      final DateTime today = DateTime(2026, 5, 10);
      final List<Task> tasks = <Task>[
        _task(
          id: 'a',
          date: today,
          categoryId: 'study',
          done: true,
          completedAt: DateTime(2026, 5, 10, 9),
          startMinutes: 9 * 60,
          durationMinutes: 45,
        ),
        _task(id: 'b', date: today, startMinutes: 11 * 60, durationMinutes: 30),
        _task(id: 'c', date: today, skipped: true),
        _task(id: 'd', date: Dates.addDays(today, 2)),
      ];
      final DayStat stat = StatsEngine.dayStat(today, tasks, now: DateTime(2026, 5, 10, 12));
      expect(stat.total, 3);
      expect(stat.done, 1);
      expect(stat.skipped, 1);
      expect(stat.missed, 0);
      expect(stat.pending, 1);
      expect(stat.plannedMinutes, 75);
      expect(stat.doneMinutes, 45);
      expect(stat.rate, closeTo(1 / 3, 0.001));
      expect(stat.isPerfect, isFalse);
    });

    test('المهمة غير المنجزة قبل اليوم تُحسب متأخرة', () {
      final DateTime day = DateTime(2026, 5, 10);
      final DayStat stat = StatsEngine.dayStat(
        day,
        <Task>[_task(id: 'a', date: day)],
        now: DateTime(2026, 5, 12),
      );
      expect(stat.missed, 1);
      expect(stat.done, 0);
    });

    test('اليوم المثالي = إنجاز كل المهام', () {
      final DateTime day = DateTime(2026, 5, 10);
      final DayStat stat = StatsEngine.dayStat(
        day,
        <Task>[
          _task(id: 'a', date: day, done: true, completedAt: DateTime(2026, 5, 10, 8)),
          _task(id: 'b', date: day, done: true, completedAt: DateTime(2026, 5, 10, 20)),
        ],
        now: DateTime(2026, 5, 10, 21),
      );
      expect(stat.isPerfect, isTrue);
      expect(stat.rate, 1);
    });
  });

  group('ملخّص الفترة', () {
    late List<Task> tasks;
    late List<FocusSession> sessions;

    setUp(() {
      tasks = <Task>[
        _task(
          id: 'a',
          date: DateTime(2026, 1, 1),
          categoryId: 'study',
          done: true,
          completedAt: DateTime(2026, 1, 1, 9),
          startMinutes: 9 * 60,
          durationMinutes: 30,
        ),
        _task(
          id: 'b',
          date: DateTime(2026, 1, 2),
          categoryId: 'work',
          done: true,
          completedAt: DateTime(2026, 1, 2, 21),
        ),
        _task(id: 'c', date: DateTime(2026, 1, 3)),
      ];
      sessions = <FocusSession>[
        FocusSession(id: 'f1', start: DateTime(2026, 1, 2, 10), minutes: 25),
        FocusSession(id: 'f2', start: DateTime(2025, 12, 30, 10), minutes: 10),
      ];
    });

    StatsSummary summary() => StatsEngine.summarize(
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 1, 3),
          allTasks: tasks,
          sessions: sessions,
          allTasksForStreak: tasks,
          now: DateTime(2026, 1, 5, 8),
        );

    test('الإجماليات والنِسب', () {
      final StatsSummary s = summary();
      expect(s.days.length, 3);
      expect(s.total, 3);
      expect(s.done, 2);
      expect(s.missed, 1);
      expect(s.skipped, 0);
      expect(s.rate, closeTo(2 / 3, 0.001));
      expect(s.perfectDays, 2, reason: 'يومان أُنجزت فيهما كل المهام');
      expect(s.averagePerDay, 1, reason: '٢ إنجاز ÷ ٣ أيام = ١');
      expect(s.hasData, isTrue);
    });

    test('التوزيع حسب الفئة والساعة واليوم', () {
      final StatsSummary s = summary();
      expect(s.doneByCategory['study'], 1);
      expect(s.doneByCategory['work'], 1);
      expect(s.doneByHour[9], 1);
      expect(s.doneByHour[21], 1);
      expect(s.doneByWeekday[DateTime.thursday], 1);
      expect(s.doneByWeekday[DateTime.friday], 1);
      expect(s.topCategory, isNotEmpty);
      expect(s.topHour, isNotNull);
      expect(s.bestDay, DateTime(2026, 1, 1));
    });

    test('دقائق التركيز داخل الفترة فقط', () {
      final StatsSummary s = summary();
      expect(s.focusMinutes, 25);
    });

    test('مجموع النقاط يساوي نقاط المهام المنجزة', () {
      final StatsSummary s = summary();
      final int expected = tasks.where((Task t) => t.done).fold(0, (int sum, Task t) => sum + t.xp);
      expect(s.totalXp, expected);
      expect(s.totalXp, greaterThan(0));
    });

    test('ملخّص فارغ لا ينكسر', () {
      final StatsSummary s = StatsEngine.summarize(
        from: DateTime(2026, 2, 1),
        to: DateTime(2026, 2, 3),
        allTasks: const <Task>[],
        sessions: const <FocusSession>[],
        allTasksForStreak: const <Task>[],
        now: DateTime(2026, 2, 4),
      );
      expect(s.total, 0);
      expect(s.rate, 0);
      expect(s.hasData, isFalse);
      expect(s.averagePerDay, 0);
      expect(s.bestDay, isNull);
      expect(s.topHour, isNull);
    });
  });

  group('السلاسل', () {
    test('السلسلة الحالية تتجاهل الأيام الفارغة وتتوقف عند يوم ناقص', () {
      final List<Task> tasks = <Task>[
        _task(id: 'a', date: DateTime(2026, 1, 5), done: true, completedAt: DateTime(2026, 1, 5, 9)),
        _task(id: 'b', date: DateTime(2026, 1, 4), done: true, completedAt: DateTime(2026, 1, 4, 9)),
        _task(id: 'c', date: DateTime(2026, 1, 3), done: false),
        _task(id: 'd', date: DateTime(2026, 1, 1), done: true, completedAt: DateTime(2026, 1, 1, 9)),
      ];
      expect(StatsEngine.currentStreak(tasks, now: DateTime(2026, 1, 5, 12)), 2);
    });

    test('إن لم يُنجز اليوم شيء تبدأ السلسلة من الأمس', () {
      final List<Task> tasks = <Task>[
        _task(id: 'a', date: DateTime(2026, 1, 5)),
        _task(id: 'b', date: DateTime(2026, 1, 4), done: true, completedAt: DateTime(2026, 1, 4, 9)),
      ];
      expect(StatsEngine.currentStreak(tasks, now: DateTime(2026, 1, 5, 12)), 1);
    });

    test('أطول سلسلة تُحسب من كل السجل', () {
      final List<Task> tasks = <Task>[
        for (int d = 1; d <= 3; d++)
          _task(id: 'a$d', date: DateTime(2026, 1, d), done: true, completedAt: DateTime(2026, 1, d, 9)),
        _task(id: 'b', date: DateTime(2026, 1, 10), done: true, completedAt: DateTime(2026, 1, 10, 9)),
        _task(id: 'c', date: DateTime(2026, 1, 11), done: false),
      ];
      expect(StatsEngine.bestStreak(tasks), 3);
      expect(StatsEngine.bestStreak(const <Task>[]), 0);
    });
  });

  group('إحصاءات الخطة (أيام الدوام)', () {
    Plan plan() => Plan(
          id: 'p1',
          title: 'دوام',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 7),
          repeatType: RepeatType.daily,
        );

    PlanStats stats({List<Task> tasks = const <Task>[]}) => StatsEngine.planStats(
          plan: plan(),
          tasks: tasks,
          workDays: <int>{
            DateTime.sunday,
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
          },
          now: DateTime(2026, 1, 4, 12),
        );

    test('عدد أيام الدوام وأيام الراحة في الخطة', () {
      final PlanStats s = stats();
      expect(s.spanDays, 7);
      expect(s.scheduledTotal, 7);
      expect(s.workDays, 5, reason: 'الخميس والأحد والاثنين والثلاثاء والأربعاء');
      expect(s.restDays, 2, reason: 'الجمعة والسبت');
      expect(s.workDays + s.restDays, s.scheduledTotal);
    });

    test('المنجز والمتأخر والقادم والموعد القادم', () {
      final PlanStats s = stats();
      expect(s.doneCount, 0);
      expect(s.missedCount, 3, reason: '١–٣ يناير انتهت ولم تُنجز');
      expect(s.upcomingCount, 3, reason: '٥–٧ يناير لم يحن وقتها');
      expect(s.remainingCount, 4);
      expect(s.next, DateTime(2026, 1, 4));
      expect(s.adherence, greaterThanOrEqualTo(0));
      expect(s.adherence, lessThanOrEqualTo(1));
    });

    test('مهام الخطة المنجزة ترفع الالتزام', () {
      final List<Task> tasks = <Task>[
        _task(id: 'po_p1_2026-01-01', date: DateTime(2026, 1, 1), done: true, planId: 'p1'),
        _task(id: 'po_p1_2026-01-02', date: DateTime(2026, 1, 2), done: true, planId: 'p1'),
      ];
      final PlanStats s = stats(tasks: tasks);
      expect(s.doneCount, 2);
      expect(s.missedCount, 1);
      expect(s.adherence, closeTo(2 / 3, 0.01));
      expect(s.streak, 0, reason: 'اليوم الحالي لم يُنجز بعد');
    });
  });
}
