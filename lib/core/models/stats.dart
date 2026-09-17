import '../utils/dates.dart';
import 'day_note.dart';
import 'plan.dart';
import 'task.dart';

/// إحصاء يوم واحد.
class DayStat {
  const DayStat({
    required this.day,
    required this.total,
    required this.done,
    required this.missed,
    required this.skipped,
    required this.plannedMinutes,
    required this.doneMinutes,
  });

  final DateTime day;
  final int total;
  final int done;
  final int missed;
  final int skipped;
  final int plannedMinutes;
  final int doneMinutes;

  bool get isEmpty => total == 0;

  bool get isPerfect => total > 0 && done == total;

  double get rate => total == 0 ? 0 : done / total;

  int get pending => total - done - skipped;
}

/// ملخّص إحصائي لفترة زمنية.
class StatsSummary {
  const StatsSummary({
    required this.from,
    required this.to,
    required this.days,
    required this.total,
    required this.done,
    required this.missed,
    required this.skipped,
    required this.rate,
    required this.currentStreak,
    required this.bestStreak,
    required this.perfectDays,
    required this.doneByCategory,
    required this.doneByHour,
    required this.doneByWeekday,
    required this.focusMinutes,
    required this.bestDay,
    required this.bestDayCount,
    required this.totalXp,
  });

  final DateTime from;
  final DateTime to;
  final List<DayStat> days;
  final int total;
  final int done;
  final int missed;
  final int skipped;
  final double rate;
  final int currentStreak;
  final int bestStreak;
  final int perfectDays;
  final Map<String, int> doneByCategory;
  final Map<int, int> doneByHour;
  final Map<int, int> doneByWeekday;
  final int focusMinutes;
  final DateTime? bestDay;
  final int bestDayCount;
  final int totalXp;

  bool get hasData => total > 0 || focusMinutes > 0;

  int get averagePerDay => days.isEmpty ? 0 : (done / days.length).round();

  String get topCategory {
    String best = '';
    int bestValue = 0;
    doneByCategory.forEach((String key, int value) {
      if (value > bestValue) {
        bestValue = value;
        best = key;
      }
    });
    return best;
  }

  int? get topHour {
    int? best;
    int bestValue = 0;
    doneByHour.forEach((int key, int value) {
      if (value > bestValue) {
        bestValue = value;
        best = key;
      }
    });
    return best;
  }

  int? get topWeekday {
    int? best;
    int bestValue = 0;
    doneByWeekday.forEach((int key, int value) {
      if (value > bestValue) {
        bestValue = value;
        best = key;
      }
    });
    return best;
  }
}

/// إحصاءات خطة — تتضمّن عدد أيام الدوام وأيام الراحة (المطلوب: كم يوم دوام في الخطة).
class PlanStats {
  const PlanStats({
    required this.spanDays,
    required this.scheduledTotal,
    required this.workDays,
    required this.restDays,
    required this.doneCount,
    required this.missedCount,
    required this.skippedCount,
    required this.remainingCount,
    required this.upcomingCount,
    required this.adherence,
    required this.streak,
    required this.weekDone,
    required this.weekTotal,
    required this.next,
  });

  /// عدد أيام الخطة الكلية (من البداية إلى النهاية/اليوم).
  final int spanDays;

  /// عدد الأيام المجدولة فعليًا حسب التكرار.
  final int scheduledTotal;

  /// الأيام المجدولة التي تقع في أيام الدوام.
  final int workDays;

  /// الأيام المجدولة التي تقع في أيام الراحة.
  final int restDays;

  final int doneCount;
  final int missedCount;
  final int skippedCount;

  /// أيام مجدولة انتهى وقتها ولم تُنجز.
  final int remainingCount;

  /// أيام قادمة لم يحن وقتها بعد.
  final int upcomingCount;

  final double adherence;
  final int streak;
  final int weekDone;
  final int weekTotal;
  final DateTime? next;

  bool get finished => remainingCount == 0 && upcomingCount == 0;

  int get pastScheduled => doneCount + missedCount + skippedCount;
}

/// محرّك الإحصاءات — دوال خالصة (بدون حالة) لتسهيل الاختبار.
class StatsEngine {
  StatsEngine._();

  static DayStat dayStat(DateTime day, List<Task> tasks, {DateTime? now}) {
    final DateTime n = now ?? DateTime.now();
    int total = 0;
    int done = 0;
    int missed = 0;
    int skipped = 0;
    int planned = 0;
    int doneMinutes = 0;
    for (final Task t in tasks) {
      if (!Dates.sameDay(t.date, day)) continue;
      total++;
      if (t.hasTime && t.durationMinutes > 0) planned += t.durationMinutes;
      if (t.done) {
        done++;
        if (t.durationMinutes > 0) doneMinutes += t.durationMinutes;
      } else if (t.skipped) {
        skipped++;
      } else if (Dates.diffDays(t.date, n) > 0) {
        missed++;
      }
    }
    return DayStat(
      day: Dates.day(day),
      total: total,
      done: done,
      missed: missed,
      skipped: skipped,
      plannedMinutes: planned,
      doneMinutes: doneMinutes,
    );
  }

  static StatsSummary summarize({
    required DateTime from,
    required DateTime to,
    required List<Task> allTasks,
    required List<FocusSession> sessions,
    required List<Task> allTasksForStreak,
    DateTime? now,
  }) {
    final DateTime n = now ?? DateTime.now();
    final List<DayStat> days = <DayStat>[];
    int total = 0;
    int done = 0;
    int missed = 0;
    int skipped = 0;
    int perfect = 0;
    int focusMinutes = 0;
    final Map<String, int> byCategory = <String, int>{};
    final Map<int, int> byHour = <int, int>{};
    final Map<int, int> byWeekday = <int, int>{};
    DateTime? bestDay;
    int bestCount = 0;
    int xp = 0;

    DateTime cursor = Dates.day(from);
    final DateTime last = Dates.day(to);
    while (Dates.diffDays(cursor, last) >= 0) {
      final List<Task> dayTasks = allTasks.where((Task t) => Dates.sameDay(t.date, cursor)).toList();
      final DayStat stat = dayStat(cursor, dayTasks, now: n);
      days.add(stat);
      total += stat.total;
      done += stat.done;
      missed += stat.missed;
      skipped += stat.skipped;
      if (stat.isPerfect) perfect++;
      if (stat.done > bestCount) {
        bestCount = stat.done;
        bestDay = stat.day;
      }
      for (final Task t in dayTasks) {
        if (!t.done) continue;
        xp += t.xp;
        byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + 1;
        final DateTime when = t.completedAt ?? t.date;
        byHour[when.hour] = (byHour[when.hour] ?? 0) + 1;
        byWeekday[cursor.weekday] = (byWeekday[cursor.weekday] ?? 0) + 1;
      }
      cursor = Dates.addDays(cursor, 1);
    }

    for (final FocusSession s in sessions) {
      if (Dates.diffDays(from, s.start) >= 0 && Dates.diffDays(s.start, to) >= 0) {
        focusMinutes += s.minutes;
      }
    }

    return StatsSummary(
      from: Dates.day(from),
      to: Dates.day(to),
      days: days,
      total: total,
      done: done,
      missed: missed,
      skipped: skipped,
      rate: total == 0 ? 0 : done / total,
      currentStreak: currentStreak(allTasksForStreak, now: n),
      bestStreak: bestStreak(allTasksForStreak),
      perfectDays: perfect,
      doneByCategory: byCategory,
      doneByHour: byHour,
      doneByWeekday: byWeekday,
      focusMinutes: focusMinutes,
      bestDay: bestDay,
      bestDayCount: bestCount,
      totalXp: xp,
    );
  }

  /// السلسلة الحالية: أيام متتالية فيها إنجاز واحد على الأقل.
  /// الأيام الخالية من أي مهمة محايدة (لا تكسر السلسلة).
  static int currentStreak(List<Task> tasks, {DateTime? now}) {
    final DateTime today = Dates.day(now ?? DateTime.now());
    final Map<String, int> doneByDay = <String, int>{};
    final Set<String> busyDays = <String>{};
    for (final Task t in tasks) {
      final String k = Dates.key(t.date);
      busyDays.add(k);
      if (t.done) doneByDay[k] = (doneByDay[k] ?? 0) + 1;
    }
    int streak = 0;
    DateTime cursor = today;
    // إذا لم يُنجز شيء اليوم بعد، نبدأ الحساب من الأمس (اليوم ما زال جاريًا)
    if ((doneByDay[Dates.key(cursor)] ?? 0) == 0) {
      cursor = Dates.addDays(cursor, -1);
    }
    for (int i = 0; i < 400; i++) {
      final String k = Dates.key(cursor);
      if ((doneByDay[k] ?? 0) > 0) {
        streak++;
      } else if (!busyDays.contains(k)) {
        // يوم خالٍ — نتجاهله
      } else {
        break;
      }
      cursor = Dates.addDays(cursor, -1);
    }
    return streak;
  }

  static int bestStreak(List<Task> tasks) {
    final Map<String, int> doneByDay = <String, int>{};
    final Set<String> busyDays = <String>{};
    for (final Task t in tasks) {
      final String k = Dates.key(t.date);
      busyDays.add(k);
      if (t.done) doneByDay[k] = (doneByDay[k] ?? 0) + 1;
    }
    if (busyDays.isEmpty) return 0;
    final List<String> sorted = busyDays.toList()..sort();
    int best = 0;
    int current = 0;
    DateTime? previous;
    for (final String k in sorted) {
      final DateTime? day = Dates.parseKey(k);
      if (day == null) continue;
      if (previous == null || Dates.diffDays(previous, day) == 1) {
        if ((doneByDay[k] ?? 0) > 0) {
          current++;
        } else {
          current = 0;
        }
      } else {
        current = (doneByDay[k] ?? 0) > 0 ? 1 : 0;
      }
      if (current > best) best = current;
      previous = day;
    }
    return best;
  }

  /// إحصاءات خطة: أيام الدوام، الالتزام، السلسلة، الموعد القادم.
  static PlanStats planStats({
    required Plan plan,
    required List<Task> tasks,
    required Set<int> workDays,
    DateTime? now,
  }) {
    final DateTime n = Dates.day(now ?? DateTime.now());
    final DateTime start = Dates.day(plan.startDate);
    final DateTime spanEnd = plan.endDate != null ? Dates.day(plan.endDate!) : n;
    final int spanDays = spanEnd.isBefore(start) ? 0 : Dates.diffDays(start, spanEnd) + 1;

    final List<Task> planTasks = tasks.where((Task t) => t.planId == plan.id).toList();
    final Map<String, Task> byDay = <String, Task>{};
    for (final Task t in planTasks) {
      byDay[Dates.key(t.date)] = t;
    }

    // توليد الأيام المجدولة المتوقعة (بدون أثر جانبي على البيانات).
    final int scanLimit = spanDays > 0 && spanDays < 1100 ? spanDays : 400;
    int scheduled = 0;
    int work = 0;
    int rest = 0;
    int doneCount = 0;
    int missedCount = 0;
    int skippedCount = 0;
    int remaining = 0;
    int upcoming = 0;
    DateTime? next;

    DateTime cursor = start;
    for (int i = 0; i < scanLimit; i++) {
      final bool inRange = plan.endDate == null ? Dates.diffDays(cursor, n) >= 0 : Dates.diffDays(cursor, spanEnd) >= 0;
      if (!inRange && plan.endDate != null) break;
      if (plan.occursOn(cursor)) {
        scheduled++;
        if (workDays.contains(cursor.weekday)) {
          work++;
        } else {
          rest++;
        }
        final Task? task = byDay[Dates.key(cursor)];
        if (task != null && task.done) {
          doneCount++;
        } else if (task != null && task.skipped) {
          skippedCount++;
        } else if (Dates.diffDays(cursor, n) > 0) {
          if (plan.paused || plan.skippedDates.contains(Dates.key(cursor))) {
            skippedCount++;
          } else {
            missedCount++;
          }
        } else if (Dates.sameDay(cursor, n)) {
          if (task == null || !task.done) {
            remaining++;
            next ??= cursor;
          }
        } else {
          upcoming++;
          remaining++;
          next ??= cursor;
        }
      }
      cursor = Dates.addDays(cursor, 1);
    }

    next ??= plan.paused ? null : plan.nextOccurrence(n);

    // سلسلة الخطة: أيام مجدولة متتالية مُنجزة (بغض النظر عن أيام الراحة).
    int streak = 0;
    DateTime streakCursor = n;
    if (!(byDay[Dates.key(streakCursor)]?.done ?? false)) {
      streakCursor = Dates.addDays(streakCursor, -1);
    }
    for (int i = 0; i < 400; i++) {
      if (plan.occursOn(streakCursor)) {
        if (byDay[Dates.key(streakCursor)]?.done ?? false) {
          streak++;
        } else {
          break;
        }
      }
      streakCursor = Dates.addDays(streakCursor, -1);
      if (Dates.diffDays(start, streakCursor) < 0) break;
    }

    // ملخّص الأسبوع الحالي (حسب أول يوم أسبوع "السبت" الافتراضي)
    final DateTime weekStart = Dates.startOfWeek(n, DateTime.saturday);
    int weekTotal = 0;
    int weekDone = 0;
    DateTime wCursor = weekStart;
    for (int i = 0; i < 7; i++) {
      if (plan.occursOn(wCursor) && Dates.diffDays(wCursor, n) >= 0) {
        weekTotal++;
        if (byDay[Dates.key(wCursor)]?.done ?? false) weekDone++;
      }
      wCursor = Dates.addDays(wCursor, 1);
    }

    final int past = doneCount + missedCount + skippedCount;
    return PlanStats(
      spanDays: spanDays,
      scheduledTotal: scheduled,
      workDays: work,
      restDays: rest,
      doneCount: doneCount,
      missedCount: missedCount,
      skippedCount: skippedCount,
      remainingCount: remaining,
      upcomingCount: upcoming,
      adherence: past == 0 ? 0 : doneCount / past,
      streak: streak,
      weekDone: weekDone,
      weekTotal: weekTotal,
      next: next,
    );
  }
}
