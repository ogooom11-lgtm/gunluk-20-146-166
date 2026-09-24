import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

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

/// ترميز بيانات التطبيق إلى نص JSON — تُنفَّذ في عزلة منفصلة (compute)
/// كي لا تتجمّد الواجهة عند حفظ أرشيف كبير.
String encodeDataTask(Map<String, dynamic> data) => jsonEncode(data);

/// هل نعمل داخل `flutter test`؟
///
/// داخل الاختبارات يعمل زمن اصطناعي لا تُسلَّم فيه نتائج العزلات، فتظلّ
/// `compute` معلّقة بلا نهاية ويبدو المُشغّل كأنه تعلّق. لذلك نُكمل العمل
/// على الخيط الرئيسي في الاختبارات فقط، وتبقى العزلة للتطبيق الحقيقي.
bool _inTestRun() {
  try {
    return Platform.environment['FLUTTER_TEST'] == 'true';
  } catch (_) {
    return false;
  }
}

/// حالة التطبيق المركزية: البيانات، الإحصاءات، الإشعارات، والتعديلات.
class AppState extends ChangeNotifier {
  AppState({
    AppRepository? repository,
    NotificationService? notifications,
    this.useIsolates = true,
    this.pinIterations = SecureData.passwordIterations,
    DateTime Function()? clock,
  })  : repo = repository ?? AppRepository(),
        notifications = notifications ?? NotificationService.instance,
        clock = clock ?? DateTime.now;

  /// تنفيذ مهام التشفير في عزلة منفصلة (يُعطّل في الاختبارات لتبقى متزامنة).
  final bool useIsolates;

  /// مصدر الوقت الحالي (قابل للحقن في الاختبارات).
  final DateTime Function() clock;

  /// عدد تكرارات PBKDF2 لبصمة رمز الدخول (يُخفَّض في الاختبارات فقط).
  final int pinIterations;

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

  // ===== مؤقّت التركيز (يعمل خارج الشاشة وفي الخلفية) =====

  /// هل هناك جلسة تركيز جارية (تشغيل أو إيقاف مؤقت)؟
  bool focusRunning = false;

  /// هل الجلسة متوقّفة مؤقتًا؟
  bool focusPaused = false;

  /// مدة الجلسة كاملة بالثواني.
  int focusTotalSeconds = 0;

  /// لحظة بدء الجلسة الحالية (تُحفظ لتسجيل وقت الجلسة).
  DateTime? focusStartedAt;

  /// لحظة نهاية الجلسة (null عند الإيقاف المؤقت).
  DateTime? focusEndsAt;

  /// الثواني المتبقية عند الإيقاف المؤقت.
  int focusPausedRemaining = 0;

  /// المهمة المرتبطة بالجلسة (إن وُجدت).
  String? focusTaskId;

  /// عنوان الجلسة (اسم المهمة أو فراغ).
  String focusLabel = '';

  /// هل الجلسة راحة (لا تُحتسب ضمن دقائق التركيز)؟
  bool focusIsBreak = false;

  /// عدد الجلسات المكتملة (تستهلكه الشاشة لعرض تهنئة مرة واحدة).
  int focusCompletedCount = 0;

  /// معرّف الإشعار الدائم (شريط التقدّم) في نظام الإشعارات.
  static const int focusNotifId = 900001;

  /// معرّف إشعار انتهاء الجلسة الاحتياطي.
  static const int focusDoneNotifId = 900002;

  Timer? _focusTimer;
  int _focusNoticeTick = 0;

  /// الثواني المتبقية في الجلسة الحالية (محسوبة من الساعة لا من عدّاد).
  int get focusRemainingSeconds {
    if (!focusRunning) return 0;
    if (focusPaused) return focusPausedRemaining;
    final DateTime? end = focusEndsAt;
    if (end == null) return 0;
    final int seconds = end.difference(clock()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  /// الثواني المنقضية من الجلسة.
  int get focusElapsedSeconds {
    final int remaining = focusRemainingSeconds;
    final int elapsed = focusTotalSeconds - remaining;
    return elapsed < 0 ? 0 : elapsed;
  }

  /// نسبة إنجاز الجلسة (0..1).
  double get focusProgress {
    if (focusTotalSeconds <= 0) return 0;
    return (focusElapsedSeconds / focusTotalSeconds).clamp(0.0, 1.0);
  }

  Duration get focusRemaining => Duration(seconds: focusRemainingSeconds);

  /// وقت آخر انتقال للخلفية (لحساب مهلة السماح).
  DateTime? _backgroundedAt;

  /// يقفل التطبيق تلقائيًا بعد انتهاء مهلة السماح وهو في الخلفية.
  Timer? _lockTimer;

  /// مؤقّت قصير لحالة «inactive» قبل اعتبارها مغادرة فعلية.
  Timer? _inactiveTimer;

  /// حالة «inactive»: قد تكون مغادرة حقيقية (مبدّل تطبيقات) أو لمسة سريعة
  /// (شريط إشعارات أو نافذة نظام) — ننتظر ٣ ثوانٍ قبل اعتبارها مغادرة.
  void handlePossiblyLeaving() {
    if (!lockEnabled || !settings.lockWhenBackground) return;
    _inactiveTimer?.cancel();
    _inactiveTimer = Timer(const Duration(seconds: 3), () {
      // نافذة تحقّق المنبّه ليست مغادرة للتطبيق.
      if (activeAlarmTaskId != null) return;
      if (_backgroundedAt != null) return;
      handleBackgrounded();
    });
  }

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

  bool _initOnceStarted = false;

  /// تهيئة محميّة من التكرار (تُستدعى من main) ولا تعتمد على مهلة من الخارج.
  Future<void> initOnce() async {
    if (_initOnceStarted) return;
    _initOnceStarted = true;
    await init();
  }

  Future<void> init() async {
    await repo.ensure();
    _load();
    await repo.reload();
    await applyPendingOps(silent: true);
    syncQuantProgress();
    _prune();
    // التأكد من وجود نسخ الخطط القادمة (والنسخة الحالية) — بدونها لا تظهر
    // مهام الخطط في التقويم ولا تُجدول تذكيراتها بعد إعادة التشغيل.
    final int healed = ensureOccurrences(pastDays: 0);
    if (healed > 0) _dirty = true;
    // إعادة حساب مطلوب الأيام القادمة للخطط الكمّية عند كل فتح للتطبيق.
    refreshQuantTasks();
    // قفل التطبيق عند الإقلاع إن كان مفعّلًا.
    locked = settings.lockEnabled && settings.lockHash.isNotEmpty;
    ready = true;
    notifyListeners();
    await applySecurityFlags();
    await initNotifications();
    // استرجاع جلسة تركيز كانت جارية قبل إغلاق التطبيق.
    await _restoreFocus();
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
    _loadFocusTimer(AppRepository.map(data['focusTimer']));
  }

  void _loadFocusTimer(Map<String, dynamic> json) {
    if (json.isEmpty) {
      _clearFocus();
      return;
    }
    final int total = (json['total'] as num?)?.toInt() ?? 0;
    if (total <= 0) {
      _clearFocus();
      return;
    }
    focusTotalSeconds = total;
    focusStartedAt = DateTime.tryParse((json['started'] ?? '').toString());
    focusEndsAt = DateTime.tryParse((json['ends'] ?? '').toString());
    focusPaused = json['paused'] == true;
    focusPausedRemaining = (json['prem'] as num?)?.toInt() ?? 0;
    focusTaskId = json['task']?.toString();
    focusLabel = (json['label'] ?? '').toString();
    focusIsBreak = json['brk'] == true;
    focusRunning = true;
    _focusTimer?.cancel();
    _focusTimer = null;
    _focusNoticeTick = 0;
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
        'focusTimer': focusRunning
            ? <String, dynamic>{
                'total': focusTotalSeconds,
                'started': focusStartedAt?.toIso8601String(),
                'ends': focusEndsAt?.toIso8601String(),
                'paused': focusPaused,
                'prem': focusPausedRemaining,
                'task': focusTaskId,
                'label': focusLabel,
                'brk': focusIsBreak,
              }
            : null,
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

  /// حفظ واحد جارٍ (حتى لا يتزاحم حزمان على نفس المستند).
  Future<void>? _saving;

  /// يحفظ كل البيانات — وترميز JSON يجري في عزلة منفصلة كي لا تتجمّد الواجهة
  /// عند كبر البيانات (آلاف المهام والأيام).
  ///
  /// إن كان حفظ جارٍ فلا نبدأ آخر بالتوازي (كي لا يطمس الأقدم الجديد)، بل
  /// نُعيد الحفظ الجاري نفسه — وهو يُكمل ما استجدّ من تغييرات في حلقة واحدة.
  Future<void> _save() {
    final Future<void>? running = _saving;
    if (running != null) return running;
    // لا تغييرات ⇒ لا كتابة (وإلّا بقي _saving عالقًا على مهمة منتهية).
    if (!_dirty) return Future<void>.value();
    final Future<void> job = _saveLoop();
    _saving = job;
    return job;
  }

  Future<void> _saveLoop() async {
    try {
      while (_dirty) {
        _dirty = false;
        final Map<String, dynamic> data = exportData();
        final String raw = await _encodeData(data);
        await repo.ensure();
        await repo.writeRaw(raw);
      }
    } catch (_) {
      // فشل الحفظ: نُعيد علامة «غير محفوظ» كي يُعاد المحاولة تلقائيًا.
      _dirty = true;
    } finally {
      _saving = null;
    }
  }

  void markDirty({bool notify = true}) {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      if (_dirty) unawaited(_save());
    });
    if (notify) notifyListeners();
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _save();
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
    refreshQuantTasks(onlyPlan: plan);
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
    refreshQuantTasks(onlyPlan: plan);
    markDirty();
    _scheduleReminderRebuild();
  }

  // ===== الخطة الكمّية (هدف يُوزَّع على الأيام) =====

  /// يسجّل كمّية يوم من خطة كمّية، ثم يعيد توزيع الأيام القادمة:
  /// أنجزت أكثر من المطلوب ⇒ يقلّ مطلوب الأيام القادمة، وأقل ⇒ يرتفع.
  Future<void> logPlanAmount(String planId, DateTime day, double amount) async {
    final Plan? plan = planById(planId);
    if (plan == null || !plan.isQuantified) return;
    // المطلوب قبل التسجيل — نُقارن به لتحديد الإنجاز.
    final double required = plan.requiredOn(day);
    final String key = Dates.key(day);
    final double clean = amount <= 0 ? 0 : (amount * 100).roundToDouble() / 100;
    if (clean <= 0) {
      plan.progress.remove(key);
    } else {
      plan.progress[key] = clean;
    }
    final Task? task = taskFor(planId, day);
    if (task != null) {
      task.amountDone = clean;
      task.amountUnit = plan.unit;
      if (plan.autoComplete) {
        final bool met = required > 0 && clean + 0.0001 >= required;
        if (met && !task.done) {
          task.done = true;
          task.completedAt = DateTime.now();
          for (final Subtask sub in task.subtasks) {
            sub.done = true;
          }
        }
      }
    }
    refreshQuantTasks(onlyPlan: plan);
    markDirty();
    _scheduleReminderRebuild();
  }

  /// يتأكد أن كمّية كل خطة كمّية محفوظة في سجلّ الخطة (استعادة بعد نسخة قديمة).
  void syncQuantProgress() {
    for (final Plan plan in plans) {
      if (!plan.isQuantified) continue;
      for (final Task task in tasks) {
        if (task.planId != plan.id || !task.done) continue;
        final double? done = task.amountDone;
        if (done == null || done <= 0) continue;
        final String key = Dates.key(task.date);
        final double saved = plan.progress[key] ?? 0;
        if (done > saved) plan.progress[key] = done;
      }
    }
  }

  /// يحدّث مطلوب الأيام القادمة (واليوم) في مهام الخطة الكمّية.
  void refreshQuantTasks({Plan? onlyPlan}) {
    // نعتمد ساعة التطبيق (قابلة للحقن في الاختبارات) لا تاريخ النظام مباشرة.
    final DateTime today = Dates.day(clock());
    for (final Plan plan in (onlyPlan != null ? <Plan>[onlyPlan] : plans)) {
      if (!plan.isQuantified) continue;
      // فهرس مهام الخطة حسب اليوم: البحث الخطّي لكل يوم كان يُثقل الواجهة.
      final Map<String, Task> byDay = <String, Task>{};
      for (final Task task in tasks) {
        if (task.planId == plan.id) byDay[Dates.key(task.date)] = task;
      }
      for (final PlanDayAmount item in plan.schedule(from: today, maxDays: 400)) {
        final Task? task = byDay[Dates.key(item.day)];
        if (task == null || task.done) continue;
        task.amountTarget = item.amount;
        task.amountDone = item.done;
        task.amountUnit = plan.unit;
      }
    }
  }

  /// مطلوب اليوم لخطة كمّية (0 إن لم تكن كمّية أو انتهت).
  double planRequiredToday(Plan plan) => plan.requiredOn(Dates.day(clock()));

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
    // فهرس المعرّفات مرّة واحدة: كان الفحص لكل يوم يمرّ على كل المهام،
    // ومع آلاف المهام كان يسبّب تجمّدًا عند فتح التطبيق.
    final Set<String> existing = taskIds;
    for (final Plan plan in (onlyPlan != null ? <Plan>[onlyPlan] : plans)) {
      if (plan.paused) continue;
      final DateTime start = Dates.diffDays(from, plan.startDate) > 0 ? from : plan.startDate;
      final DateTime end = plan.endDate != null && Dates.diffDays(plan.endDate!, to) < 0 ? plan.endDate! : to;
      if (Dates.diffDays(start, end) < 0) continue;
      final List<DateTime> days = plan.occurrences(start, end);
      for (final DateTime day in days) {
        final String id = Ids.planOccurrence(plan.id, Dates.key(day));
        if (existing.contains(id)) continue;
        final Task created = plan.occurrenceTask(day);
        tasks.add(created);
        existing.add(id);
        added++;
      }
    }
    if (added > 0) refreshQuantTasks();
    return added;
  }

  /// فهرس سريع لمعرّفات المهام — يمنع المقارنة الخطية داخل الحلقات الطويلة.
  Set<String> get taskIds => tasks.map((Task t) => t.id).toSet();

  // ===== ملاحظات وجلسات =====

  /// تقييم اليوم (٠ = سيء … ٤ = ممتاز، و-1 = لم يُقيَّم بعد).
  int ratingFor(DateTime day) => noteFor(day)?.mood ?? -1;

  /// يحفظ تقييم اليوم (مع الحفاظ على الملاحظة المكتوبة).
  Future<void> rateDay(DateTime day, int rating) async {
    final DayNote? existing = noteFor(day);
    await saveNote(day, existing?.text ?? '', rating);
  }

  /// الأيام المُقيَّمة مرتبة من الأحدث (مع ملاحظاتها).
  List<DayNote> ratedNotes({bool onlyRated = true}) {
    final List<DayNote> list = notes
        .where((DayNote n) => !onlyRated || n.mood >= 0 || n.text.trim().isNotEmpty)
        .toList()
      ..sort((DayNote a, DayNote b) => b.day.compareTo(a.day));
    return list;
  }

  /// متوسط التقييمات لشهر معيّن (month = 1..12): يعيد null إن لم يوجد تقييم.
  double? averageRating(int year, int month) {
    final String prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final List<DayNote> monthNotes =
        notes.where((DayNote n) => n.day.startsWith(prefix) && n.mood >= 0).toList();
    if (monthNotes.isEmpty) return null;
    final int sum = monthNotes.fold<int>(0, (int acc, DayNote n) => acc + n.mood);
    return (sum + monthNotes.length) / monthNotes.length;
  }

  /// عدد الأيام المُقيَّمة في شهر معيّن.
  int ratedCountIn(int year, int month) {
    final String prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    return notes.where((DayNote n) => n.day.startsWith(prefix) && n.mood >= 0).length;
  }

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
      sessionsOn(clock()).fold(0, (int sum, FocusSession s) => sum + s.minutes);

  int get focusMinutesTotal => sessions.fold(0, (int sum, FocusSession s) => sum + s.minutes);

  Future<void> addFocusSession(int minutes, {String? taskId, String label = ''}) async {
    if (minutes <= 0) return;
    sessions.add(FocusSession(
      id: Ids.next('fs'),
      start: clock(),
      minutes: minutes,
      taskId: taskId,
      label: label,
    ));
    _evaluateBadges();
    markDirty();
  }

  // ===== إدارة مؤقّت التركيز =====

  /// يبدأ جلسة تركيز جديدة بالمدة المعطاة (بالدقائق).
  Future<void> startFocus(
    int minutes, {
    String? taskId,
    String label = '',
    bool isBreak = false,
  }) async {
    final int seconds = (minutes <= 0 ? 1 : minutes) * 60;
    focusTotalSeconds = seconds;
    focusStartedAt = clock();
    focusEndsAt = clock().add(Duration(seconds: seconds));
    focusPaused = false;
    focusPausedRemaining = 0;
    focusRunning = true;
    focusIsBreak = isBreak;
    focusTaskId = taskId;
    focusLabel = label;
    _focusNoticeTick = 0;
    _startFocusTicker();
    markDirty();
    await _refreshFocusNotification(force: true);
  }

  /// إيقاف مؤقت مع الاحتفاظ بالوقت المتبقي.
  Future<void> pauseFocus() async {
    if (!focusRunning || focusPaused) return;
    focusPausedRemaining = focusRemainingSeconds;
    focusPaused = true;
    focusEndsAt = null;
    markDirty();
    await _refreshFocusNotification(force: true);
  }

  /// متابعة الجلسة من حيث توقّفت.
  Future<void> resumeFocus() async {
    if (!focusRunning || !focusPaused) return;
    focusEndsAt = clock().add(Duration(seconds: focusPausedRemaining));
    focusPaused = false;
    focusPausedRemaining = 0;
    _startFocusTicker();
    markDirty();
    await _refreshFocusNotification(force: true);
  }

  /// إنهاء الجلسة يدويًا — يُسجَّل الوقت المنقضي إن بلغ دقيقة على الأقل.
  Future<void> stopFocus() async {
    if (!focusRunning) return;
    final int elapsed = focusElapsedSeconds;
    final String? taskId = focusTaskId;
    final String label = focusLabel;
    final bool isBreak = focusIsBreak;
    _clearFocus();
    markDirty();
    await notifications.cancel(focusNotifId);
    if (!isBreak && elapsed >= 60) {
      await addFocusSession(elapsed ~/ 60, taskId: taskId, label: label);
    }
  }

  void _clearFocus() {
    _focusTimer?.cancel();
    _focusTimer = null;
    focusRunning = false;
    focusPaused = false;
    focusTotalSeconds = 0;
    focusEndsAt = null;
    focusPausedRemaining = 0;
    focusStartedAt = null;
    focusTaskId = null;
    focusLabel = '';
    focusIsBreak = false;
    _focusNoticeTick = 0;
  }

  void _startFocusTicker() {
    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (_) => _focusTick());
  }

  void _focusTick() {
    if (!focusRunning) {
      _clearFocus();
      return;
    }
    if (focusPaused) return;
    if (focusRemainingSeconds <= 0) {
      unawaited(_completeFocus());
      return;
    }
    _focusNoticeTick++;
    notifyListeners();
    // تحديث شريط التقدّم كل ٥ ثوانٍ فقط (تحديث كل ثانية يُخنق في النظام).
    if (_focusNoticeTick % 5 == 0) unawaited(_refreshFocusNotification());
  }

  /// انتهاء الجلسة: يُسجَّل الوقت وتظهر تهيئة + إشعار.
  Future<void> _completeFocus() async {
    final int minutes = (focusTotalSeconds / 60).round().clamp(1, 24 * 60);
    final String? taskId = focusTaskId;
    final String label = focusLabel;
    final bool isBreak = focusIsBreak;
    _clearFocus();
    focusCompletedCount++;
    markDirty();
    await notifications.cancel(focusNotifId);
    if (isBreak) {
      notifyListeners();
      return;
    }
    await addFocusSession(minutes, taskId: taskId, label: label);
    final AppLocalizations l10n = this.l10n;
    await notifications.init(onTap: _handleNotificationTap);
    // إلغاء الإشعار الاحتياطي المجدول قبل عرض إشعار الانتهاء (نفس المعرّف).
    await notifications.cancel(focusDoneNotifId);
    await notifications.showInstant(
      id: focusDoneNotifId,
      title: l10n.t('focus.notifDone'),
      body: l10n.t('focus.wellDone', <String, String>{
        't': DateNames.duration(minutes, l10n.lang, arabicDigits: settings.arabicDigits),
      }),
      settings: settings,
      l10n: l10n,
      kind: ReminderKind.task,
      accent: AppTheme.palette(settings).accent,
    );
    notifyListeners();
  }

  /// نص الإشعار الدائم: الوقت المتبقي + وقت الانتهاء.
  String _focusNotificationBody(AppLocalizations l10n) {
    final String remaining = DateNames.duration(
      (focusRemainingSeconds / 60).ceil(),
      l10n.lang,
      arabicDigits: settings.arabicDigits,
    );
    if (focusPaused) {
      return l10n.t('focus.notifPaused', <String, String>{'t': remaining});
    }
    final DateTime? end = focusEndsAt;
    final String ends = end == null
        ? ''
        : l10n.t('focus.notifEndsAt', <String, String>{
            'time': DateNames.time(end.hour * 60 + end.minute,
                use24: settings.use24Hour, lang: l10n.lang, arabicDigits: settings.arabicDigits),
          });
    final String left = l10n.t('focus.notifRemaining', <String, String>{'t': remaining});
    return ends.isEmpty ? left : '$left · $ends';
  }

  /// يعرض/يحدّث إشعار الجلسة الجارية (شريط تقدّم + وقت).
  Future<void> _refreshFocusNotification({bool force = false}) async {
    if (!focusRunning) {
      await notifications.cancelFocusProgress(focusNotifId);
      return;
    }
    if (!force && _focusNoticeTick % 5 != 0) return;
    final AppLocalizations l10n = this.l10n;
    final String title = focusLabel.isEmpty
        ? l10n.t(focusIsBreak ? 'focus.notifBreakRunning' : 'focus.inProgress')
        : focusLabel;
    await notifications.showFocusProgress(
      id: focusNotifId,
      title: title,
      body: _focusNotificationBody(l10n),
      elapsedSeconds: focusElapsedSeconds,
      totalSeconds: focusTotalSeconds,
      settings: settings,
      l10n: l10n,
      endsAt: focusEndsAt,
      paused: focusPaused,
      accent: AppTheme.palette(settings).accent,
      // الضغط على إشعار الجلسة يفتح شاشة المؤقّت.
      payload: NotifPayload(op: 'focus', kind: ReminderKind.task.name).encode(),
    );
  }

  /// استرجاع جلسة كانت جارية قبل إغلاق التطبيق.
  Future<void> _restoreFocus() async {
    if (!focusRunning) return;
    if (focusTotalSeconds <= 0) {
      _clearFocus();
      return;
    }
    if (focusPaused) {
      _focusNoticeTick = 0;
      await _refreshFocusNotification(force: true);
      return;
    }
    final DateTime? end = focusEndsAt;
    if (end == null) {
      _clearFocus();
      return;
    }
    if (!end.isAfter(clock())) {
      // انتهت الجلسة أثناء غيابك: نُسجّل الوقت كاملًا دون إشعار مكرّر.
      final int minutes = (focusTotalSeconds / 60).round().clamp(1, 24 * 60);
      final String? taskId = focusTaskId;
      final String label = focusLabel;
      final bool isBreak = focusIsBreak;
      _clearFocus();
      focusCompletedCount++;
      markDirty();
      if (isBreak) return;
      await addFocusSession(minutes, taskId: taskId, label: label);
      // إن كانت الجلسة انتهت قبل قليل، نُظهر الإشعار (نفس معرّف الاحتياطي،
      // فإن كان قد ظهر فعلًا يُحدَّث بدل أن يتكرّر).
      if (clock().difference(end).inMinutes <= 10) {
        await notifications.showInstant(
          id: focusDoneNotifId,
          title: l10n.t('focus.notifDone'),
          body: l10n.t('focus.wellDone', <String, String>{
            't': DateNames.duration(minutes, l10n.lang, arabicDigits: settings.arabicDigits),
          }),
          settings: settings,
          l10n: l10n,
          kind: ReminderKind.task,
          accent: AppTheme.palette(settings).accent,
        );
      }
      return;
    }
    _startFocusTicker();
    await _refreshFocusNotification(force: true);
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
      notes: notes,
      windowDays: 16,
    );
    // تذكير انتهاء جلسة التركيز: يُجدول كإشعار عادي حتى يصل وقتها حتى لو
    // أُغلق التطبيق بالكامل (sync يلغي كل الإشعارات ثم يعيد الجدولة).
    final DateTime? focusEnd = focusEndsAt;
    if (focusRunning && !focusPaused && focusEnd != null && focusEnd.isAfter(DateTime.now())) {
      final int minutes = (focusTotalSeconds / 60).round().clamp(1, 24 * 60);
      planned.add(PlannedReminder(
        id: focusDoneNotifId,
        key: 'focus:done',
        when: focusEnd,
        kind: ReminderKind.task,
        title: l10n.t('focus.notifDone'),
        body: l10n.t('focus.wellDone', <String, String>{
          't': DateNames.duration(minutes, l10n.lang, arabicDigits: settings.arabicDigits),
        }),
        withActions: false,
      ));
      planned.sort((PlannedReminder a, PlannedReminder b) => a.when.compareTo(b.when));
    }
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
    // sync يلغي كل الإشعارات المعروضة، فنُعيد إظهار إشعار الجلسة الجارية.
    if (focusRunning) await _refreshFocusNotification(force: true);
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
    // منبّه مهمة عاجلة: تُفتح شاشة المنبّه كاملة بدل التنقّل العادي.
    if (payload.op == 'alarm' && payload.taskId != null) {
      openAlarm(payload.taskId!);
      return;
    }
    // تفتح الواجهة التفاصيل بناءً على المحتوى — يُستهلك في RootShell
    lastTappedPayload = payload;
    notifyListeners();
  }

  // ===== المنبّه (المهام العاجلة) =====

  /// المهمة التي يرنّ منبّهها الآن — تعرض شاشة المنبّه كاملة فوق كل شيء.
  String? activeAlarmTaskId;

  Task? get activeAlarmTask =>
      activeAlarmTaskId == null ? null : taskById(activeAlarmTaskId!);

  /// مفاتيح المنبّهات التي رنّت (أو أُنجزت/أُجّلت) فلا تتكرّر في نفس اليوم.
  final Set<String> _alarmShown = <String>{};

  /// مهمّات عاجلة حان وقتها ولم يُعرض منبّهها بعد.
  ///
  /// تعمل داخل التطبيق نفسه كلما كان مفتوحًا — حتى لو منع النظام الشاشة
  /// الكاملة للإشعار، فالمنبّه يظهر في التطبيق.
  Task? dueAlarmTask({DateTime? at}) {
    if (!settings.alarmEnabled) return null;
    if (activeAlarmTaskId != null) return null;
    final DateTime now = at ?? clock();
    final List<Task> candidates = tasks
        .where((Task t) =>
            !t.done &&
            !t.skipped &&
            t.priority == TaskPriority.urgent &&
            t.startMinutes != null &&
            Dates.sameDay(t.date, now))
        .toList()
      ..sort((Task a, Task b) => (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0));
    for (final Task task in candidates) {
      final int minute = task.startMinutes!;
      final DateTime when = Dates.at(task.date, minute);
      if (when.isAfter(now)) continue;
      // نسمح بالرنّ خلال ٣٠ دقيقة من وقتها (لا منبّهات قديمة من الصباح).
      if (now.difference(when).inMinutes > 30) continue;
      if (_alarmShown.contains('${task.id}:${Dates.key(task.date)}:$minute')) continue;
      return task;
    }
    return null;
  }

  /// يفتح المنبّه إن حان وقت مهمة عاجلة (تُستدعى دوريًا من الواجهة).
  /// يعيد true إن فُتح منبّه الآن — كي لا تُعاد بناء الواجهة بلا داعٍ.
  bool checkDueAlarm() {
    final Task? task = dueAlarmTask();
    if (task == null) return false;
    _alarmShown.add('${task.id}:${Dates.key(task.date)}:${task.startMinutes}');
    openAlarm(task.id);
    return true;
  }

  /// «تجربة المنبّه»: نُظهره فورًا على مهمة عاجلة قادمة أو على أي مهمة.
  Future<bool> testAlarm() async {
    final DateTime now = clock();
    final Task urgent = tasks.firstWhere(
      (Task t) => !t.done && t.priority == TaskPriority.urgent && Dates.sameDay(t.date, now),
      orElse: () => tasks.firstWhere(
        (Task t) => !t.done && t.startMinutes != null && Dates.sameDay(t.date, now),
        orElse: () => Task(
          id: 'alarm_test',
          title: l10n.t('alarm.testTaskTitle'),
          date: Dates.day(now),
          priority: TaskPriority.urgent,
          startMinutes: Dates.nowMinutes(),
          notes: l10n.t('alarm.testTaskNotes'),
        ),
      ),
    );
    if (!tasks.any((Task t) => t.id == urgent.id)) {
      tasks.add(urgent);
      markDirty();
    }
    openAlarm(urgent.id);
    return true;
  }

  void openAlarm(String taskId) {
    if (taskById(taskId) == null) return;
    activeAlarmTaskId = taskId;
    notifyListeners();
  }

  void closeAlarm() {
    if (activeAlarmTaskId == null) return;
    activeAlarmTaskId = null;
    notifyListeners();
  }

  /// إنجاز المهمة من شاشة المنبّه.
  Future<void> completeAlarm() async {
    final Task? task = activeAlarmTask;
    closeAlarm();
    if (task == null || task.done) return;
    task.done = true;
    task.completedAt = DateTime.now();
    for (final Subtask s in task.subtasks) {
      s.done = true;
    }
    _evaluateBadges();
    _checkCelebration();
    markDirty();
    _scheduleReminderRebuild();
  }

  /// تأجيل المنبّه: يُجدول منبّه آخر بعد d دقائق بنفس المهمة.
  Future<void> snoozeAlarm(int minutes) async {
    final Task? task = activeAlarmTask;
    closeAlarm();
    if (task == null) return;
    final AppLocalizations l10n = AppLocalizations.ofLocale(Locale(settings.language));
    final int id = notifId(
      '${ReminderKind.alarm}:snooze:${task.id}:${DateTime.now().millisecondsSinceEpoch}',
    );
    await notifications.init(onTap: _handleNotificationTap);
    await notifications.scheduleAlarmLater(
      id: id,
      taskId: task.id,
      minutes: minutes,
      settings: settings,
      l10n: l10n,
      title: task.title,
      accent: AppTheme.palette(settings).accent,
    );
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
      if (type == 'rate') {
        final int value = (op['value'] as num?)?.toInt() ?? -1;
        final String? dayKey = op['day']?.toString();
        if (value >= 0 && dayKey != null) {
          final DateTime? day = Dates.parseKey(dayKey);
          if (day != null) {
            final DayNote? existing = noteFor(day);
            final int index = notes.indexWhere((DayNote n) => n.day == dayKey);
            if (index >= 0) {
              notes[index].mood = value;
              notes[index].updatedAt = DateTime.now();
            } else {
              notes.add(DayNote(
                day: dayKey,
                text: existing?.text ?? '',
                mood: value,
                updatedAt: DateTime.now(),
              ));
            }
          }
        }
        continue;
      }
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

  /// يتحقق من الرمز ويعيد النتيجة (بدون تغيير حالة القفل).
  /// يعمل في عزلة منفصلة حتى لا تتجمّد الواجهة أثناء PBKDF2.
  Future<bool> verifyLockPin(String pin) async {
    if (!lockEnabled) return true;
    final Map<String, dynamic> result = await _runTask(
      verifyPinTask,
      <String, dynamic>{'password': pin, 'hash': settings.lockHash},
    );
    return result['ok'] == true;
  }

  /// يتحقق من الرمز ويفتح التطبيق عند صحّته.
  Future<bool> unlock(String password) async {
    if (!lockEnabled) {
      locked = false;
      notifyListeners();
      return true;
    }
    final bool ok = await verifyLockPin(password);
    if (ok) {
      locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// تفعيل القفل برمز أرقام جديد (يُحفظ عدد أرقامه لعرض النقاط).
  Future<void> setLockPassword(String password, {int? pinLength}) async {
    final Map<String, dynamic> result = await _runTask(
      hashPinTask,
      <String, dynamic>{'password': password, 'iterations': pinIterations},
    );
    final String hash = (result['data'] ?? '').toString();
    if (hash.isEmpty) return;
    await updateSettings(settings.copyWith(
      lockEnabled: true,
      lockHash: hash,
      lockPinLength: AppSettings.clampPinLength(
          pinLength ?? (password.length >= AppSettings.minPinLength ? password.length : AppSettings.minPinLength)),
    ));
    locked = false;
    notifyListeners();
  }

  /// تعديل خيارات القفل (فتح تلقائي / عدد الأرقام).
  Future<void> updateLockOptions({bool? autoUnlock, int? pinLength}) async {
    await updateSettings(settings.copyWith(
      lockAutoUnlock: autoUnlock,
      lockPinLength: pinLength,
    ));
  }

  /// إلغاء القفل نهائيًا (بعد التحقق من الرمز الحالي في الواجهة).
  Future<void> removeLock() async {
    await updateSettings(settings.copyWith(lockEnabled: false, lockHash: '', lockPinLength: 0));
    locked = false;
    notifyListeners();
  }

  /// عند انتقال التطبيق للخلفية.
  void handleBackgrounded() {
    _backgroundedAt = DateTime.now();
    _lockTimer?.cancel();
    if (lockEnabled && settings.lockWhenBackground) {
      if (settings.lockGraceSeconds <= 0) {
        locked = true;
      } else {
        // حتى لو لم يعُد التطبيق للواجهة، يُقفل بعد انتهاء المهلة (مؤقّت داخلي).
        _lockTimer = Timer(Duration(seconds: settings.lockGraceSeconds), () {
          if (!lockEnabled || !settings.lockWhenBackground) return;
          if (locked) return;
          locked = true;
          notifyListeners();
        });
      }
    }
    // آخر تحديث لإشعار جلسة التركيز قبل تجميد التطبيق في الخلفية.
    if (focusRunning) unawaited(_refreshFocusNotification(force: true));
    notifyListeners();
  }

  /// عند العودة للتطبيق — يقفل إذا انتهت مهلة السماح.
  void handleResumed() {
    final DateTime? at = _backgroundedAt;
    _backgroundedAt = null;
    _lockTimer?.cancel();
    _inactiveTimer?.cancel();
    if (!lockEnabled) {
      if (locked) locked = false;
      notifyListeners();
      return;
    }
    if (at != null && settings.lockWhenBackground) {
      final int away = DateTime.now().difference(at).inSeconds;
      if (away >= settings.lockGraceSeconds) locked = true;
    }
    // الجلسة قد تكون انتهت أثناء غيابنا — نُحدّث الحالة والإشعار.
    if (focusRunning) {
      if (!focusPaused && focusRemainingSeconds <= 0) {
        unawaited(_completeFocus());
      } else {
        if (!focusPaused) _startFocusTicker();
        unawaited(_refreshFocusNotification(force: true));
      }
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
    if (!useIsolates || _inTestRun()) return task(args);
    return compute(task, args);
  }

  /// ترميز البيانات نصًّا: في عزلة منفصلة إن أمكن، مع مهلة زمنية تُكمل العمل
  /// على الخيط الرئيسي إن لم تستجب العزلة — فلا يبقى الحفظ معلّقًا أبدًا.
  Future<String> _encodeData(Map<String, dynamic> data) async {
    if (!useIsolates || _inTestRun()) return encodeDataTask(data);
    try {
      return await compute(encodeDataTask, data).timeout(const Duration(seconds: 6));
    } catch (_) {
      return encodeDataTask(data);
    }
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
    _clearFocus();
    focusCompletedCount = 0;
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

  @override
  void dispose() {
    _lockTimer?.cancel();
    _inactiveTimer?.cancel();
    _focusTimer?.cancel();
    _saveTimer?.cancel();
    _reminderTimer?.cancel();
    super.dispose();
  }
}
