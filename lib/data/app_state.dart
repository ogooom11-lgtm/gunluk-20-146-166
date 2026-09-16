import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/l10n/app_strings.dart';
import '../core/l10n/date_names.dart';
import '../core/models/app_settings.dart';
import '../core/models/day_event.dart';
import '../core/models/day_note.dart';
import '../core/models/plan.dart';
import '../core/models/planned_reminder.dart';
import '../core/models/stats.dart';
import '../core/models/subtask.dart';
import '../core/models/task.dart';
import '../core/utils/dates.dart';
import '../core/utils/ids.dart';
import '../core/utils/secure_data.dart';
import '../services/backup_service.dart';
import '../services/file_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'app_repository.dart';
import 'defaults.dart';
import 'reminder_planner.dart';

/// حالة التطبيق المركزية: البيانات، الإحصاءات، الإشعارات، والتعديلات.
class AppState extends ChangeNotifier {
  AppState({
    AppRepository? repository,
    NotificationService? notifications,
    this.useIsolates = true,
  })  : repo = repository ?? AppRepository(),
        notifications = notifications ?? NotificationService.instance;

  /// تنفيذ مهام التشفير في عزلة منفصلة (يُعطّل في الاختبارات لتبقى متزامنة).
  final bool useIsolates;

  final AppRepository repo;
  final NotificationService notifications;

  bool ready = false;

  AppSettings settings = AppSettings(createdAt: DateTime.now());
  List<Category> categories = <Category>[];
  List<Task> tasks = <Task>[];
  List<Plan> plans = <Plan>[];
  List<DayNote> notes = <DayNote>[];

  /// أحداث اليوم — تُحفظ للأبد ولا تُحذف تلقائيًا.
  List<DayEvent> events = <DayEvent>[];
  List<FocusSession> sessions = <FocusSession>[];

  /// خدمة الملفات الأصلية (حفظ/اختيار ملف).
  final FileService files = FileService();

  /// هل التطبيق مقفل الآن بانتظار كلمة السر؟
  bool locked = false;

  /// وقت آخر انتقال للخلفية (لحساب مهلة السماح).
  DateTime? _backgroundedAt;

  /// الشارات المفتوحة وتاريخ فتحها.
  final Map<String, DateTime> badges = <String, DateTime>{};

  /// شارات جديدة لم تُعرض بعد (لعرض تنبيه داخلي).
  final List<String> newBadges = <String>[];

  /// طلب احتفال (عند إتمام كل مهام اليوم) — تستهلكه الواجهة مرة واحدة.
  bool celebrationPending = false;

  /// آخر وقت تذكير قادم (للعرض في الرئيسية).
  DateTime? nextReminderAt;

  bool systemNotificationsAllowed = true;

  List<PlannedReminder> _planned = <PlannedReminder>[];
  final Map<String, int> _notifIds = <String, int>{};
  int _notifSeq = 1000;

  Timer? _saveTimer;
  Timer? _reminderTimer;
  bool _dirty = false;

  // ===== تهيئة =====

  Future<void> init() async {
    await repo.ensure();
    _load();
    await repo.reload();
    await applyPendingOps(silent: true);
    _prune();
    // التأكد من وجود نسخ الخطط القادمة (والنسخة الحالية) — بدونها لا تظهر
    // مهام الخطط في التقويم ولا تُجدول تذكيراتها بعد إعادة التشغيل.
    final int healed = ensureOccurrences(pastDays: 0);
    if (healed > 0) _dirty = true;
    // قفل التطبيق عند الإقلاع إن كان مفعّلًا.
    locked = settings.lockEnabled && settings.lockHash.isNotEmpty;
    ready = true;
    notifyListeners();
    await applySecurityFlags();
    await initNotifications();
    await rebuildReminders(immediate: true);
    await refreshSystemNotificationState();
  }

  Future<void> initNotifications() async {
    await notifications.init(onTap: _handleNotificationTap);
  }

  Future<void> refreshSystemNotificationState() async {
    systemNotificationsAllowed = await notifications.areNotificationsEnabled();
    notifyListeners();
  }

  void _load() {
    final Map<String, dynamic> data = repo.read();
    if (data.isEmpty) {
      settings = AppSettings(createdAt: DateTime.now());
      categories = Defaults.categories();
      return;
    }
    settings = AppSettings.fromJson(AppRepository.map(data['settings']));
    categories = AppRepository.mapList(data['categories']).map(Category.fromJson).toList();
    if (categories.isEmpty) categories = Defaults.categories();
    tasks = AppRepository.mapList(data['tasks']).map(Task.fromJson).toList();
    plans = AppRepository.mapList(data['plans']).map(Plan.fromJson).toList();
    notes = AppRepository.mapList(data['notes']).map(DayNote.fromJson).toList();
    events = AppRepository.mapList(data['events']).map(DayEvent.fromJson).toList();
    sessions = AppRepository.mapList(data['sessions']).map(FocusSession.fromJson).toList();
    final Map<String, dynamic> badgeMap = AppRepository.map(data['badges']);
    badges.clear();
    badgeMap.forEach((String key, dynamic value) {
      final DateTime? at = DateTime.tryParse(value.toString());
      if (at != null) badges[key] = at;
    });
    _notifIds.clear();
    AppRepository.map(data['notifIds']).forEach((String key, dynamic value) {
      if (value is num) _notifIds[key] = value.toInt();
    });
    _notifSeq = (data['notifSeq'] as num?)?.toInt() ?? 1000;
  }

  Map<String, dynamic> exportData() => <String, dynamic>{
        'v': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'categories': categories.map((Category c) => c.toJson()).toList(),
        'tasks': tasks.map((Task t) => t.toJson()).toList(),
        'plans': plans.map((Plan p) => p.toJson()).toList(),
        'notes': notes.map((DayNote n) => n.toJson()).toList(),
        'events': events.map((DayEvent e) => e.toJson()).toList(),
        'sessions': sessions.map((FocusSession s) => s.toJson()).toList(),
        'badges': badges.map((String key, DateTime v) => MapEntry<String, String>(key, v.toIso8601String())),
        'notifIds': _notifIds,
        'notifSeq': _notifSeq,
      };

  String exportJson() => const JsonEncoder.withIndent('  ').convert(exportData());

  Future<bool> importJson(String raw) async {
    try {
      final dynamic decoded = jsonDecode(raw.trim());
      if (decoded is! Map) return false;
      final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);
      if (data['tasks'] == null && data['plans'] == null && data['settings'] == null) {
        return false;
      }
      await repo.write(data);
      _load();
      _prune();
      // نسخة مستعادة قد لا تحتوي نسخ الخطط القادمة — نولّدها فورًا.
      if (ensureOccurrences(pastDays: 0) > 0) _dirty = true;
      notifyListeners();
      await rebuildReminders(immediate: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// تنظيف البيانات القديمة فقط: لا يُحذف أي شيء حديث أو قادم.
  ///
  /// تنبيه: diffDays(a, b) = b - a، لذا الشرط الصحيح لحذف «الأقدم من الحد»
  /// هو أن يكون تاريخ العنصر أصغر من cutoff: diffDays(cutoff, date) < 0.
  void _prune() {
    final DateTime cutoff = Dates.addDays(DateTime.now(), -400);
    tasks.removeWhere((Task t) =>
        t.planId != null && !t.done && Dates.diffDays(cutoff, t.date) < 0);
    sessions.removeWhere((FocusSession s) => Dates.diffDays(cutoff, s.start) < 0);
  }

  void _save() {
    _dirty = false;
    repo.write(exportData());
  }

  void markDirty({bool notify = true}) {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      if (_dirty) _save();
    });
    if (notify) notifyListeners();
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    if (_dirty) _save();
  }

  // ===== فئات =====

  Category? category(String id) {
    for (final Category c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String categoryName(String id) => category(id)?.name ?? id;

  Color categoryColor(String id) => Color(category(id)?.color ?? 0xFF5B6BF0);

  IconData categoryIcon(String id) => category(id)?.icon ?? Icons.star_rounded;

  Future<void> upsertCategory(Category c) async {
    final int index = categories.indexWhere((Category e) => e.id == c.id);
    if (index >= 0) {
      categories[index] = c;
    } else {
      categories.add(c);
    }
    markDirty();
  }

  Future<void> deleteCategory(String id) async {
    if (id == 'general') return;
    categories.removeWhere((Category c) => c.id == id);
    for (final Task t in tasks) {
      if (t.categoryId == id) t.categoryId = 'general';
    }
    for (final Plan p in plans) {
      if (p.categoryId == id) p.categoryId = 'general';
    }
    markDirty();
  }

  // ===== مهام =====

  List<Task> tasksOn(DateTime day, {bool includeSkipped = true}) {
    final List<Task> list = tasks.where((Task t) => Dates.sameDay(t.date, day)).toList();
    if (!includeSkipped) list.removeWhere((Task t) => t.skipped);
    list.sort(_sortTasks);
    return list;
  }

  int _sortTasks(Task a, Task b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final int am = a.startMinutes ?? 24 * 60 + 1;
    final int bm = b.startMinutes ?? 24 * 60 + 1;
    if (am != bm) return am - bm;
    if (a.priority.rank != b.priority.rank) return b.priority.rank - a.priority.rank;
    return a.createdAt.compareTo(b.createdAt);
  }

  List<Task> get todayTasks => tasksOn(DateTime.now());

  List<Task> tasksInRange(DateTime from, DateTime to) {
    final List<Task> list = tasks
        .where((Task t) => Dates.diffDays(from, t.date) >= 0 && Dates.diffDays(t.date, to) >= 0)
        .toList();
    list.sort(_sortTasks);
    return list;
  }

  List<Task> get overdueTasks {
    final DateTime today = Dates.today();
    final List<Task> list = tasks
        .where((Task t) => !t.done && !t.skipped && Dates.diffDays(t.date, today) > 0)
        .toList();
    list.sort((Task a, Task b) => a.date.compareTo(b.date));
    return list;
  }

  Task? taskById(String id) {
    for (final Task t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Task> planTasks(String planId) => tasks.where((Task t) => t.planId == planId).toList();

  /// نسخة الخطة في يوم محدّد (إن وُجدت).
  Task? taskFor(String planId, DateTime day) {
    for (final Task t in tasks) {
      if (t.planId == planId && Dates.sameDay(t.date, day)) return t;
    }
    return null;
  }

  Future<void> upsertTask(Task task, {bool reschedule = true}) async {
    // حماية: أي مهمة بدون معرّف تحصل على معرّف جديد
    final Task safe = task.id.isEmpty ? task.duplicate(newId: Ids.next('t')) : task;
    final int index = tasks.indexWhere((Task t) => t.id == safe.id);
    if (index >= 0) {
      tasks[index] = safe;
    } else {
      tasks.add(safe);
    }
    _evaluateBadges();
    markDirty();
    if (reschedule) _scheduleReminderRebuild();
  }

  Future<void> deleteTask(String id) async {
    final Task? task = taskById(id);
    if (task != null && task.planId != null) {
      // حذف نسخة خطة يُعتبر «تخطّي ذلك اليوم»، وإلا عادت عند إعادة توليد النسخ.
      planById(task.planId!)?.skippedDates.add(Dates.key(task.date));
    }
    tasks.removeWhere((Task t) => t.id == id);
    await notifications.cancelTaskReminders(id);
    markDirty();
    _scheduleReminderRebuild();
  }

  /// تأجيل نسخة خطة إلى يوم آخر: نُسجّل اليوم الأصلي كمتخطّى حتى لا يُعاد
  /// توليده، ونفصل المهمة عن الخطة حتى لا تتكرر في يومها الجديد.
  void _detachFromPlan(Task task) {
    final String? planId = task.planId;
    if (planId == null) return;
    planById(planId)?.skippedDates.add(Dates.key(task.date));
    task.planId = null;
  }

  Future<void> setTaskDone(String id, bool done) async {
    final Task? task = taskById(id);
    if (task == null) return;
    task.done = done;
    task.completedAt = done ? DateTime.now() : null;
    if (done) {
      task.skipped = false;
      for (final Subtask s in task.subtasks) {
        s.done = true;
      }
    }
    if (done) await notifications.cancelTaskReminders(id);
    _checkCelebration();
    _evaluateBadges();
    markDirty();
    _scheduleReminderRebuild();
  }

  Future<void> toggleTaskDone(String id) async {
    final Task? task = taskById(id);
    if (task == null) return;
    final bool wasDone = task.done;
    await setTaskDone(id, !wasDone);
    if (!wasDone) {
      for (final Subtask s in task.subtasks) {
        s.done = true;
      }
    }
  }

  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    final Task? task = taskById(taskId);
    if (task == null) return;
    final int index = task.subtasks.indexWhere((Subtask s) => s.id == subtaskId);
    if (index < 0) return;
    task.subtasks[index].done = !task.subtasks[index].done;
    final bool allDone = task.subtasks.isNotEmpty && task.subtasks.every((Subtask s) => s.done);
    if (allDone && !task.done) {
      task.done = true;
      task.completedAt = DateTime.now();
      _checkCelebration();
    } else if (!allDone && task.done && task.subtasks.isNotEmpty) {
      task.done = false;
      task.completedAt = null;
    }
    _evaluateBadges();
    markDirty();
    _scheduleReminderRebuild();
  }

  Future<void> skipTask(String id, bool skipped) async {
    final Task? task = taskById(id);
    if (task == null) return;
    task.skipped = skipped;
    if (skipped) await notifications.cancelTaskReminders(id);
    markDirty();
    _scheduleReminderRebuild();
  }

  Future<void> moveTaskToTomorrow(String id) async {
    final Task? task = taskById(id);
    if (task == null) return;
    _detachFromPlan(task);
    task.date = Dates.addDays(Dates.today(), 1);
    task.updatedAt = DateTime.now();
    markDirty();
    _scheduleReminderRebuild();
  }

  Future<void> moveAllPendingToTomorrow() async {
    final DateTime today = Dates.today();
    for (final Task t in tasks) {
      if (Dates.sameDay(t.date, today) && !t.done && !t.skipped) {
        _detachFromPlan(t);
        t.date = Dates.addDays(today, 1);
        t.updatedAt = DateTime.now();
      }
    }
    markDirty();
    _scheduleReminderRebuild();
  }

  Future<void> duplicateTask(String id) async {
    final Task? task = taskById(id);
    if (task == null) return;
    final Task copy = task.duplicate(newDate: Dates.addDays(task.date, 1));
    await upsertTask(copy);
  }

  // ===== خطط =====

  Plan? planById(String id) {
    for (final Plan p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> upsertPlan(Plan plan, {bool regenerate = true}) async {
    final int index = plans.indexWhere((Plan p) => p.id == plan.id);
    if (index >= 0) {
      plans[index] = plan;
    } else {
      plans.add(plan);
    }
    if (regenerate) _resyncPlan(plan);
    markDirty();
    _scheduleReminderRebuild();
  }

  Future<void> deletePlan(String id, {bool deleteTasks = true}) async {
    plans.removeWhere((Plan p) => p.id == id);
    if (deleteTasks) {
      tasks.removeWhere((Task t) => t.planId == id);
    }
    markDirty();
    _scheduleReminderRebuild();
  }

  Future<void> setPlanPaused(String id, bool paused) async {
    final Plan? plan = planById(id);
    if (plan == null) return;
    plan.paused = paused;
    if (!paused) {
      ensureOccurrences();
    }
    markDirty();
    _scheduleReminderRebuild();
  }

  Future<void> togglePlanSkipDay(String planId, DateTime day) async {
    final Plan? plan = planById(planId);
    if (plan == null) return;
    final String key = Dates.key(day);
    if (plan.skippedDates.contains(key)) {
      plan.skippedDates.remove(key);
    } else {
      plan.skippedDates.add(key);
      tasks.removeWhere((Task t) => Dates.sameDay(t.date, day) && t.planId == planId && !t.done);
    }
    ensureOccurrences();
    markDirty();
    _scheduleReminderRebuild();
  }

  /// إعادة توليد مهام الخطة في المستقبل (بعد تعديل قواعدها).
  void _resyncPlan(Plan plan) {
    final DateTime today = Dates.today();
    tasks.removeWhere((Task t) =>
        t.planId == plan.id && !t.done && Dates.diffDays(today, t.date) >= 0);
    ensureOccurrences(onlyPlan: plan);
  }

  /// توليد نسخ الخطط كي تظهر في التقويم والإشعارات.
  /// يعيد عدد المهام التي أُضيفت.
  int ensureOccurrences({Plan? onlyPlan, int pastDays = 400, int futureDays = 150}) {
    final DateTime today = Dates.today();
    final DateTime from = Dates.addDays(today, -pastDays);
    final DateTime to = Dates.addDays(today, futureDays);
    int added = 0;
    for (final Plan plan in (onlyPlan != null ? <Plan>[onlyPlan] : plans)) {
      if (plan.paused) continue;
      final DateTime start = Dates.diffDays(from, plan.startDate) > 0 ? from : plan.startDate;
      final DateTime end = plan.endDate != null && Dates.diffDays(plan.endDate!, to) < 0 ? plan.endDate! : to;
      if (Dates.diffDays(start, end) < 0) continue;
      final List<DateTime> days = plan.occurrences(start, end);
      for (final DateTime day in days) {
        final String id = Ids.planOccurrence(plan.id, Dates.key(day));
        final bool exists = tasks.any((Task t) => t.id == id);
        if (!exists) {
          tasks.add(plan.occurrenceTask(day));
          added++;
        }
      }
    }
    return added;
  }

  // ===== ملاحظات وجلسات =====

  DayNote? noteFor(DateTime day) {
    final String key = Dates.key(day);
    for (final DayNote n in notes) {
      if (n.day == key) return n;
    }
    return null;
  }

  Future<void> saveNote(DateTime day, String text, int mood) async {
    final String key = Dates.key(day);
    final int index = notes.indexWhere((DayNote n) => n.day == key);
    if (index >= 0) {
      notes[index].text = text;
      notes[index].mood = mood;
      notes[index].updatedAt = DateTime.now();
    } else {
      notes.add(DayNote(day: key, text: text, mood: mood, updatedAt: DateTime.now()));
    }
    markDirty();
  }

  List<FocusSession> sessionsOn(DateTime day) =>
      sessions.where((FocusSession s) => Dates.sameDay(s.start, day)).toList();

  int get focusMinutesToday =>
      sessionsOn(DateTime.now()).fold(0, (int sum, FocusSession s) => sum + s.minutes);

  int get focusMinutesTotal => sessions.fold(0, (int sum, FocusSession s) => sum + s.minutes);

  Future<void> addFocusSession(int minutes, {String? taskId, String label = ''}) async {
    if (minutes <= 0) return;
    sessions.add(FocusSession(
      id: Ids.next('fs'),
      start: DateTime.now(),
      minutes: minutes,
      taskId: taskId,
      label: label,
    ));
    _evaluateBadges();
    markDirty();
  }

  // ===== إحصاءات =====

  DayStat statFor(DateTime day) => StatsEngine.dayStat(day, tasksOn(day));

  StatsSummary summary({int days = 7, int offset = 0}) {
    final DateTime to = Dates.addDays(Dates.today(), -offset);
    final DateTime from = Dates.addDays(to, -(days - 1));
    return StatsEngine.summarize(
      from: from,
      to: to,
      allTasks: tasks,
      sessions: sessions,
      allTasksForStreak: tasks,
    );
  }

  PlanStats planStats(Plan plan) => StatsEngine.planStats(
        plan: plan,
        tasks: tasks,
        workDays: settings.workDays,
        now: DateTime.now(),
      );

  double get todayRate {
    final List<Task> list = todayTasks.where((Task t) => !t.skipped).toList();
    if (list.isEmpty) return 0;
    return list.where((Task t) => t.done).length / list.length;
  }

  int get currentStreak => StatsEngine.currentStreak(tasks);

  int get bestStreak => StatsEngine.bestStreak(tasks);

  int get totalDone => tasks.where((Task t) => t.done).length;

  int get totalXp {
    int xp = 0;
    for (final Task t in tasks) {
      if (t.done) xp += t.xp;
    }
    xp += focusMinutesTotal;
    return xp;
  }

  static const int xpPerLevel = 250;

  int get level => 1 + (totalXp ~/ xpPerLevel);

  double get levelProgress => (totalXp % xpPerLevel) / xpPerLevel;

  int get xpToNextLevel => xpPerLevel - (totalXp % xpPerLevel);

  // ===== الشارات =====

  List<BadgeProgress> get badgeProgress {
    final StatsSummary week = summary(days: 7);
    final StatsSummary month = summary(days: 30);
    final int perfectInWeek = week.days.where((DayStat d) => d.isPerfect).length;
    final int finishedPlans = plans.where((Plan p) {
      final PlanStats s = planStats(p);
      final DateTime? next = s.next;
      return p.endDate != null && s.doneCount > 0 && (next == null || !next.isAfter(DateTime.now()));
    }).length;
    final int earlyDone = tasks
        .where((Task t) => t.done && (t.completedAt ?? t.date).hour < 9)
        .length;
    final int nightDone = tasks
        .where((Task t) => t.done && (t.completedAt ?? t.date).hour >= 21)
        .length;
    return <BadgeProgress>[
      for (final BadgeDef def in Defaults.badges)
        BadgeProgress(def, _metricValue(def.metric, earlyDone, nightDone, perfectInWeek, finishedPlans, month), badges[def.id]),
    ];
  }

  int _metricValue(BadgeMetric metric, int earlyDone, int nightDone, int perfectInWeek, int finishedPlans, StatsSummary month) {
    switch (metric) {
      case BadgeMetric.totalDone:
        return totalDone;
      case BadgeMetric.streak:
        return currentStreak > bestStreak ? currentStreak : bestStreak;
      case BadgeMetric.perfectDays:
        return month.days.where((DayStat d) => d.isPerfect).length;
      case BadgeMetric.perfectDaysInWeek:
        return perfectInWeek;
      case BadgeMetric.finishedPlans:
        return finishedPlans;
      case BadgeMetric.earlyDone:
        return earlyDone;
      case BadgeMetric.nightDone:
        return nightDone;
      case BadgeMetric.focusMinutes:
        return focusMinutesTotal;
    }
  }

  void _evaluateBadges() {
    for (final BadgeProgress progress in badgeProgress) {
      if (progress.value >= progress.def.target && !badges.containsKey(progress.def.id)) {
        badges[progress.def.id] = DateTime.now();
        newBadges.add(progress.def.id);
      }
    }
  }

  void _checkCelebration() {
    final List<Task> list = todayTasks.where((Task t) => !t.skipped).toList();
    if (list.isNotEmpty && list.every((Task t) => t.done)) {
      celebrationPending = settings.confetti;
    }
  }

  // ===== الإشعارات =====

  int notifId(String key) {
    final int? existing = _notifIds[key];
    if (existing != null) return existing;
    _notifSeq++;
    _notifIds[key] = _notifSeq;
    _dirty = true;
    return _notifSeq;
  }

  void _scheduleReminderRebuild() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(milliseconds: 900), () {
      rebuildReminders();
    });
  }

  /// إعادة بناء كل التذكيرات المجدولة (تُستدعى بعد أي تغيير).
  Future<void> rebuildReminders({bool immediate = false}) async {
    if (immediate) _reminderTimer?.cancel();
    final AppLocalizations l10n = AppLocalizations.ofLocale(Locale(settings.language));
    final List<PlannedReminder> planned = ReminderPlanner.build(
      settings: settings,
      tasks: tasks,
      l10n: l10n,
      idFor: notifId,
      categoryName: categoryName,
      windowDays: 16,
    );
    _planned = planned;
    nextReminderAt = planned.isEmpty ? null : planned.first.when;
    try {
      await notifications.sync(
        planned,
        settings,
        l10n,
        accent: AppTheme.palette(settings).accent,
      );
    } catch (_) {}
    _dirty = true;
    notifyListeners();
  }

  List<PlannedReminder> get plannedReminders => _planned;

  /// تذكير فوري لمهمة (تأجيل من داخل التطبيق).
  Future<void> snoozeTask(String taskId) async {
    final Task? task = taskById(taskId);
    if (task == null) return;
    final AppLocalizations l10n = AppLocalizations.ofLocale(Locale(settings.language));
    await notifications.init(onTap: _handleNotificationTap);
    final DateTime when = DateTime.now().add(Duration(minutes: settings.snoozeMinutes));
    final String timeText = DateNames.time(
      task.startMinutes ?? Dates.nowMinutes(),
      use24: settings.use24Hour,
      lang: settings.language,
      arabicDigits: settings.arabicDigits,
    );
    await notifications.schedule(
      PlannedReminder(
        id: notifId('manual:${task.id}:${when.millisecondsSinceEpoch ~/ 60000}'),
        key: 'manual:${task.id}',
        when: when,
        kind: ReminderKind.task,
        title: l10n.t('notif.taskTitle', <String, String>{'title': task.title}),
        body: l10n.t('notif.taskBody', <String, String>{
          'time': timeText,
          'category': categoryName(task.categoryId),
        }),
        taskId: task.id,
      ),
      settings,
      l10n,
      accent: AppTheme.palette(settings).accent,
    );
    markDirty(notify: false);
  }

  /// إشعار تجريبي فوري — يعيد false إذا رفض النظام عرض الإشعار.
  Future<bool> sendPreviewNotification() async {
    final AppLocalizations l10n = AppLocalizations.ofLocale(Locale(settings.language));
    await notifications.init(onTap: _handleNotificationTap);
    return notifications.showInstant(
      id: notifId('preview') + 1,
      title: l10n.t('notif.summaryTitle'),
      body: l10n.t('notif.summaryBody', <String, String>{'done': '3', 'total': '7', 'left': '4'}),
      settings: settings,
      l10n: l10n,
      kind: ReminderKind.review,
      accent: AppTheme.palette(settings).accent,
    );
  }

  /// عدد التذكيرات المجدولة فعليًا في نظام الإشعارات.
  Future<int> pendingReminderCount() => notifications.pendingCount();

  void _handleNotificationTap(NotifPayload payload) {
    // تفتح الواجهة التفاصيل بناءً على المحتوى — يُستهلك في RootShell
    lastTappedPayload = payload;
    notifyListeners();
  }

  NotifPayload? lastTappedPayload;

  void consumeTapPayload() {
    lastTappedPayload = null;
  }

  /// تنفيذ العمليات القادمة من أزرار الإشعارات في الخلفية.
  Future<void> applyPendingOps({bool silent = false}) async {
    List<Map<String, dynamic>> ops = <Map<String, dynamic>>[];
    try {
      ops = await repo.takeOps();
    } catch (_) {
      return;
    }
    if (ops.isEmpty) return;
    for (final Map<String, dynamic> op in ops) {
      final String type = (op['op'] ?? '').toString();
      final String? taskId = op['taskId']?.toString();
      if (type == 'done' && taskId != null) {
        final Task? task = taskById(taskId);
        if (task != null && !task.done) {
          task.done = true;
          task.completedAt = DateTime.tryParse((op['at'] ?? '').toString()) ?? DateTime.now();
          for (final Subtask s in task.subtasks) {
            s.done = true;
          }
        }
      }
    }
    _evaluateBadges();
    _checkCelebration();
    markDirty(notify: !silent);
    _scheduleReminderRebuild();
  }

  // ===== إعدادات =====

  Future<void> updateSettings(AppSettings next, {bool rescheduleNotifications = false}) async {
    final bool soundChanged = next.sound != settings.sound ||
        next.vibration != settings.vibration ||
        next.privacyMode != settings.privacyMode;
    settings = next;
    markDirty();
    if (rescheduleNotifications || soundChanged) {
      await rebuildReminders(immediate: true);
    }
  }

  AppLocalizations get l10n => AppLocalizations.ofLocale(Locale(settings.language));

  // ===== الأحداث اليومية =====

  /// أحداث يوم معيّن مرتّبة زمنيًا.
  List<DayEvent> eventsOn(DateTime day) {
    final List<DayEvent> out = events.where((DayEvent e) => e.isOn(day)).toList()
      ..sort(DayEvent.compareInDay);
    return out;
  }

  int eventCountOn(DateTime day) => events.where((DayEvent e) => e.isOn(day)).length;

  /// كل الأحداث مرتّبة من الأحدث إلى الأقدم.
  List<DayEvent> get eventsSorted =>
      List<DayEvent>.of(events)..sort(DayEvent.compareDesc);

  List<DayEvent> get starredEvents => eventsSorted.where((DayEvent e) => e.starred).toList();

  /// الأحداث القادمة (اليوم وما بعده)، مرتّبة تصاعديًا.
  List<DayEvent> upcomingEvents({int days = 30}) {
    final DateTime from = Dates.today();
    final DateTime to = Dates.addDays(from, days);
    final List<DayEvent> out = events
        .where((DayEvent e) => Dates.diffDays(from, e.day) >= 0 && Dates.diffDays(e.day, to) >= 0)
        .toList()
      ..sort((DayEvent a, DayEvent b) => DayEvent.compareDesc(b, a));
    return out;
  }

  /// الأحداث التي مرّت (قبل اليوم) — للمراجعة والذكريات.
  List<DayEvent> pastEvents({int days = 30}) {
    final DateTime today = Dates.today();
    final DateTime from = Dates.addDays(today, -days);
    return eventsSorted
        .where((DayEvent e) => Dates.diffDays(from, e.day) >= 0 && Dates.diffDays(e.day, today) > 0)
        .toList();
  }

  /// عدد الأحداث في شهر معيّن (يُعرض في التقويم والتقارير).
  int eventCountInMonth(DateTime month) => events
      .where((DayEvent e) => e.day.year == month.year && e.day.month == month.month)
      .length;

  DayEvent? eventById(String id) {
    for (final DayEvent e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<DayEvent> searchEvents(String query) {
    final String q = query.trim();
    if (q.isEmpty) return <DayEvent>[];
    final String needle = q.toLowerCase();
    return eventsSorted
        .where((DayEvent e) =>
            e.title.toLowerCase().contains(needle) ||
            e.place.toLowerCase().contains(needle) ||
            e.notes.toLowerCase().contains(needle))
        .toList();
  }

  Future<void> upsertEvent(DayEvent event) async {
    final DayEvent safe = event.id.isEmpty
        ? DayEvent(
            id: Ids.next('ev'),
            title: event.title,
            day: event.day,
            minutes: event.minutes,
            notes: event.notes,
            place: event.place,
            categoryId: event.categoryId,
            iconKey: event.iconKey,
            starred: event.starred,
          )
        : event;
    final int index = events.indexWhere((DayEvent e) => e.id == safe.id);
    if (index >= 0) {
      events[index] = safe;
    } else {
      events.add(safe);
    }
    markDirty();
  }

  Future<void> deleteEvent(String id) async {
    events.removeWhere((DayEvent e) => e.id == id);
    markDirty();
  }

  Future<void> toggleEventStar(String id) async {
    final DayEvent? event = eventById(id);
    if (event == null) return;
    event.starred = !event.starred;
    event.updatedAt = DateTime.now();
    markDirty();
  }

  // ===== الأمان: قفل بكلمة سر + منع التقاط الشاشة =====

  bool get lockEnabled => settings.lockEnabled && settings.lockHash.isNotEmpty;

  /// يقفل التطبيق فورًا (يُستدعى من الإعدادات أو عند مغادرة التطبيق).
  void lockNow() {
    if (!lockEnabled || locked) return;
    locked = true;
    notifyListeners();
  }

  /// يتحقق من كلمة السر ويفتح التطبيق.
  Future<bool> unlock(String password) async {
    if (!lockEnabled) {
      locked = false;
      notifyListeners();
      return true;
    }
    final bool ok = SecureData.verifyPassword(password, settings.lockHash);
    if (ok) {
      locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// تفعيل القفل بكلمة سر جديدة.
  Future<void> setLockPassword(String password) async {
    final String hash = SecureData.hashPassword(password);
    await updateSettings(settings.copyWith(lockEnabled: true, lockHash: hash));
    locked = false;
    notifyListeners();
  }

  /// إلغاء القفل نهائيًا (بعد التحقق من كلمة السر الحالية في الواجهة).
  Future<void> removeLock() async {
    await updateSettings(settings.copyWith(lockEnabled: false, lockHash: ''));
    locked = false;
    notifyListeners();
  }

  /// عند انتقال التطبيق للخلفية.
  void handleBackgrounded() {
    _backgroundedAt = DateTime.now();
    if (lockEnabled && settings.lockWhenBackground && settings.lockGraceSeconds <= 0) {
      locked = true;
    }
    notifyListeners();
  }

  /// عند العودة للتطبيق — يقفل إذا انتهت مهلة السماح.
  void handleResumed() {
    final DateTime? at = _backgroundedAt;
    _backgroundedAt = null;
    if (!lockEnabled) {
      if (locked) locked = false;
      notifyListeners();
      return;
    }
    if (at != null && settings.lockWhenBackground) {
      final int away = DateTime.now().difference(at).inSeconds;
      if (away >= settings.lockGraceSeconds) locked = true;
    }
    notifyListeners();
  }

  /// يطبّق خيارات الحماية على مستوى النظام (منع التقاط الشاشة).
  Future<void> applySecurityFlags() => files.setSecureScreen(settings.secureScreen);

  // ===== النسخ الاحتياطي المشفّر =====

  /// يشفّر كل البيانات ويعيد نص الملف الجاهز للحفظ.
  ///
  /// يعيد null إذا فشل التشفير (نادر: كلمة سر فارغة).
  Future<String?> exportEncryptedJson(
    String password, {
    int iterations = SecureData.defaultIterations,
  }) async {
    final Map<String, dynamic> result = await _runTask(
      encryptBackupTask,
      <String, dynamic>{
        'json': exportJson(),
        'password': password,
        'iterations': iterations,
      },
    );
    return result['ok'] == true ? result['data'] as String : null;
  }

  /// يستورد نسخة احتياطية عادية أو مشفّرة (بكلمة سرها).
  Future<ImportStatus> importAny(String raw, {String? password}) async {
    final String text = raw.trim();
    if (text.isEmpty) return ImportStatus.notBackup;
    if (!SecureData.looksEncrypted(text)) {
      final bool ok = await importJson(text);
      return ok ? ImportStatus.ok : ImportStatus.notBackup;
    }
    if (password == null || password.isEmpty) return ImportStatus.wrongPassword;
    final Map<String, dynamic> result = await _runTask(
      decryptBackupTask,
      <String, dynamic>{'file': text, 'password': password},
    );
    if (result['ok'] != true) {
      return importStatusForKey((result['key'] ?? '').toString());
    }
    final bool ok = await importJson(result['data'] as String);
    return ok ? ImportStatus.ok : ImportStatus.badFile;
  }

  Future<Map<String, dynamic>> _runTask(
    Map<String, dynamic> Function(Map<String, dynamic>) task,
    Map<String, dynamic> args,
  ) async {
    if (!useIsolates) return task(args);
    return compute(task, args);
  }

  Future<void> resetAll() async {
    await notifications.cancelAll();
    await repo.clearAll();
    settings = AppSettings(createdAt: DateTime.now());
    categories = Defaults.categories();
    tasks = <Task>[];
    plans = <Plan>[];
    notes = <DayNote>[];
    events = <DayEvent>[];
    sessions = <FocusSession>[];
    locked = false;
    badges.clear();
    _notifIds.clear();
    _planned = <PlannedReminder>[];
    nextReminderAt = null;
    markDirty();
  }

  Future<void> refreshFromStorage() async {
    await repo.reload();
    await applyPendingOps(silent: true);
    notifyListeners();
  }
}
