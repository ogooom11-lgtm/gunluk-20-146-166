import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/settings_tiles.dart';

/// النسخ الاحتياطي: تصدير، استيراد، وإعادة ضبط.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final TextEditingController _import = TextEditingController();
  bool _busy = false;

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
                        '${context.tr('backup.size')}: ${kb.toStringAsFixed(1)} KB • '
                        '${context.numStr(app.tasks.length)} ${context.tr('home.todayTasks')}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (app.settings.lastExport != null)
                        Text(
                          '${context.tr('backup.lastExport')}: ${context.dateStr(app.settings.lastExport!)}',
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
            title: context.tr('backup.title'),
            icon: Icons.backup_rounded,
            children: <Widget>[
              SettingsTile(
                title: context.tr('backup.export'),
                subtitle: context.tr('backup.exportDesc'),
                icon: Icons.upload_file_rounded,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: data));
                  await app.updateSettings(app.settings.copyWith(lastExport: DateTime.now()));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(context.tr('backup.exportDone'))));
                },
              ),
              SettingsTile(
                title: context.tr('backup.import'),
                subtitle: context.tr('backup.importHint'),
                icon: Icons.download_rounded,
                onTap: () async {
                  final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
                  final String text = clip?.text ?? '';
                  if (text.trim().isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(context.tr('backup.importError'))));
                    return;
                  }
                  setState(() => _import.text = text);
                  await _runImport(text);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('backup.import'),
            subtitle: context.tr('backup.importHint'),
            icon: Icons.content_paste_rounded,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _import,
                      minLines: 4,
                      maxLines: 8,
                      style: Theme.of(context).textTheme.labelSmall,
                      decoration: const InputDecoration(hintText: '{"v":1, ...}'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
                              if (clip?.text != null) setState(() => _import.text = clip!.text!);
                            },
                            icon: const Icon(Icons.content_paste_rounded, size: 18),
                            label: Text(context.tr('common.copy')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : () => _runImport(_import.text),
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

  Future<void> _runImport(String raw) async {
    if (raw.trim().isEmpty) return;
    setState(() => _busy = true);
    final app = context.appRead;
    final bool ok = await app.importJson(raw);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(ok ? 'backup.importDone' : 'backup.importError'))));
    if (ok) setState(() => _import.clear());
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr('backup.resetDone'))));
  }
}
