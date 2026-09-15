import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/secure_data.dart';
import '../../services/backup_service.dart';
import '../../services/file_service.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/settings_tiles.dart';

/// النسخ الاحتياطي: ملف مشفّر بكلمة سر، نسخ نصي، استيراد من ملف، وإعادة ضبط.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final TextEditingController _import = TextEditingController();
  bool _busy = false;
  String? _busyLabel;

  @override
  void dispose() {
    _import.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final String data = app.exportJson();
    final double kb = data.length / 1024;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('backup.title'))),
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
                  child: Icon(Icons.storage_rounded, color: context.palette.seed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(context.tr('backup.subtitle'), style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('backup.size', <String, String>{
                          'tasks': context.numStr(app.tasks.length),
                          'plans': context.numStr(app.plans.length),
                        })} • ${context.numStr(app.events.length)} ${context.tr('nav.events')} • '
                        '${kb.toStringAsFixed(1)} KB',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (app.settings.lastExport != null)
                        Text(
                          context.tr('backup.lastExport', <String, String>{
                            'd': context.dateStr(app.settings.lastExport!),
                          }),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_busy) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(_busyLabel ?? context.tr('common.loading'),
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ],
          const SizedBox(height: 18),
          // ===== النسخة المشفّرة =====
          SettingsGroup(
            title: context.tr('backup.encryptedTitle'),
            subtitle: context.tr('backup.encryptedDesc'),
            icon: Icons.enhanced_encryption_rounded,
            children: <Widget>[
              SettingsTile(
                title: context.tr('backup.exportEncrypted'),
                subtitle: context.tr('backup.saveToFile'),
                icon: Icons.lock_rounded,
                trailing: const Pill(label: 'AES-256', dense: true),
                onTap: _busy ? null : () => _exportEncrypted(openSaveDialog: true),
              ),
              SettingsTile(
                title: context.tr('backup.exportPlain'),
                subtitle: context.tr('backup.exportPlainDesc'),
                icon: Icons.copy_all_rounded,
                onTap: _busy ? null : () => _copyPlain(data),
              ),
              SettingsTile(
                title: context.tr('backup.pickFile'),
                subtitle: context.tr('backup.pickFileDesc'),
                icon: Icons.folder_open_rounded,
                onTap: _busy ? null : _importFromFile,
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ===== نص للصق اليدوي (يعمل حتى بدون صلاحية ملفات) =====
          SettingsGroup(
            title: context.tr('backup.import'),
            subtitle: context.tr('backup.restoreHint'),
            icon: Icons.content_paste_rounded,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _import,
                      minLines: 3,
                      maxLines: 7,
                      style: Theme.of(context).textTheme.labelSmall,
                      decoration: InputDecoration(
                        hintText: context.tr('secure.fileHidden'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final ClipboardData? clip =
                                  await Clipboard.getData(Clipboard.kTextPlain);
                              if (clip?.text != null) {
                                setState(() => _import.text = clip!.text!);
                              }
                            },
                            icon: const Icon(Icons.content_paste_rounded, size: 18),
                            label: Text(context.tr('common.copy')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : () => _importText(_import.text),
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(context.tr('backup.import')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('settings.data'),
            icon: Icons.warning_amber_rounded,
            children: <Widget>[
              DangerTile(
                title: context.tr('backup.reset'),
                subtitle: context.tr('backup.resetConfirm'),
                icon: Icons.restart_alt_rounded,
                onTap: () => _confirmReset(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(context.tr('about.privacy'), style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }

  // ===== التصدير المشفّر =====

  Future<void> _exportEncrypted({required bool openSaveDialog}) async {
    final String? password = await showPasswordDialog(
      context,
      title: context.tr('backup.passwordPrompt'),
      fieldLabel: context.tr('backup.passwordPrompt'),
      confirm: true,
      hint: context.tr('backup.passwordPromptDesc'),
      submitLabel: context.tr('backup.makeFile'),
      minLength: 6,
      shortMessage: context.tr('backup.passwordShort'),
    );
    if (password == null || !mounted) return;

    _startBusy(context.tr('backup.exportEncrypted'));
    final app = context.appRead;
    final String? encrypted = await app.exportEncryptedJson(password);
    if (encrypted == null) {
      if (!mounted) return;
      _stopBusy();
      _toast(context.tr('backup.saveError'));
      return;
    }
    await app.updateSettings(app.settings.copyWith(lastExport: DateTime.now()));
    if (!mounted) return;
    _stopBusy();

    final String name = 'injazi-backup-${_stamp()}.injaz';
    if (!openSaveDialog) {
      await Clipboard.setData(ClipboardData(text: encrypted));
      if (!mounted) return;
      _toast(context.tr('backup.encryptedFileReady'));
      return;
    }
    _toast(context.tr('backup.encryptedFileReady'));
    final String? saved = await app.files.saveTextFile(fileName: name, text: encrypted);
    if (!mounted) return;
    if (saved == null) {
      // المستخدم ألغى أو القناة غير متاحة: ننسخ النص حتى لا تضيع النسخة.
      await Clipboard.setData(ClipboardData(text: encrypted));
      if (!mounted) return;
      _toast(context.tr('toast.copied'));
      return;
    }
    if (saved == 'error') {
      _toast(context.tr('backup.saveError'));
      return;
    }
    _toast(context.tr('backup.savedTo', <String, String>{'name': saved}));
  }

  // ===== الاستيراد =====

  Future<void> _importFromFile() async {
    final app = context.appRead;
    final PickedFile? picked = await app.files.pickTextFile();
    if (!mounted) return;
    if (picked == null) {
      _toast(context.tr('backup.importNotBackup'));
      return;
    }
    _toast(context.tr('backup.filePicked', <String, String>{'name': picked.name}));
    setState(() => _import.text = picked.text);
    await _importText(picked.text);
  }

  Future<void> _importText(String raw) async {
    final String text = raw.trim();
    if (text.isEmpty) return;
    final app = context.appRead;
    String? password;
    if (SecureData.looksEncrypted(text)) {
      password = await showPasswordDialog(
        context,
        title: context.tr('backup.importPasswordTitle'),
        fieldLabel: context.tr('backup.passwordPrompt'),
        hint: context.tr('backup.importPasswordDesc'),
        submitLabel: context.tr('backup.import'),
      );
      if (!mounted || password == null) return;
    }
    _startBusy(context.tr('backup.import'));
    final ImportStatus status = await app.importAny(text, password: password);
    if (!mounted) return;
    _stopBusy();
    switch (status) {
      case ImportStatus.ok:
        setState(() => _import.clear());
        _toast(context.tr('backup.importOk'));
      case ImportStatus.wrongPassword:
        _toast(context.tr('backup.importWrongPassword'), error: true);
      case ImportStatus.badFile:
        _toast(context.tr('backup.importBadFile'), error: true);
      case ImportStatus.notBackup:
        _toast(context.tr('backup.importNotBackup'), error: true);
    }
  }

  Future<void> _copyPlain(String data) async {
    await Clipboard.setData(ClipboardData(text: data));
    final app = context.appRead;
    await app.updateSettings(app.settings.copyWith(lastExport: DateTime.now()));
    if (!mounted) return;
    _toast(context.tr('backup.exportPlain'));
  }

  Future<void> _confirmReset() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: context.tr('backup.reset'),
      message: context.tr('backup.resetConfirm'),
      confirmLabel: context.tr('common.delete'),
    );
    if (!confirmed) return;
    await context.appRead.resetAll();
    if (!mounted) return;
    _toast(context.tr('backup.resetDone'));
  }

  // ===== أدوات =====

  void _startBusy(String label) {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
  }

  void _stopBusy() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyLabel = null;
    });
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFE05B5B) : null,
        ),
      );
  }

  String _stamp() {
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}-${two(now.hour)}${two(now.minute)}';
  }
}
