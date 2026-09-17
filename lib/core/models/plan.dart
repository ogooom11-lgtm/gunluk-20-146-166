import 'dart:math' as math;

import '../enums.dart';
import '../utils/dates.dart';
import '../utils/ids.dart';
import 'subtask.dart';
import 'task.dart';

/// حالة الخطة المشتقة.
enum PlanStatus { notStarted, active, paused, finished }

/// خطة متكررة (روتين) — مثل: «كل ثلاثاء: قراءة الكتاب» مع تاريخ بداية ونهاية.
class Plan {
  Plan({
    required this.id,
    required this.title,
    required this.startDate,
    this.notes = '',
    this.categoryId = 'general',
    this.priority = TaskPriority.medium,
    this.repeatType = RepeatType.weekly,
    Set<int>? weekdays,
    this.intervalDays = 2,
    this.dayOfMonth = 1,
    this.endDate,
    this.paused = false,
    this.startMinutes,
    this.durationMinutes = 30,
    List<int>? reminderLeads,
    this.reminderAtMinutes,
    List<Subtask>? subtaskTemplates,
    List<String>? tags,
    Set<String>? skippedDates,
    DateTime? createdAt,
  })  : weekdays = weekdays ?? <int>{DateTime.tuesday},
        reminderLeads = reminderLeads ?? <int>[30],
        subtaskTemplates = subtaskTemplates ?? <Subtask>[],
        tags = tags ?? <String>[],
        skippedDates = skippedDates ?? <String>{},
        createdAt = createdAt ?? DateTime.now();

  factory Plan.fromJson(Map<String, dynamic> json) {
    final Set<int> days = <int>{};
    final dynamic rawDays = json['wd'];
    if (rawDays is List) {
      for (final dynamic v in rawDays) {
        if (v is num) days.add(v.toInt());
      }
    }
    final List<int> leads = <int>[];
    final dynamic rawLeads = json['rl'];
    if (rawLeads is List) {
      for (final dynamic v in rawLeads) {
        if (v is num) leads.add(v.toInt());
      }
    }
    final List<Subtask> subs = <Subtask>[];
    final dynamic rawSubs = json['sub'];
    if (rawSubs is List) {
      for (final dynamic v in rawSubs) {
        if (v is Map) subs.add(Subtask.fromJson(Map<String, dynamic>.from(v)));
      }
    }
    final Set<String> skipped = <String>{};
    final dynamic rawSkipped = json['sk'];
    if (rawSkipped is List) {
      for (final dynamic v in rawSkipped) {
        if (v != null) skipped.add(v.toString());
      }
    }
    final List<String> tags = <String>[];
    final dynamic rawTags = json['tags'];
    if (rawTags is List) {
      for (final dynamic v in rawTags) {
        if (v != null) tags.add(v.toString());
      }
    }
    return Plan(
      id: (json['id'] ?? Ids.next('pl')).toString(),
      title: (json['t'] ?? '').toString(),
      notes: (json['n'] ?? '').toString(),
      categoryId: (json['c'] ?? 'general').toString(),
      priority: TaskPriority.fromName(json['p']?.toString()),
      repeatType: RepeatType.fromName(json['rt']?.toString()),
      weekdays: days.isEmpty ? <int>{DateTime.tuesday} : days,
      intervalDays: (json['iv'] as num?)?.toInt() ?? 2,
      dayOfMonth: (json['dom'] as num?)?.toInt() ?? 1,
      startDate: Dates.parseKey(json['sd']?.toString()) ?? Dates.today(),
      endDate: json['ed'] != null ? Dates.parseKey(json['ed'].toString()) : null,
      paused: json['pz'] == true,
      startMinutes: (json['sm'] as num?)?.toInt(),
      durationMinutes: (json['dm'] as num?)?.toInt() ?? 30,
      reminderLeads: leads,
      reminderAtMinutes: (json['rm'] as num?)?.toInt(),
      subtaskTemplates: subs,
      tags: tags,
      skippedDates: skipped,
      createdAt: json['cr'] != null ? DateTime.tryParse(json['cr'].toString()) : null,
    );
  }

  final String id;
  String title;
  String notes;
  String categoryId;
  TaskPriority priority;
  RepeatType repeatType;

  /// أيام الأسبوع للخطة (1=الاثنين ... 7=الأحد).
  Set<int> weekdays;

  /// للخطة من نوع "كل عدد أيام".
  int intervalDays;

  /// للخطة الشهرية: يوم الشهر.
  int dayOfMonth;

  DateTime startDate;
  DateTime? endDate;
  bool paused;

  int? startMinutes;
  int durationMinutes;

  /// تذكيرات "قبل الموعد" بالدقائق.
  List<int> reminderLeads;

  /// تذكير في وقت محدد من اليوم (للخطط بدون وقت).
  int? reminderAtMinutes;

  /// خطوات متكررة تُنسخ إلى كل نسخة يومية.
  List<Subtask> subtaskTemplates;

  List<String> tags;

  /// أيام تم تخطيها يدويًا (بصيغة yyyy-MM-dd).
  Set<String> skippedDates;

  final DateTime createdAt;

  bool get hasTime => startMinutes != null;

  int? get endMinutes =>
      startMinutes == null ? null : startMinutes! + (durationMinutes > 0 ? durationMinutes : 0);

  /// هل تحلّ الخطة في هذا اليوم؟
  bool occursOn(DateTime day) {
    final DateTime d = Dates.day(day);
    if (Dates.diffDays(startDate, d) < 0) return false;
    if (endDate != null && Dates.diffDays(endDate!, d) > 0) return false;
    if (skippedDates.contains(Dates.key(d))) return false;
    switch (repeatType) {
      case RepeatType.daily:
        return true;
      case RepeatType.weekly:
        return weekdays.isEmpty ? true : weekdays.contains(d.weekday);
      case RepeatType.interval:
        final int step = intervalDays < 1 ? 1 : intervalDays;
        return Dates.diffDays(startDate, d) % step == 0;
      case RepeatType.monthly:
        final int target = math.min(dayOfMonth, Dates.daysInMonth(d.year, d.month));
        return d.day == target;
    }
  }

  /// كل أيام التنفيذ بين تاريخين (شامل الطرفين) مع حد أعلى للحماية.
  List<DateTime> occurrences(DateTime from, DateTime to, {int limit = 750}) {
    final List<DateTime> out = <DateTime>[];
    DateTime cursor = Dates.day(from);
    final DateTime last = Dates.day(to);
    int guard = 0;
    while (Dates.diffDays(cursor, last) >= 0 && guard < limit + 5) {
      if (pausedSkipped(cursor)) {
        // متوقفة مؤقتًا: لا تولّد أيامًا جديدة
        cursor = Dates.addDays(cursor, 1);
        guard++;
        continue;
      }
      if (occursOn(cursor) && !skippedDates.contains(Dates.key(cursor))) {
        out.add(cursor);
        if (out.length >= limit) break;
      }
      cursor = Dates.addDays(cursor, 1);
      guard++;
    }
    return out;
  }

  /// مُساعد داخلي: هل اليوم ضمن نطاق الخطة؟
  bool pausedSkipped(DateTime day) {
    if (Dates.diffDays(startDate, day) < 0) return true;
    if (endDate != null && Dates.diffDays(endDate!, day) > 0) return true;
    return false;
  }

  /// الموعد القادم بعد [from] (شامل اليوم).
  DateTime? nextOccurrence(DateTime from, {int searchDays = 400}) {
    DateTime cursor = Dates.day(from);
    for (int i = 0; i < searchDays; i++) {
      if (occursOn(cursor)) return cursor;
      cursor = Dates.addDays(cursor, 1);
    }
    return null;
  }

  /// كل أيام الخطة (من البداية حتى النهاية) — حتى لو لم تكن مجدولة.
  int totalSpanDays({DateTime? until}) {
    final DateTime end = endDate ?? (until ?? DateTime.now());
    final int diff = Dates.diffDays(startDate, end);
    return diff < 0 ? 0 : diff + 1;
  }

  PlanStatus statusAt(DateTime now) {
    if (endDate != null && Dates.diffDays(Dates.day(now), Dates.day(endDate!)) < 0) {
      return PlanStatus.finished;
    }
    if (Dates.diffDays(startDate, Dates.day(now)) < 0) return PlanStatus.notStarted;
    if (paused) return PlanStatus.paused;
    return PlanStatus.active;
  }

  /// إنشاء نسخة يومية من الخطة في يوم معيّن.
  Task occurrenceTask(DateTime day) => Task(
        id: Ids.planOccurrence(id, Dates.key(day)),
        title: title,
        date: Dates.day(day),
        notes: notes,
        categoryId: categoryId,
        priority: priority,
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
        reminderLeads: List<int>.from(reminderLeads),
        reminderAtMinutes: reminderAtMinutes,
        planId: id,
        subtasks: subtaskTemplates.map((Subtask s) => Subtask.create(s.title)).toList(),
        tags: List<String>.from(tags),
      );

  Plan copyWith({
    String? title,
    String? notes,
    String? categoryId,
    TaskPriority? priority,
    RepeatType? repeatType,
    Set<int>? weekdays,
    int? intervalDays,
    int? dayOfMonth,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? paused,
    int? startMinutes,
    bool clearStartTime = false,
    int? durationMinutes,
    List<int>? reminderLeads,
    int? reminderAtMinutes,
    bool clearReminderAt = false,
    List<Subtask>? subtaskTemplates,
    List<String>? tags,
    Set<String>? skippedDates,
  }) =>
      Plan(
        id: id,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        categoryId: categoryId ?? this.categoryId,
        priority: priority ?? this.priority,
        repeatType: repeatType ?? this.repeatType,
        weekdays: weekdays ?? Set<int>.from(this.weekdays),
        intervalDays: intervalDays ?? this.intervalDays,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        paused: paused ?? this.paused,
        startMinutes: clearStartTime ? null : (startMinutes ?? this.startMinutes),
        durationMinutes: durationMinutes ?? this.durationMinutes,
        reminderLeads: reminderLeads ?? List<int>.from(this.reminderLeads),
        reminderAtMinutes: clearReminderAt ? null : (reminderAtMinutes ?? this.reminderAtMinutes),
        subtaskTemplates:
            subtaskTemplates ?? this.subtaskTemplates.map((Subtask s) => s.copy()).toList(),
        tags: tags ?? List<String>.from(this.tags),
        skippedDates: skippedDates ?? Set<String>.from(this.skippedDates),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        't': title,
        'n': notes,
        'c': categoryId,
        'p': priority.name,
        'rt': repeatType.name,
        'wd': weekdays.toList()..sort(),
        'iv': intervalDays,
        'dom': dayOfMonth,
        'sd': Dates.key(startDate),
        'ed': endDate == null ? null : Dates.key(endDate!),
        'pz': paused,
        'sm': startMinutes,
        'dm': durationMinutes,
        'rl': reminderLeads,
        'rm': reminderAtMinutes,
        'sub': subtaskTemplates.map((Subtask s) => s.toJson()).toList(),
        'tags': tags,
        'sk': skippedDates.toList(),
        'cr': createdAt.toIso8601String(),
      };
}
