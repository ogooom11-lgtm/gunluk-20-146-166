import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/l10n/app_strings.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/settings_tiles.dart';

/// إعدادات الإشعارات: المواعيد، الصوت، الاهتزاز، الخصوصية، والأذونات.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _busy = false;

  /// عدد التذكيرات المجدولة فعليًا في النظام (null = لم يُقرأ بعد).
  int? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshScheduled());
  }

  /// يعيد جدولة التذكيرات ثم يقرأ عددها من نظام الإشعارات — يفيد في التأكد
  /// أن الإشعارات مجدولة فعلًا على الجهاز.
  Future<void> _refreshScheduled() async {
    final app = context.appRead;
    await app.rebuildReminders(immediate: true);
    final int count = await app.pendingReminderCount();
    if (!mounted) return;
    setState(() => _pending = count);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.tr('notif.refreshed', <String, String>{'n': context.numStr(count)}))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final settings = app.settings;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('notif.title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 40),
        children: <Widget>[
          if (!app.systemNotificationsAllowed)
            AppCard(
              color: const Color(0xFFE05B5B).withAlpha(context.isDark ? 45 : 20),
              onTap: _askPermission,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.notifications_off_rounded, color: Color(0xFFE05B5B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(context.tr('home.notificationsOff'), style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 3),
                        Text(context.tr('notif.permissions'), style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded),
                ],
              ),
            ),
          if (!app.systemNotificationsAllowed) const SizedBox(height: 14),
          SettingsGroup(
            title: context.tr('notif.title'),
            subtitle: context.tr('notif.channelNote'),
            icon: Icons.notifications_active_rounded,
            children: <Widget>[
              SettingsSwitchTile(
                title: context.tr('common.on'),
                subtitle: context.tr('notif.title'),
                icon: Icons.toggle_on_rounded,
                value: settings.notificationsEnabled,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(notificationsEnabled: value),
                  rescheduleNotifications: true,
                ),
              ),
              SettingsSwitchTile(
                title: context.tr('notif.evening'),
                subtitle: context.tr('notif.eveningDesc'),
                icon: Icons.nightlight_round,
                value: settings.eveningEnabled,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(eveningEnabled: value),
                  rescheduleNotifications: true,
                ),
              ),
              SettingsValueTile(
                title: context.tr('notif.eveningTime'),
                subtitle: context.tr('notif.eveningDesc'),
                value: context.timeStr(settings.eveningMinutes),
                icon: Icons.schedule_rounded,
                onTap: () async {
                  final int? picked = await showTimeWheelSheet(
                    context,
                    initialMinutes: settings.eveningMinutes,
                    title: context.tr('notif.eveningTime'),
                  );
                  if (picked != null && picked >= 0) {
                    await app.updateSettings(
                      settings.copyWith(eveningMinutes: picked),
                      rescheduleNotifications: true,
                    );
                  }
                },
              ),
              SettingsSwitchTile(
                title: context.tr('notif.morning'),
                subtitle: context.tr('notif.morningDesc'),
                icon: Icons.wb_sunny_rounded,
                value: settings.morningEnabled,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(morningEnabled: value),
                  rescheduleNotifications: true,
                ),
              ),
              SettingsValueTile(
                title: context.tr('notif.morningTime'),
                value: context.timeStr(settings.morningMinutes),
                icon: Icons.alarm_rounded,
                onTap: () async {
                  final int? picked = await showTimeWheelSheet(
                    context,
                    initialMinutes: settings.morningMinutes,
                    title: context.tr('notif.morningTime'),
                  );
                  if (picked != null && picked >= 0) {
                    await app.updateSettings(
                      settings.copyWith(morningMinutes: picked),
                      rescheduleNotifications: true,
                    );
                  }
                },
              ),
              SettingsSwitchTile(
                title: context.tr('notif.nudges'),
                subtitle: context.tr('notif.nudgesDesc'),
                icon: Icons.campaign_rounded,
                value: settings.nudgesEnabled,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(nudgesEnabled: value),
                  rescheduleNotifications: true,
                ),
              ),
              SettingsValueTile(
                title: context.tr('notif.nudgeInterval'),
                value: context.durStr(settings.nudgeIntervalMinutes),
                icon: Icons.timer_outlined,
                onTap: () async {
                  final int? picked = await showChoiceSheet<int>(
                    context,
                    title: context.tr('notif.nudgeInterval'),
                    value: settings.nudgeIntervalMinutes,
                    options: <ChoiceItem<int>>[
                      for (final int minutes in <int>[15, 20, 30, 45, 60, 90, 120])
                        ChoiceItem<int>(value: minutes, label: context.durStr(minutes), icon: Icons.timer_outlined),
                    ],
                  );
                  if (picked != null) {
                    await app.updateSettings(
                      settings.copyWith(nudgeIntervalMinutes: picked),
                      rescheduleNotifications: true,
                    );
                  }
                },
              ),
              SettingsValueTile(
                title: context.tr('notif.maxNudges'),
                value: context.numStr(settings.maxNudges),
                icon: Icons.repeat_rounded,
                onTap: () async {
                  final int? picked = await showChoiceSheet<int>(
                    context,
                    title: context.tr('notif.maxNudges'),
                    value: settings.maxNudges,
                    options: <ChoiceItem<int>>[
                      for (final int count in <int>[1, 2, 3, 4, 5])
                        ChoiceItem<int>(value: count, label: context.numStr(count), icon: Icons.numbers_rounded),
                    ],
                  );
                  if (picked != null) {
                    await app.updateSettings(
                      settings.copyWith(maxNudges: picked),
                      rescheduleNotifications: true,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('sound.title'),
            subtitle: context.tr('notif.channelNote'),
            icon: Icons.music_note_rounded,
            children: <Widget>[
              SettingsValueTile(
                title: context.tr('notif.sound'),
                value: context.tr(settings.sound.labelKey),
                icon: Icons.audiotrack_rounded,
                onTap: () async {
                  final AppSound? picked = await showChoiceSheet<AppSound>(
                    context,
                    title: context.tr('notif.sound'),
                    value: settings.sound,
                    options: <ChoiceItem<AppSound>>[
                      for (final AppSound sound in AppSound.values)
                        ChoiceItem<AppSound>(
                          value: sound,
                          label: context.tr(sound.labelKey),
                          icon: sound == AppSound.silent ? Icons.volume_off_rounded : Icons.graphic_eq_rounded,
                        ),
                    ],
                  );
                  if (picked != null) {
                    await app.updateSettings(
                      settings.copyWith(sound: picked),
                      rescheduleNotifications: true,
                    );
                  }
                },
              ),
              SettingsValueTile(
                title: context.tr('notif.vibration'),
                value: context.tr(settings.vibration.labelKey),
                icon: Icons.vibration_rounded,
                onTap: () async {
                  final AppVibration? picked = await showChoiceSheet<AppVibration>(
                    context,
                    title: context.tr('notif.vibration'),
                    value: settings.vibration,
                    options: <ChoiceItem<AppVibration>>[
                      for (final AppVibration vibrate in AppVibration.values)
                        ChoiceItem<AppVibration>(
                          value: vibrate,
                          label: context.tr(vibrate.labelKey),
                          icon: vibrate == AppVibration.off
                              ? Icons.vibration_rounded
                              : Icons.phone_android_rounded,
                        ),
                    ],
                  );
                  if (picked != null) {
                    await app.updateSettings(
                      settings.copyWith(vibration: picked),
                      rescheduleNotifications: true,
                    );
                  }
                },
              ),
              SettingsSwitchTile(
                title: context.tr('notif.privacyMode'),
                subtitle: context.tr('notif.privacyModeDesc'),
                icon: Icons.visibility_off_rounded,
                value: settings.privacyMode,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(privacyMode: value),
                  rescheduleNotifications: true,
                ),
              ),
              SettingsSwitchTile(
                title: context.tr('notif.actionDone'),
                subtitle: context.tr('notif.actionSnooze', <String, String>{'n': context.numStr(settings.snoozeMinutes)}),
                icon: Icons.bolt_rounded,
                value: settings.actionButtons,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(actionButtons: value),
                  rescheduleNotifications: true,
                ),
              ),
              SettingsValueTile(
                title: context.tr('settings.snooze'),
                value: context.durStr(settings.snoozeMinutes),
                icon: Icons.snooze_rounded,
                onTap: () async {
                  final int? picked = await showChoiceSheet<int>(
                    context,
                    title: context.tr('settings.snooze'),
                    value: settings.snoozeMinutes,
                    options: <ChoiceItem<int>>[
                      for (final int minutes in <int>[5, 10, 15, 30, 60])
                        ChoiceItem<int>(value: minutes, label: context.durStr(minutes), icon: Icons.snooze_rounded),
                    ],
                  );
                  if (picked != null) await app.updateSettings(settings.copyWith(snoozeMinutes: picked));
                },
              ),
              SettingsValueTile(
                title: context.tr('settings.defaultLead'),
                value: context.durStr(settings.defaultLeadMinutes),
                icon: Icons.notifications_paused_rounded,
                onTap: () async {
                  final int? picked = await showChoiceSheet<int>(
                    context,
                    title: context.tr('settings.defaultLead'),
                    value: settings.defaultLeadMinutes,
                    options: <ChoiceItem<int>>[
                      for (final int minutes in <int>[0, 5, 10, 15, 30, 60, 120, 1440])
                        ChoiceItem<int>(
                          value: minutes,
                          label: minutes == 0 ? context.tr('calendar.now') : context.durStr(minutes),
                          icon: Icons.notifications_none_rounded,
                        ),
                    ],
                  );
                  if (picked != null) await app.updateSettings(settings.copyWith(defaultLeadMinutes: picked));
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('notif.permissions'),
            icon: Icons.verified_user_rounded,
            children: <Widget>[
              SettingsTile(
                title: context.tr('notif.permissionNotif'),
                icon: Icons.notifications_rounded,
                trailing: Pill(
                  label: context.tr(app.systemNotificationsAllowed ? 'notif.granted' : 'notif.denied'),
                  color: app.systemNotificationsAllowed ? const Color(0xFF43A047) : const Color(0xFFE05B5B),
                  dense: true,
                ),
                onTap: _askPermission,
              ),
              SettingsTile(
                title: context.tr('notif.permissionExact'),
                subtitle: context.tr('notif.batteryDesc'),
                icon: Icons.alarm_on_rounded,
                onTap: () async {
                  final bool ok = await app.notifications.requestExactAlarmPermission();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(context.tr(ok ? 'notif.granted' : 'toast.permissionDenied'))),
                    );
                },
              ),
              SettingsTile(
                title: context.tr('notif.scheduled'),
                subtitle: app.nextReminderAt == null
                    ? context.tr('notif.noneScheduled')
                    : context.tr('notif.nextAt', <String, String>{
                        'when': '${context.relativeDay(app.nextReminderAt!)} — '
                            '${context.timeStr(app.nextReminderAt!.hour * 60 + app.nextReminderAt!.minute)}',
                      }),
                icon: Icons.update_rounded,
                onTap: _refreshScheduled,
                trailing: _pending == null
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Pill(
                        label: context.numStr(_pending!),
                        color: _pending! > 0 ? const Color(0xFF43A047) : const Color(0xFFE0A02E),
                        dense: true,
                      ),
              ),
              SettingsTile(
                title: context.tr('notif.preview'),
                // نفس القيم التجريبية التي يرسلها الإشعار التجريبي
                subtitle: context.tr('notif.summaryBody', <String, String>{
                  'done': '3',
                  'total': '7',
                  'left': '4',
                }),
                icon: Icons.send_rounded,
                onTap: () async {
                  setState(() => _busy = true);
                  final bool sent = await app.sendPreviewNotification();
                  if (!mounted) return;
                  setState(() => _busy = false);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(context.tr(sent ? 'notif.previewSent' : 'notif.previewFailed')),
                    ));
                },
                trailing: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            color: context.palette.seed.withAlpha(context.isDark ? 40 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.tips_and_updates_rounded, size: 18, color: context.palette.seed),
                    const SizedBox(width: 8),
                    Text(context.tr('notif.batteryTitle'), style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 6),
                Text(context.tr('notif.batteryDesc'), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(title: context.tr('notif.nudges'), icon: Icons.bolt_rounded),
          Row(
            children: <Widget>[
              for (final AppVibration vibrate in AppVibration.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Pill(
                      label: context.tr(vibrate.labelKey),
                      color: settings.vibration == vibrate ? context.palette.seed : null,
                      filled: settings.vibration == vibrate,
                      dense: true,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsValueTile(
            title: context.tr('notif.sound'),
            value: context.tr(settings.sound.labelKey),
            icon: Icons.play_circle_outline_rounded,
            onTap: _previewSound,
          ),
        ],
      ),
    );
  }

  Future<void> _askPermission() async {
    final app = context.appRead;
    final bool granted = await app.notifications.requestNotificationPermission();
    await app.refreshSystemNotificationState();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.tr(granted ? 'notif.granted' : 'toast.permissionDenied'))),
      );
  }

  Future<void> _previewSound() async {
    final app = context.appRead;
    if (app.settings.sound == AppSound.silent) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('sound.silent'))));
      return;
    }
    final bool sent = await app.sendPreviewNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.tr(sent ? 'notif.previewSent' : 'notif.previewFailed')),
      ));
  }
}
