import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/models/app_settings.dart';
import '../../core/l10n/app_strings.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/settings_tiles.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';
import 'backup_screen.dart';
import 'categories_screen.dart';
import 'notification_settings_screen.dart';
import 'security_screen.dart';

/// شاشة الإعدادات الرئيسية.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// اختيار مدة التأجيل الافتراضية للمنبّه.
  Future<void> _editAlarmSnooze(BuildContext context) async {
    final AppSettings settings = context.appRead.settings;
    final int? picked = await showChoiceSheet<int>(
      context,
      title: context.tr('alarm.snoozeDefault'),
      subtitle: context.tr('alarm.settingsDesc'),
      value: settings.alarmSnoozeMinutes,
      options: <ChoiceItem<int>>[
        for (final int n in AppSettings.alarmSnoozeOptions)
          ChoiceItem<int>(
            value: n,
            label: n == 1
                ? context.tr('alarm.minute1')
                : context.tr('alarm.snoozeValue', <String, String>{'n': context.numStr(n)}),
            icon: Icons.snooze_rounded,
          ),
      ],
    );
    if (picked == null || !context.mounted) return;
    await context.appRead.updateSettings(
      settings.copyWith(alarmSnoozeMinutes: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final settings = app.settings;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings.title')),
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 130),
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.all(16),
            gradient: LinearGradient(
              colors: <Color>[
                context.palette.gradient.first.withAlpha(context.isDark ? 110 : 26),
                context.palette.gradient.last.withAlpha(context.isDark ? 60 : 12),
              ],
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: context.palette.seed,
                  child: Text(
                    settings.name.trim().isEmpty
                        ? '؟'
                        : settings.name.trim().characters.first,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'ReadexPro'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        settings.name.trim().isEmpty ? context.tr('settings.nameHint') : settings.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${context.tr('home.level', <String, String>{'n': context.numStr(app.level)})} • '
                        '${context.numStr(app.totalXp)} XP',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _editName(context),
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('settings.general'),
            icon: Icons.tune_rounded,
            children: <Widget>[
              SettingsValueTile(
                title: context.tr('settings.name'),
                value: settings.name.trim().isEmpty ? '—' : settings.name,
                icon: Icons.person_rounded,
                onTap: () => _editName(context),
              ),
              SettingsValueTile(
                title: context.tr('settings.language'),
                value: settings.isArabic ? context.tr('settings.languageAr') : context.tr('settings.languageEn'),
                icon: Icons.translate_rounded,
                onTap: () async {
                  final String? value = await showChoiceSheet<String>(
                    context,
                    title: context.tr('settings.language'),
                    value: settings.language,
                    options: <ChoiceItem<String>>[
                      ChoiceItem<String>(value: 'ar', label: 'العربية', icon: Icons.language_rounded),
                      ChoiceItem<String>(value: 'en', label: 'English', icon: Icons.language_rounded),
                    ],
                  );
                  if (value != null) {
                    await app.updateSettings(settings.copyWith(language: value), rescheduleNotifications: true);
                  }
                },
              ),
              SettingsValueTile(
                title: context.tr('settings.dailyGoal'),
                subtitle: context.tr('settings.dailyGoalHint'),
                value: context.numStr(settings.dailyGoal),
                icon: Icons.flag_rounded,
                onTap: () => _editNumber(
                  context,
                  title: context.tr('settings.dailyGoal'),
                  value: settings.dailyGoal,
                  min: 1,
                  max: 30,
                  onChanged: (int value) => app.updateSettings(settings.copyWith(dailyGoal: value)),
                ),
              ),
              SettingsValueTile(
                title: context.tr('settings.weeklyGoal'),
                value: context.numStr(settings.weeklyGoal),
                icon: Icons.calendar_view_week_rounded,
                onTap: () => _editNumber(
                  context,
                  title: context.tr('settings.weeklyGoal'),
                  value: settings.weeklyGoal,
                  min: 1,
                  max: 200,
                  onChanged: (int value) => app.updateSettings(settings.copyWith(weeklyGoal: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('settings.appearance'),
            subtitle: context.tr('settings.body'),
            icon: Icons.palette_rounded,
            children: <Widget>[
              SettingsValueTile(
                title: context.tr('settings.theme'),
                value: context.tr(settings.themeMode.labelKey),
                icon: Icons.dark_mode_rounded,
                onTap: () async {
                  final AppThemeMode? value = await showChoiceSheet<AppThemeMode>(
                    context,
                    title: context.tr('settings.theme'),
                    value: settings.themeMode,
                    options: <ChoiceItem<AppThemeMode>>[
                      for (final AppThemeMode mode in AppThemeMode.values)
                        ChoiceItem<AppThemeMode>(
                          value: mode,
                          label: context.tr(mode.labelKey),
                          icon: mode == AppThemeMode.system
                              ? Icons.brightness_auto_rounded
                              : mode == AppThemeMode.light
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                        ),
                    ],
                  );
                  if (value != null) await app.updateSettings(settings.copyWith(themeMode: value));
                },
              ),
              SettingsValueTile(
                title: context.tr('settings.accent'),
                value: context.tr(context.palette.key),
                icon: Icons.color_lens_rounded,
                iconColor: context.palette.seed,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AppearanceScreen()),
                ),
              ),
              SettingsValueTile(
                title: context.tr('settings.density'),
                value: context.tr(settings.density.labelKey),
                icon: Icons.format_line_spacing_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AppearanceScreen()),
                ),
              ),
              SettingsValueTile(
                title: context.tr('settings.fontScale'),
                value: '${context.numStr((settings.fontScale * 100).round())}%',
                icon: Icons.format_size_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AppearanceScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('settings.notifications'),
            icon: Icons.notifications_active_rounded,
            children: <Widget>[
              SettingsSwitchTile(
                title: context.tr('notif.evening'),
                subtitle: context.tr('notif.eveningDesc'),
                icon: Icons.nightlight_round,
                value: settings.eveningEnabled,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(eveningEnabled: value, notificationsEnabled: true),
                  rescheduleNotifications: true,
                ),
              ),
              SettingsValueTile(
                title: context.tr('notif.eveningTime'),
                value: context.timeStr(settings.eveningMinutes),
                icon: Icons.schedule_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen()),
                ),
              ),
              SettingsTile(
                title: context.tr('notif.title'),
                subtitle: context.tr('notif.channelNote'),
                icon: Icons.dashboard_customize_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ===== المنبّه (المهام العاجلة) =====
          SettingsGroup(
            title: context.tr('alarm.settingsGroup'),
            subtitle: context.tr('alarm.settingsDesc'),
            icon: Icons.notifications_active_rounded,
            children: <Widget>[
              SettingsSwitchTile(
                title: context.tr('alarm.enabled'),
                subtitle: context.tr('alarm.enabledDesc'),
                icon: Icons.alarm_rounded,
                value: settings.alarmEnabled,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(alarmEnabled: value, notificationsEnabled: true),
                  rescheduleNotifications: true,
                ),
              ),
              SettingsSwitchTile(
                title: context.tr('alarm.hideDetails'),
                subtitle: context.tr('alarm.hideDetailsDesc'),
                icon: Icons.visibility_off_rounded,
                value: settings.alarmHideDetails,
                enabled: settings.alarmEnabled,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(alarmHideDetails: value),
                  rescheduleNotifications: true,
                ),
              ),
              SettingsSwitchTile(
                title: context.tr('alarm.requireUnlock'),
                subtitle: context.tr('alarm.requireUnlockDesc'),
                icon: Icons.face_retouching_natural_rounded,
                value: settings.alarmRequireUnlock,
                enabled: settings.alarmEnabled && settings.alarmHideDetails,
                onChanged: (bool value) => app.updateSettings(
                  settings.copyWith(alarmRequireUnlock: value),
                ),
              ),
              SettingsValueTile(
                title: context.tr('alarm.snoozeDefault'),
                value: settings.alarmSnoozeMinutes == 1
                    ? context.tr('alarm.minute1')
                    : context.tr('alarm.snoozeValue', <String, String>{
                        'n': context.numStr(settings.alarmSnoozeMinutes),
                      }),
                icon: Icons.snooze_rounded,
                onTap: settings.alarmEnabled ? () => _editAlarmSnooze(context) : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('settings.security'),
            icon: Icons.shield_rounded,
            subtitle: context.tr('security.subtitle'),
            children: <Widget>[
              SettingsTile(
                title: context.tr('security.title'),
                subtitle: context.tr('security.subtitle'),
                icon: settings.lockEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                trailing: Text(
                  context.tr(settings.lockEnabled ? 'common.enabled' : 'common.disabled'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SecurityScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('settings.data'),
            icon: Icons.storage_rounded,
            children: <Widget>[
              SettingsTile(
                title: context.tr('category.manage'),
                subtitle: '${context.numStr(app.categories.length)} ${context.tr('category.title')}',
                icon: Icons.category_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
                ),
              ),
              SettingsTile(
                title: context.tr('backup.title'),
                subtitle: context.tr('backup.subtitle'),
                icon: Icons.backup_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
                ),
              ),
              SettingsTile(
                title: context.tr('settings.haptics'),
                icon: Icons.vibration_rounded,
                trailing: Switch.adaptive(
                  value: settings.haptics,
                  onChanged: (bool value) => app.updateSettings(settings.copyWith(haptics: value)),
                ),
                onTap: () => app.updateSettings(settings.copyWith(haptics: !settings.haptics)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('settings.about'),
            icon: Icons.info_rounded,
            children: <Widget>[
              SettingsTile(
                title: context.tr('about.title'),
                subtitle: context.tr('about.version', <String, String>{'v': '1.0.7'}),
                icon: Icons.apps_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
              ),
              SettingsTile(
                title: context.tr('stats.export'),
                icon: Icons.copy_all_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${context.tr('app.name')} • ${context.tr('about.version', <String, String>{'v': '1.0.7'})}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final app = context.appRead;
    final TextEditingController controller = TextEditingController(text: app.settings.name);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.tr('settings.name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.tr('settings.nameHint')),
          onSubmitted: (String value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      await app.updateSettings(app.settings.copyWith(name: result.trim()));
    }
  }

  Future<void> _editNumber(
    BuildContext context, {
    required String title,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) async {
    int current = value;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: Text(title),
          content: Row(
            children: <Widget>[
              Expanded(
                child: Slider(
                  value: current.toDouble().clamp(min.toDouble(), max.toDouble()),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: (max - min).clamp(1, 100),
                  label: '$current',
                  onChanged: (double v) => setState(() => current = v.round()),
                ),
              ),
              Text(context.numStr(current), style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () {
                onChanged(current);
                Navigator.of(context).pop();
              },
              child: Text(context.tr('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}
