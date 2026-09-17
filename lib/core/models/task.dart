import '../enums.dart';
import '../utils/dates.dart';
import '../utils/ids.dart';
import 'subtask.dart';

/// إنجاز/مهمة في يوم محدّد. نسخ الخطط تُنشأ كمهام مرتبطة بـ planId.
class Task {
  Task({
    required this.id,
    required this.title,
    required this.date,
    this.notes = '',
    this.categoryId = 'general',
    this.priority = TaskPriority.medium,
    this.startMinutes,
    this.durationMinutes = 0,
    List<int>? reminderLeads,
    this.reminderAtMinutes,
    this.planId,
    List<Subtask>? subtasks,
    List<String>? tags,
    this.done = false,
    this.completedAt,
    this.skipped = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : reminderLeads = reminderLeads ?? <int>[],
        subtasks = subtasks ?? <Subtask>[],
        tags = tags ?? <String>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Task.fromJson(Map<String, dynamic> json) {
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
    final List<String> tags = <String>[];
    final dynamic rawTags = json['tags'];
    if (rawTags is List) {
      for (final dynamic v in rawTags) {
        if (v != null) tags.add(v.toString());
      }
    }
    return Task(
      id: (json['id'] ?? Ids.next('t')).toString(),
      title: (json['t'] ?? '').toString(),
      date: Dates.parseKey(json['d']?.toString()) ?? Dates.today(),
      notes: (json['n'] ?? '').toString(),
      categoryId: (json['c'] ?? 'general').toString(),
      priority: TaskPriority.fromName(json['p']?.toString()),
      startMinutes: (json['sm'] as num?)?.toInt(),
      durationMinutes: (json['dm'] as num?)?.toInt() ?? 0,
      reminderLeads: leads,
      reminderAtMinutes: (json['rm'] as num?)?.toInt(),
      planId: json['pl']?.toString(),
      subtasks: subs,
      tags: tags,
      done: json['dn'] == true,
      completedAt: json['ca'] != null ? DateTime.tryParse(json['ca'].toString()) : null,
      skipped: json['sk'] == true,
      createdAt: json['cr'] != null ? DateTime.tryParse(json['cr'].toString()) : null,
      updatedAt: json['up'] != null ? DateTime.tryParse(json['up'].toString()) : null,
    );
  }

  final String id;
  String title;
  String notes;

  /// معرّف الفئة.
  String categoryId;
  TaskPriority priority;

  /// اليوم الذي تنتمي إليه المهمة.
  DateTime date;

  /// وقت البدء بالدقائق من منتصف الليل — null يعني "بدون وقت".
  int? startMinutes;

  /// المدة المتوقعة بالدقائق (0 = غير محددة).
  int durationMinutes;

  /// تذكيرات "قبل الموعد" بالدقائق (مثال: 30 تعني قبل نصف ساعة).
  List<int> reminderLeads;

  /// تذكير في وقت محدد من اليوم (للمهام بدون وقت).
  int? reminderAtMinutes;

  /// معرّف الخطة إذا كانت هذه نسخة من خطة.
  String? planId;

  List<Subtask> subtasks;
  List<String> tags;

  bool done;
  DateTime? completedAt;
  bool skipped;

  final DateTime createdAt;
  DateTime updatedAt;

  bool get fromPlan => planId != null;

  bool get hasTime => startMinutes != null;

  int? get endMinutes {
    if (startMinutes == null) return null;
    return startMinutes! + (durationMinutes > 0 ? durationMinutes : 0);
  }

  int get subtaskCount => subtasks.length;

  int get subtaskDone => subtasks.where((Subtask s) => s.done).length;

  double get progress {
    if (done) return 1;
    if (subtasks.isEmpty) return 0;
    return subtaskDone / subtasks.length;
  }

  bool get isOverdue {
    if (done || skipped) return false;
    final DateTime now = DateTime.now();
    if (Dates.diffDays(date, now) > 0) return true;
    if (!Dates.sameDay(date, now)) return false;
    final int? end = endMinutes ?? startMinutes;
    if (end == null) return false;
    return Dates.nowMinutes() > end + 30;
  }

  ItemState get state {
    if (done) return ItemState.done;
    if (skipped) return ItemState.skipped;
    if (isOverdue) return ItemState.missed;
    return ItemState.pending;
  }

  int get xp {
    int base = priority.xp;
    if (subtasks.isNotEmpty) base += subtasks.length * 2;
    return base;
  }

  /// أوقات التذكيرات الفعلية لهذه المهمة (دقائق من منتصف الليل).
  List<int> reminderMinutes() {
    final List<int> out = <int>[];
    if (startMinutes != null) {
      for (final int lead in reminderLeads) {
        final int m = startMinutes! - lead;
        if (m >= 0 && m < 1440) out.add(m);
      }
    } else if (reminderAtMinutes != null) {
      out.add(reminderAtMinutes!);
    }
    final Set<int> unique = out.toSet();
    final List<int> list = unique.toList()..sort();
    return list;
  }

  Task copyWith({
    String? title,
    String? notes,
    String? categoryId,
    TaskPriority? priority,
    DateTime? date,
    int? startMinutes,
    bool clearStartTime = false,
    int? durationMinutes,
    List<int>? reminderLeads,
    int? reminderAtMinutes,
    bool clearReminderAt = false,
    String? planId,
    bool clearPlan = false,
    List<Subtask>? subtasks,
    List<String>? tags,
    bool? done,
    DateTime? completedAt,
    bool? skipped,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        date: date ?? this.date,
        notes: notes ?? this.notes,
        categoryId: categoryId ?? this.categoryId,
        priority: priority ?? this.priority,
        startMinutes: clearStartTime ? null : (startMinutes ?? this.startMinutes),
        durationMinutes: durationMinutes ?? this.durationMinutes,
        reminderLeads: reminderLeads ?? List<int>.from(this.reminderLeads),
        reminderAtMinutes: clearReminderAt ? null : (reminderAtMinutes ?? this.reminderAtMinutes),
        planId: clearPlan ? null : (planId ?? this.planId),
        subtasks: subtasks ?? this.subtasks.map((Subtask s) => s.copy()).toList(),
        tags: tags ?? List<String>.from(this.tags),
        done: done ?? this.done,
        completedAt: completedAt ?? this.completedAt,
        skipped: skipped ?? this.skipped,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  /// نسخة جديدة بمعرّف جديد (للنسخ المكررة).
  Task duplicate({DateTime? newDate, String? newId}) => Task(
        id: newId ?? Ids.next('t'),
        title: title,
        date: newDate ?? date,
        notes: notes,
        categoryId: categoryId,
        priority: priority,
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
        reminderLeads: List<int>.from(reminderLeads),
        reminderAtMinutes: reminderAtMinutes,
        subtasks: subtasks.map((Subtask s) => Subtask.create(s.title)).toList(),
        tags: List<String>.from(tags),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        't': title,
        'd': Dates.key(date),
        'n': notes,
        'c': categoryId,
        'p': priority.name,
        'sm': startMinutes,
        'dm': durationMinutes,
        'rl': reminderLeads,
        'rm': reminderAtMinutes,
        'pl': planId,
        'sub': subtasks.map((Subtask s) => s.toJson()).toList(),
        'tags': tags,
        'dn': done,
        'ca': completedAt?.toIso8601String(),
        'sk': skipped,
        'cr': createdAt.toIso8601String(),
        'up': updatedAt.toIso8601String(),
      };
}
