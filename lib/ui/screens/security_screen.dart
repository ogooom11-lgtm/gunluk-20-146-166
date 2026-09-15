import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/secure_data.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/settings_tiles.dart';

/// شاشة الأمان: قفل التطبيق بكلمة سر، الحماية، وتشفير النسخ الاحتياطية.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final settings = app.settings;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('security.title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 40),
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.palette.seed.withAlpha(context.isDark ? 60 : 26),
                    borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
                  ),
                  child: Icon(
                    settings.lockEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: context.palette.seed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.tr(settings.lockEnabled ? 'security.lock' : 'security.subtitle'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('security.encryptedHint'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('security.lock'),
            icon: Icons.lock_rounded,
            children: <Widget>[
              SettingsTile(
                title: context.tr('security.lock'),
                subtitle: context.tr('security.lockDesc'),
                icon: Icons.password_rounded,
                trailing: Text(
                  context.tr(settings.lockEnabled ? 'common.enabled' : 'common.disabled'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                onTap: () => settings.lockEnabled ? _changePassword(context) : _setPassword(context),
              ),
              if (settings.lockEnabled) ...<Widget>[
                SettingsTile(
                  title: context.tr('security.change'),
                  icon: Icons.key_rounded,
                  onTap: () => _changePassword(context),
                ),
                SettingsTile(
                  title: context.tr('security.lockNow'),
                  subtitle: context.tr('security.lockNowDesc'),
                  icon: Icons.lock_clock_rounded,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.appRead.lockNow();
                  },
                ),
                SettingsTile(
                  title: context.tr('security.disable'),
                  icon: Icons.lock_open_rounded,
                  iconColor: const Color(0xFFE05B5B),
                  onTap: () => _disableLock(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('security.title'),
            icon: Icons.shield_rounded,
            children: <Widget>[
              SettingsSwitchTile(
                title: context.tr('security.lockWhenBackground'),
                subtitle: context.tr('security.lockWhenBackgroundDesc'),
                icon: Icons.exit_to_app_rounded,
                value: settings.lockWhenBackground,
                enabled: settings.lockEnabled,
                onChanged: (bool v) => context.appRead.updateSettings(
                  settings.copyWith(lockWhenBackground: v),
                ),
              ),
              SettingsValueTile(
                title: context.tr('security.grace'),
                subtitle: context.tr('security.graceDesc'),
                value: settings.lockGraceSeconds <= 0
                    ? context.tr('security.graceNone')
                    : context.tr('security.graceValue', <String, String>{
                        'n': context.numStr(settings.lockGraceSeconds),
                      }),
                icon: Icons.timer_outlined,
                onTap: settings.lockEnabled ? () => _editGrace(context) : null,
              ),
              SettingsSwitchTile(
                title: context.tr('security.secureScreen'),
                subtitle: context.tr('security.secureScreenDesc'),
                icon: Icons.screenshot_monitor_rounded,
                value: settings.secureScreen,
                onChanged: (bool v) async {
                  await context.appRead.updateSettings(settings.copyWith(secureScreen: v));
                  await context.appRead.applySecurityFlags();
                },
              ),
              SettingsSwitchTile(
                title: context.tr('security.encryptBackups'),
                subtitle: context.tr('security.encryptBackupsDesc'),
                icon: Icons.enhanced_encryption_rounded,
                value: settings.encryptBackupsByDefault,
                onChanged: (bool v) => context.appRead.updateSettings(
                  settings.copyWith(encryptBackupsByDefault: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('security.forgot'),
            icon: Icons.help_outline_rounded,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Text(
                  context.tr('security.forgotDesc'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setPassword(BuildContext context) async {
    final String? password = await showPasswordDialog(
      context,
      title: context.tr('security.enable'),
      confirm: true,
      submitLabel: context.tr('security.enable'),
    );
    if (password == null || !context.mounted) return;
    await context.appRead.setLockPassword(password);
    if (!context.mounted) return;
    _toast(context, context.tr('security.passwordSet'));
  }

  Future<void> _changePassword(BuildContext context) async {
    final String? current = await showPasswordDialog(
      context,
      title: context.tr('security.change'),
      fieldLabel: context.tr('security.currentPassword'),
      submitLabel: context.tr('common.next'),
    );
    if (current == null || !context.mounted) return;
    if (!SecureData.verifyPassword(current, context.appRead.settings.lockHash)) {
      _toast(context, context.tr('security.wrongPassword'), error: true);
      return;
    }
    if (!context.mounted) return;
    final String? next = await showPasswordDialog(
      context,
      title: context.tr('security.change'),
      fieldLabel: context.tr('security.newPassword'),
      confirm: true,
      submitLabel: context.tr('common.save'),
    );
    if (next == null || !context.mounted) return;
    await context.appRead.setLockPassword(next);
    if (!context.mounted) return;
    _toast(context, context.tr('security.passwordChanged'));
  }

  Future<void> _disableLock(BuildContext context) async {
    final String? current = await showPasswordDialog(
      context,
      title: context.tr('security.disable'),
      fieldLabel: context.tr('security.currentPassword'),
      submitLabel: context.tr('security.disable'),
    );
    if (current == null || !context.mounted) return;
    if (!SecureData.verifyPassword(current, context.appRead.settings.lockHash)) {
      _toast(context, context.tr('security.wrongPassword'), error: true);
      return;
    }
    await context.appRead.removeLock();
    if (!context.mounted) return;
    _toast(context, context.tr('security.lockRemoved'));
  }

  Future<void> _editGrace(BuildContext context) async {
    final app = context.appRead;
    final List<int> options = <int>[0, 15, 30, 60, 300];
    final int? picked = await showChoiceSheet<int>(
      context,
      title: context.tr('security.grace'),
      subtitle: context.tr('security.graceDesc'),
      options: <ChoiceItem<int>>[
        for (final int option in options)
          ChoiceItem<int>(
            value: option,
            label: option == 0
                ? context.tr('security.graceNone')
                : context.tr('security.graceValue', <String, String>{
                    'n': context.numStr(option),
                  }),
            icon: Icons.timer_outlined,
          ),
      ],
      value: app.settings.lockGraceSeconds,
    );
    if (picked == null) return;
    await app.updateSettings(app.settings.copyWith(lockGraceSeconds: picked));
  }

  void _toast(BuildContext context, String message, {bool error = false}) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
