import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/pin_sheet.dart';
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
              SettingsSwitchTile(
                title: context.tr('security.pinAutoUnlock'),
                subtitle: context.tr('security.pinAutoUnlockDesc'),
                icon: Icons.bolt_rounded,
                value: settings.lockAutoUnlock,
                enabled: settings.lockEnabled,
                onChanged: (bool v) => context.appRead.updateLockOptions(autoUnlock: v),
              ),
              SettingsValueTile(
                title: context.tr('security.pinLength'),
                subtitle: context.tr('security.pinLengthDesc'),
                icon: Icons.pin_rounded,
                value: settings.lockPinLength >= 4
                    ? context.tr('security.pinLengthValue', <String, String>{
                        'n': context.numStr(settings.lockPinLength),
                      })
                    : context.tr('security.legacyPin'),
                enabled: settings.lockEnabled,
                onTap: () => _editPinLength(context),
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

  /// عدد الأرقام المختار حاليًا (٤ إن لم يُحدَّد بعد).
  int _pinLengthOf(BuildContext context) {
    final int stored = context.appRead.settings.lockPinLength;
    return stored >= 4 ? stored : 4;
  }

  /// تفعيل القفل: يُدخل رمز أرقام جديد ثم يؤكّده على لوحة الأرقام.
  Future<void> _setPassword(BuildContext context) async {
    final bool ok = await _setNewPin(context);
    if (!context.mounted || !ok) return;
    _toast(context, context.tr('security.passwordSet'));
  }

  /// تغيير الرمز: أولًا التحقق من الرمز الحالي (إن كان رمزًا رقميًا)،
  /// ثم تعيين رمز جديد.
  Future<void> _changePassword(BuildContext context) async {
    if (!await _verifyCurrent(context)) return;
    if (!context.mounted) return;
    final bool ok = await _setNewPin(context);
    if (!context.mounted || !ok) return;
    _toast(context, context.tr('security.passwordChanged'));
  }

  /// إلغاء القفل بعد التحقق من الرمز الحالي.
  Future<void> _disableLock(BuildContext context) async {
    if (!await _verifyCurrent(context)) return;
    if (!context.mounted) return;
    await context.appRead.removeLock();
    if (!context.mounted) return;
    _toast(context, context.tr('security.lockRemoved'));
  }

  /// تعديل عدد أرقام الرمز (يعمل مع الرمز الحالي مباشرة).
  Future<void> _editPinLength(BuildContext context) async {
    final app = context.appRead;
    final int? picked = await showChoiceSheet<int>(
      context,
      title: context.tr('security.pinLength'),
      subtitle: context.tr('security.pinLengthDesc'),
      value: _pinLengthOf(context),
      options: <ChoiceItem<int>>[
        for (final int n in <int>[4, 5, 6, 7, 8])
          ChoiceItem<int>(
            value: n,
            label: context.tr('security.pinLengthValue', <String, String>{'n': context.numStr(n)}),
            icon: Icons.pin_rounded,
          ),
      ],
    );
    if (picked == null) return;
    await app.updateLockOptions(pinLength: picked);
  }

  /// إدخال رمز جديد مرّتين على لوحة الأرقام. يعيد true عند الحفظ.
  Future<bool> _setNewPin(BuildContext context) async {
    final int length = _pinLengthOf(context);
    final String? pin = await showPinSetupSheet(
      context,
      title: context.tr('security.enable'),
      subtitle: context.tr('security.pinNumbersOnly'),
      length: length,
    );
    if (pin == null || !context.mounted) return false;
    await context.appRead.setLockPassword(pin, pinLength: length);
    return true;
  }

  /// التحقق من الرمز الحالي إن كان رمزيًا؛ وإن كان قديمًا (نصّي) نستخدم النص.
  Future<bool> _verifyCurrent(BuildContext context) async {
    final app = context.appRead;
    if (app.settings.lockPinLength >= 4) {
      final bool ok = await showPinVerifySheet(
        context,
        title: context.tr('security.currentPassword'),
        length: app.settings.lockPinLength,
      );
      if (!ok && context.mounted) _toast(context, context.tr('security.wrongPassword'), error: true);
      return ok;
    }
    final String? current = await showPasswordDialog(
      context,
      title: context.tr('security.change'),
      fieldLabel: context.tr('security.currentPassword'),
      submitLabel: context.tr('common.next'),
    );
    if (current == null || !context.mounted) return false;
    final bool ok = await app.verifyLockPin(current);
    if (!ok && context.mounted) _toast(context, context.tr('security.wrongPassword'), error: true);
    return ok;
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
