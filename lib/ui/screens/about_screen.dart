import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/progress_ring.dart';
import '../widgets/settings_tiles.dart';

/// عن التطبيق: الميزات، النصائح، الخصوصية، وإعادة الجولة التعريفية.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final List<List<Object>> features = <List<Object>>[
      <Object>[Icons.check_circle_outline_rounded, 'home.todayTasks', 'home.addFirstTask'],
      <Object>[Icons.repeat_rounded, 'plan.title', 'onboard.featurePlansDesc'],
      <Object>[Icons.calendar_month_rounded, 'calendar.title', 'onboard.featureCalendarDesc'],
      <Object>[Icons.notifications_active_rounded, 'notif.title', 'onboard.featureNotifDesc'],
      <Object>[Icons.timer_rounded, 'focus.title', 'focus.subtitle'],
      <Object>[Icons.insights_rounded, 'stats.title', 'stats.insights'],
    ];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('about.title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 40),
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.all(20),
            gradient: LinearGradient(
              colors: <Color>[
                context.palette.gradient.first.withAlpha(context.isDark ? 120 : 30),
                context.palette.gradient.last.withAlpha(context.isDark ? 60 : 12),
              ],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            child: Column(
              children: <Widget>[
                const AppLogomark(size: 84),
                const SizedBox(height: 12),
                Text(context.tr('app.name'), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(context.tr('app.tagline'), style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                Pill(
                  label: context.tr('about.version', <String, String>{'v': '1.0.3'}),
                  color: context.palette.seed,
                  dense: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(title: context.tr('about.features'), icon: Icons.auto_awesome_rounded),
          for (final List<Object> feature in features) ...<Widget>[
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: context.palette.seed.withAlpha(context.isDark ? 60 : 24),
                      borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
                    ),
                    child: Icon(feature[0] as IconData, size: 18, color: context.palette.seed),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(context.tr(feature[1] as String), style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(context.tr(feature[2] as String), style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          SectionHeader(title: context.tr('about.tipsTitle'), icon: Icons.tips_and_updates_rounded),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String key in <String>['about.tip1', 'about.tip2', 'about.tip3', 'about.tip4'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.check_circle_rounded, size: 16, color: context.palette.seed),
                        const SizedBox(width: 10),
                        Expanded(child: Text(context.tr(key), style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SettingsGroup(
            title: context.tr('settings.about'),
            icon: Icons.info_outline_rounded,
            children: <Widget>[
              SettingsTile(
                title: context.tr('about.body'),
                icon: Icons.description_outlined,
                subtitle: context.tr('app.tagline'),
                onTap: null,
              ),
              SettingsTile(
                title: context.tr('about.privacy'),
                icon: Icons.lock_outline_rounded,
                subtitle: context.tr('backup.subtitle'),
                onTap: null,
              ),
              SettingsTile(
                title: context.tr('about.fonts'),
                icon: Icons.font_download_outlined,
                onTap: null,
              ),
              SettingsTile(
                title: context.tr('about.shortcuts'),
                icon: Icons.keyboard_alt_outlined,
                subtitle: context.tr('settings.quickAddHint'),
                onTap: null,
              ),
              SettingsTile(
                title: context.tr('toast.resetOnboarding'),
                icon: Icons.restart_alt_rounded,
                subtitle: context.tr('onboard.setupBody'),
                onTap: () async {
                  await app.updateSettings(app.settings.copyWith(onboarded: false));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(context.tr('common.saved'))));
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: <Widget>[
                Text(context.tr('about.madeWith'), style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 6),
                Text(
                  'Flutter • Material 3',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
