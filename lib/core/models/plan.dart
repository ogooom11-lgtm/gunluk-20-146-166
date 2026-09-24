import 'dart:math' as math;

import '../enums.dart';
import '../utils/dates.dart';
import '../utils/ids.dart';
import '../utils/json_map.dart';
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
    this.target,
    this.unit = '',
    Map<String, double>? progress,
    Set<int>? restWeekdays,
    this.autoComplete = true,
    DateTime? createdAt,
  })  : weekdays = weekdays ?? <int>{DateTime.tuesday},
        reminderLeads = reminderLeads ?? <int>[30],
        subtaskTemplates = subtaskTemplates ?? <Subtask>[],
        tags = tags ?? <String>[],
        skippedDates = skippedDates ?? <String>{},
        progress = progress ?? <String, double>{},
        restWeekdays = restWeekdays ?? <int>{},
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
    final Map<String, double> progress = <String, double>{};
    final Map<String, dynamic> rawProgress = AppJson.map(json['pr']);
    rawProgress.forEach((String key, dynamic value) {
      final double? v = value is num ? value.toDouble() : double.tryParse(value.toString());
      if (v != null && v > 0) progress[key] = v;
    });
    final Set<int> rest = <int>{};
    final dynamic rawRest = json['rw'];
    if (rawRest is List) {
      for (final dynamic v in rawRest) {
        if (v is num && v.toInt() >= DateTime.monday && v.toInt() <= DateTime.sunday) {
          rest.add(v.toInt());
        }
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
      target: (json['tg'] as num?)?.toDouble(),
      unit: (json['un'] ?? '').toString(),
      progress: progress,
      restWeekdays: rest,
      autoComplete: json['aq'] != false,
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

  /// الهدف الكمّي الكلي للخطة (مثال: ٥٠٠ صفحة) — null يعني خطة عادية.
  double? target;

  /// وحدة الهدف الكمّي: صفحة، كلمة، تمرين…
  String unit;

  /// ما أُنجز فعليًا كل يوم: بصيغة yyyy-MM-dd ⇒ الكمّية.
  ///
  /// تُحفظ مع الخطة نفسها للأبد، فلا يضيع سجلّك لو حُذفت مهام الأيام.
  Map<String, double> progress;

  /// أيام الراحة الأسبوعية (1=الاثنين … 7=الأحد): لا مطلوب فيها ولا تُحتسب.
  Set<int> restWeekdays;

  /// إكمال مهمة اليوم تلقائيًا عند بلوغ المطلوب؟
  bool autoComplete;

  final DateTime createdAt;

  bool get hasTime => startMinutes != null;

  // ===== الخطة الكمّية (هدف يُوزَّع على الأيام) =====

  /// هل الخطة بكمّية وهدف (مثال: ٥٠٠ صفحة خلال أسبوع)؟
  bool get isQuantified => target != null && target! > 0;

  double get totalTarget => target == null || target! < 0 ? 0 : target!;

  /// هل الهدف عدد صحيح (فنقرّب المطلوب اليومي لأعلى عدد صحيح)؟
  bool get wholeTarget => target != null && target! == target!.roundToDouble();

  /// يوم راحة أسبوعي؟
  bool isRestDay(DateTime day) => restWeekdays.contains(Dates.day(day).weekday);

  /// الكمّية المسجّلة في يوم معيّن.
  double progressOn(DateTime day) => progress[Dates.key(day)] ?? 0;

  /// مجموع ما أُنجز من الهدف الكلي.
  double get doneAmount {
    double sum = 0;
    for (final double v in progress.values) {
      sum += v;
    }
    return sum;
  }

  /// ما بقي من الهدف.
  double get remainingAmount {
    final double left = totalTarget - doneAmount;
    return left < 0 ? 0 : left;
  }

  /// نسبة الإنجاز بالكمّية (0..1).
  double get amountRatio {
    if (totalTarget <= 0) return 0;
    return (doneAmount / totalTarget).clamp(0.0, 1.0);
  }

  /// ما أُنجز قبل يوم معيّن (لا يشمل اليوم نفسه).
  double doneBefore(DateTime day) {
    final String key = Dates.key(day);
    double sum = 0;
    progress.forEach((String k, double v) {
      if (k.compareTo(key) < 0) sum += v;
    });
    return sum;
  }

  /// هل هذا اليوم يوم تنفيذ (داخل النطاق، ليس راحة، ولم يُتخطَّ)؟
  bool isExecutionDay(DateTime day) {
    final DateTime d = Dates.day(day);
    if (Dates.diffDays(startDate, d) < 0) return false;
    if (endDate != null && Dates.diffDays(endDate!, d) > 0) return false;
    if (skippedDates.contains(Dates.key(d))) return false;
    return !isRestDay(d);
  }

  /// عدد أيام التنفيذ بين يومين شاملًا الطرفين (بحد أعلى للحماية).
  int executionDays(DateTime from, DateTime to) {
    DateTime cursor = Dates.day(from);
    final DateTime last = Dates.day(to);
    int count = 0;
    int guard = 0;
    while (Dates.diffDays(cursor, last) >= 0 && guard <= 1500) {
      if (isExecutionDay(cursor)) count++;
      cursor = Dates.addDays(cursor, 1);
      guard++;
    }
    return count;
  }

  /// تقريب المطلوب اليومي: لأعلى عدد صحيح، أو بمنزلة عشرية واحدة للكسور.
  double roundAmount(double value) {
    if (value <= 0) return 0;
    if (wholeTarget) return value.ceilToDouble();
    return (value * 10).roundToDouble() / 10;
  }

  /// المطلوب في يوم معيّن حسب ما أُنجز فعلًا:
  /// تأخّرت في الأيام السابقة ⇒ يرتفع المطلوب، تقدّمت ⇒ ينخفض.
  double requiredOn(DateTime day) {
    if (!isQuantified || !isExecutionDay(day)) return 0;
    final double remaining = totalTarget - doneBefore(day);
    if (remaining <= 0) return 0;
    final int days = executionDays(day, endDate ?? Dates.day(day));
    if (days <= 0) return remaining;
    return roundAmount(remaining / days);
  }

  /// جدول الأيام القادمة: كم يجب أن تنجز كل يوم (يتعدّل مع ما تسجّله).
  List<PlanDayAmount> schedule({DateTime? from, int maxDays = 14}) {
    final DateTime start = Dates.day(from ?? Dates.today());
    final DateTime end = Dates.day(endDate ?? start);
    final List<DateTime> days = <DateTime>[];
    for (int i = 0; i <= 1500; i++) {
      final DateTime d = Dates.addDays(start, i);
      if (Dates.diffDays(d, end) < 0) break;
      if (isExecutionDay(d)) days.add(d);
    }
    double remaining = totalTarget - doneBefore(start);
    if (remaining < 0) remaining = 0;
    final List<PlanDayAmount> out = <PlanDayAmount>[];
    for (int i = 0; i < days.length && out.length < maxDays; i++) {
      final double dayDone = progressOn(days[i]);
      final int left = days.length - i;
      // اليوم الأول: إن كان قد أُنجز كاملًا فلا نُطالب به مرّة أخرى، ونخصم
      // كمّيته المحفوظة (وليس المطلوب) حتى يكون الباقي صحيحًا.
      if (i == 0 && dayDone > 0 && dayDone + 0.0001 >= remaining) {
        out.add(PlanDayAmount(day: days[i], amount: dayDone, done: dayDone));
        remaining = 0;
        continue;
      }
      double amount = remaining <= 0 ? 0 : roundAmount(remaining / left);
      if (amount > remaining) amount = remaining;
      if (remaining > 0 && amount <= 0) amount = remaining;
      out.add(PlanDayAmount(day: days[i], amount: amount, done: dayDone));
      if (i == 0 && dayDone > 0 && amount > 0 && dayDone + 0.0001 >= amount) {
        // أُنجز مطلوب اليوم ⇒ نخصم ما سُجّل فعلًا (قد يكون أكثر من المطلوب).
        remaining -= dayDone;
      } else {
        remaining -= amount;
      }
      if (remaining < 0) remaining = 0;
    }
    return out;
  }

  int? get endMinutes =>
      startMinutes == null ? null : startMinutes! + (durationMinutes > 0 ? durationMinutes : 0);

  /// هل تحلّ الخطة في هذا اليوم؟
  bool occursOn(DateTime day) {
    final DateTime d = Dates.day(day);
    if (Dates.diffDays(startDate, d) < 0) return false;
    if (endDate != null && Dates.diffDays(endDate!, d) > 0) return false;
    if (skippedDates.contains(Dates.key(d))) return false;
    // الخطة الكمّية: تُنفَّذ كل يوم ما عدا أيام الراحة المختارة.
    if (isQuantified) return !isRestDay(d);
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
        amountTarget: isQuantified ? requiredOn(day) : null,
        amountDone: isQuantified ? progressOn(day) : null,
        amountUnit: isQuantified ? unit : '',
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
    double? target,
    bool clearTarget = false,
    String? unit,
    Map<String, double>? progress,
    Set<int>? restWeekdays,
    bool? autoComplete,
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
        target: clearTarget ? null : (target ?? this.target),
        unit: unit ?? this.unit,
        progress: progress ?? Map<String, double>.from(this.progress),
        restWeekdays: restWeekdays ?? Set<int>.from(this.restWeekdays),
        autoComplete: autoComplete ?? this.autoComplete,
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
        'tg': target,
        'un': unit,
        'pr': progress,
        'rw': restWeekdays.toList()..sort(),
        'aq': autoComplete,
        'cr': createdAt.toIso8601String(),
      };
}

/// مطلوب يوم واحد في جدول الخطة الكمّية.
class PlanDayAmount {
  const PlanDayAmount({required this.day, required this.amount, required this.done});

  final DateTime day;
  final double amount;
  final double done;

  bool get met => amount > 0 && done + 0.0001 >= amount;

  double get ratio => amount <= 0 ? (done > 0 ? 1 : 0) : (done / amount).clamp(0.0, 1.0);
}
