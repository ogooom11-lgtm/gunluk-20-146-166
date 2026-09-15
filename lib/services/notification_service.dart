import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/enums.dart';
import '../core/l10n/app_strings.dart';
import '../core/models/app_settings.dart';
import '../core/models/planned_reminder.dart';
import '../data/app_repository.dart';
import 'tz_service.dart';

/// معرّفات أزرار الإشعار.
class NotifAction {
  NotifAction._();
  static const String done = 'act_done';
  static const String snooze = 'act_snooze';
}

/// محتوى الإشعار المرمّز داخل الحقل payload — يسمح بإعادة جدولة التذكير
/// من معالج الخلفية بدون الحاجة لقراءة بيانات التطبيق كاملة.
class NotifPayload {
  const NotifPayload({
    required this.op,
    required this.kind,
    this.taskId,
    this.day,
    this.title = '',
    this.body = '',
    this.lines = const <String>[],
  });

  /// task | review | morning | focus
  final String op;
  final String kind;
  final String? taskId;
  final String? day;
  final String title;
  final String body;
  final List<String> lines;

  String encode() => jsonEncode(<String, dynamic>{
        'o': op,
        'k': kind,
        'i': taskId,
        'd': day,
        't': title,
        'b': body,
        'l': lines,
      });

  static NotifPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      final List<String> lines = <String>[];
      final dynamic rawLines = map['l'];
      if (rawLines is List) {
        for (final dynamic v in rawLines) {
          if (v != null) lines.add(v.toString());
        }
      }
      return NotifPayload(
        op: (map['o'] ?? 'task').toString(),
        kind: (map['k'] ?? ReminderKind.task.name).toString(),
        taskId: map['i']?.toString(),
        day: map['d']?.toString(),
        title: (map['t'] ?? '').toString(),
        body: (map['b'] ?? '').toString(),
        lines: lines,
      );
    } catch (_) {
      return null;
    }
  }
}

typedef NotifTapHandler = void Function(NotifPayload payload);

/// كل التعامل مع نظام الإشعارات: القنوات، الأصوات، الجدولة، الأزرار.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static final NotificationService instance = NotificationService();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  bool _exactAllowed = false;
  String _channelVersion = '';

  NotifTapHandler? onTap;

  bool get exactAllowed => _exactAllowed;

  bool get isInitialized => _initialized;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// أيقونة الحالة (أحادية اللون).
  static const String statusIcon = 'ic_stat_injaz';

  Future<void> init({NotifTapHandler? onTap}) async {
    if (onTap != null) this.onTap = onTap;
    if (_initialized) return;
    TzService.ensure();
    const AndroidInitializationSettings android = AndroidInitializationSettings(statusIcon);
    const InitializationSettings settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _initialized = true;
    await refreshExactStatus();
  }

  Future<void> refreshExactStatus() async {
    try {
      _exactAllowed = await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _exactAllowed = false;
    }
  }

  void _handleResponse(NotificationResponse response) {
    final NotifPayload? payload = NotifPayload.decode(response.payload);
    if (payload == null) return;
    onTap?.call(payload);
  }

  // ===== الأذونات =====

  Future<bool> requestNotificationPermission() async {
    try {
      final bool? granted = await _android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestExactAlarmPermission() async {
    try {
      final bool? granted = await _android?.requestExactAlarmsPermission();
      await refreshExactStatus();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      return await _android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  // ===== القنوات =====

  /// إنشاء قنوات الإشعارات (صوت/اهتزاز/خصوصية). عند تغيير الإعدادات
  /// تُنشأ قنوات جديدة بحُزمة إصدار مختلفة وتُحذف القديمة.
  Future<void> ensureChannels(AppSettings settings, AppLocalizations l10n) async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) return;
    final String version = settings.channelVersion;
    if (_channelVersion == version) return;
    _channelVersion = version;

    final AndroidNotificationSound? sound = settings.sound.resource == null
        ? null
        : RawResourceAndroidNotificationSound(settings.sound.resource!);
    final bool playSound = settings.sound.resource != null;
    final bool vibrate = settings.vibration != AppVibration.off;
    final Int64List? pattern = settings.vibration.pattern;

    try {
      await android.createNotificationChannelGroup(
        AndroidNotificationChannelGroup('injaz_group', l10n.t('notif.channelGroupName')),
      );
    } catch (_) {}

    for (final ReminderKind kind in ReminderKind.values) {
      try {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            kind.channelId(version),
            l10n.t(kind.nameKey),
            description: l10n.t(kind.descKey),
            groupId: 'injaz_group',
            importance: _importanceFor(kind),
            playSound: playSound,
            sound: sound,
            enableVibration: vibrate,
            vibrationPattern: pattern,
            showBadge: kind == ReminderKind.task || kind == ReminderKind.review,
          ),
        );
      } catch (_) {}
    }

    // حذف قنوات الإصدارات القديمة حتى لا تتكدّس في إعدادات النظام
    try {
      final List<AndroidNotificationChannel>? existing = await android.getNotificationChannels();
      if (existing != null) {
        for (final AndroidNotificationChannel channel in existing) {
          if (channel.id.startsWith('injaz_') && !channel.id.endsWith(version)) {
            await android.deleteNotificationChannel(channel.id);
          }
        }
      }
    } catch (_) {}
  }

  Importance _importanceFor(ReminderKind kind) {
    switch (kind) {
      case ReminderKind.task:
      case ReminderKind.review:
      case ReminderKind.nudge:
        return Importance.high;
      case ReminderKind.upcoming:
      case ReminderKind.morning:
        return Importance.defaultImportance;
    }
  }

  Priority _priorityFor(ReminderKind kind) {
    switch (kind) {
      case ReminderKind.task:
      case ReminderKind.review:
      case ReminderKind.nudge:
        return Priority.high;
      case ReminderKind.upcoming:
      case ReminderKind.morning:
        return Priority.defaultPriority;
    }
  }

  // ===== الجدولة =====

  /// مزامنة كامل جدول التذكيرات: إلغاء القديم ثم جدولة القائمة الجديدة.
  Future<void> sync(
    List<PlannedReminder> reminders,
    AppSettings settings,
    AppLocalizations l10n, {
    Color? accent,
  }) async {
    if (!_initialized) await init();
    await ensureChannels(settings, l10n);
    await cancelAll();
    if (!settings.notificationsEnabled) return;
    for (final PlannedReminder reminder in reminders) {
      await schedule(reminder, settings, l10n, accent: accent);
    }
  }

  Future<void> schedule(
    PlannedReminder reminder,
    AppSettings settings,
    AppLocalizations l10n, {
    Color? accent,
  }) async {
    final String channelId = reminder.kind.channelId(settings.channelVersion);
    final AndroidNotificationSound? sound = settings.sound.resource == null
        ? null
        : RawResourceAndroidNotificationSound(settings.sound.resource!);
    final List<String> actions = <String>[];
    if (settings.actionButtons) {
      actions.add(NotifAction.done);
      actions.add(NotifAction.snooze);
    }
    final String payload = NotifPayload(
      op: _opFor(reminder.kind),
      kind: reminder.kind.name,
      taskId: reminder.taskId,
      day: reminder.when.toIso8601String().substring(0, 10),
      title: reminder.title,
      body: reminder.body,
      lines: reminder.lines,
    ).encode();

    final AndroidNotificationDetails android = AndroidNotificationDetails(
      channelId,
      l10n.t(reminder.kind.nameKey),
      channelDescription: l10n.t(reminder.kind.descKey),
      icon: statusIcon,
      importance: _importanceFor(reminder.kind),
      priority: _priorityFor(reminder.kind),
      color: accent,
      colorized: accent != null && reminder.kind == ReminderKind.review,
      playSound: settings.sound.resource != null,
      sound: sound,
      enableVibration: settings.vibration != AppVibration.off,
      vibrationPattern: settings.vibration.pattern,
      category: AndroidNotificationCategory.reminder,
      styleInformation: reminder.lines.isEmpty
          ? BigTextStyleInformation(reminder.body, contentTitle: reminder.title, summaryText: l10n.t('app.name'))
          : InboxStyleInformation(reminder.lines,
              contentTitle: reminder.title, summaryText: reminder.body),
      groupKey: settings.groupNotifications ? 'injaz_group' : null,
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      actions: <AndroidNotificationAction>[
        for (final String action in actions)
          AndroidNotificationAction(
            action,
            action == NotifAction.done
                ? l10n.t('notif.actionDone')
                : l10n.t('notif.actionSnooze', <String, String>{'n': '${settings.snoozeMinutes}'}),
            cancelNotification: action == NotifAction.done,
            showsUserInterface: false,
          ),
      ],
      ticker: reminder.title,
      subText: l10n.t('app.name'),
      onlyAlertOnce: reminder.kind == ReminderKind.nudge,
      autoCancel: true,
    );

    try {
      await _plugin.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.body,
        TzService.from(reminder.when),
        NotificationDetails(android: android),
        androidScheduleMode: _exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (_) {
      // قد يفشل الجدول الدقيق بدون الإذن — نعيد المحاولة بشكل غير دقيق
      try {
        await _plugin.zonedSchedule(
          reminder.id,
          reminder.title,
          reminder.body,
          TzService.from(reminder.when),
          NotificationDetails(android: android),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (_) {}
    }
  }

  String _opFor(ReminderKind kind) {
    switch (kind) {
      case ReminderKind.review:
        return 'review';
      case ReminderKind.morning:
        return 'morning';
      default:
        return 'task';
    }
  }

  /// إشعار فوري (معاينة أو انتهاء مؤقّت التركيز).
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    required AppSettings settings,
    required AppLocalizations l10n,
    ReminderKind kind = ReminderKind.task,
    Color? accent,
    String? payload,
  }) async {
    if (!_initialized) await init();
    await ensureChannels(settings, l10n);
    final AndroidNotificationSound? sound = settings.sound.resource == null
        ? null
        : RawResourceAndroidNotificationSound(settings.sound.resource!);
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kind.channelId(settings.channelVersion),
          l10n.t(kind.nameKey),
          channelDescription: l10n.t(kind.descKey),
          icon: statusIcon,
          importance: _importanceFor(kind),
          priority: _priorityFor(kind),
          color: accent,
          playSound: settings.sound.resource != null,
          sound: sound,
          enableVibration: settings.vibration != AppVibration.off,
          vibrationPattern: settings.vibration.pattern,
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
          largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
          subText: l10n.t('app.name'),
          autoCancel: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<int> pendingCount() async {
    try {
      final List<PendingNotificationRequest> list = await _plugin.pendingNotificationRequests();
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> cancelTaskReminders(String? taskId) async {
    if (taskId == null) return;
    try {
      final List<PendingNotificationRequest> list = await _plugin.pendingNotificationRequests();
      for (final PendingNotificationRequest item in list) {
        final NotifPayload? payload = NotifPayload.decode(item.payload);
        if (payload?.taskId == taskId) {
          await _plugin.cancel(item.id);
        }
      }
    } catch (_) {}
  }
}

/// معالج الإشعارات في الخلفية (زر «أنجزت» أو «تأجيل» بدون فتح التطبيق).
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  try {
    final NotifPayload? payload = NotifPayload.decode(response.payload);
    if (payload == null) return;
    final AppRepository repo = AppRepository();
    await repo.ensure();

    if (response.actionId == NotifAction.done) {
      await repo.pushOp(<String, dynamic>{
        'op': 'done',
        'taskId': payload.taskId,
        'at': DateTime.now().toIso8601String(),
      });
      final NotificationService service = NotificationService();
      await service.cancelTaskReminders(payload.taskId);
      return;
    }

    if (response.actionId == NotifAction.snooze) {
      final AppSettings settings = AppSettings.fromJson(AppRepository.map(repo.read()['settings']));
      final AppLocalizations l10n = AppLocalizations.ofLocale(Locale(settings.language));
      final NotificationService service = NotificationService();
      TzService.ensure();
      await service.init();
      await service.ensureChannels(settings, l10n);
      final DateTime when = DateTime.now().add(Duration(minutes: settings.snoozeMinutes));
      final int id = ('snooze_${payload.taskId ?? 'x'}_${when.millisecondsSinceEpoch}').hashCode & 0x3FFFFFF;
      await service.schedule(
        PlannedReminder(
          id: id,
          key: 'snooze:${payload.taskId}',
          when: when,
          kind: ReminderKind.fromName(payload.kind),
          title: payload.title,
          body: payload.body,
          lines: payload.lines,
          taskId: payload.taskId,
        ),
        settings,
        l10n,
      );
      await repo.pushOp(<String, dynamic>{
        'op': 'snoozed',
        'taskId': payload.taskId,
        'at': when.toIso8601String(),
      });
    }
  } catch (_) {
    // لا نريد إسقاط أي استثناء في الخلفية
  }
}
