import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/defaults.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import '../widgets/progress_ring.dart';

/// شاشة الشارات والمستوى.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _celebrate = false;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final List<BadgeProgress> all = app.badgeProgress;
    final List<BadgeProgress> unlocked = all.where((BadgeProgress b) => b.unlocked).toList();
    final List<BadgeProgress> locked = all.where((BadgeProgress b) => !b.unlocked).toList();
    final String levelName = 'badge.levelName${app.level.clamp(1, 6)}';

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('badges.title'))),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 130),
            children: <Widget>[
              AppCard(
                padding: const EdgeInsets.all(18),
                gradient: LinearGradient(
                  colors: <Color>[
                    context.palette.gradient.first.withAlpha(context.isDark ? 120 : 30),
                    context.palette.gradient.last.withAlpha(context.isDark ? 60 : 12),
                  ],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                child: Row(
                  children: <Widget>[
                    ProgressRing(
                      value: app.levelProgress,
                      size: 104,
                      stroke: 11,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            context.numStr(app.level),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            context.tr('badge.level', <String, String>{'n': context.numStr(app.level)}),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(context.tr(levelName), style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('home.xpToNext', <String, String>{
                              'n': context.numStr(app.xpToNextLevel),
                            }),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${context.tr('stats.xpTotal')}: ${context.numStr(app.totalXp)}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 6),
                          ThinProgress(value: app.levelProgress),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatTile(
                      label: context.tr('badges.unlocked'),
                      value: context.numStr(unlocked.length),
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFE0A02E),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: context.tr('badges.locked'),
                      value: context.numStr(locked.length),
                      icon: Icons.lock_outline_rounded,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: context.tr('stats.currentStreak'),
                      value: context.numStr(app.currentStreak),
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFE05B5B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SectionHeader(
                title: context.tr('badges.unlocked'),
                subtitle: '${context.numStr(unlocked.length)} ${context.tr('common.of')} ${context.numStr(all.length)}',
                icon: Icons.workspace_premium_rounded,
              ),
              if (unlocked.isEmpty)
                AppCard(
                  child: Text(context.tr('home.addFirstTask'), style: Theme.of(context).textTheme.bodySmall),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final BadgeProgress badge in unlocked) _BadgeCard(progress: badge, unlocked: true),
                  ],
                ),
              if (locked.isNotEmpty) ...<Widget>[
                const SizedBox(height: 22),
                SectionHeader(title: context.tr('badges.locked'), icon: Icons.lock_outline_rounded),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final BadgeProgress badge in locked) _BadgeCard(progress: badge, unlocked: false),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _celebrate = true),
                  icon: const Icon(Icons.celebration_rounded),
                  label: Text(context.tr('badges.progress')),
                ),
              ),
            ],
          ),
          ConfettiOverlay(
            play: _celebrate,
            onDone: () => setState(() => _celebrate = false),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.progress, required this.unlocked});

  final BadgeProgress progress;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final Color color = unlocked ? context.palette.seed : Theme.of(context).disabledColor;
    return SizedBox(
      width: 156,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(context.isDark ? 60 : 26),
                    borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
                  ),
                  child: Icon(progress.def.icon, color: color, size: 20),
                ),
                const Spacer(),
                if (unlocked)
                  const Icon(Icons.verified_rounded, size: 17, color: Color(0xFF43A047))
                else
                  Text(
                    '${context.numStr(progress.value)}/${context.numStr(progress.def.target)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(progress.def.titleKey),
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              context.tr(progress.def.descKey),
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            ThinProgress(value: progress.ratio, color: color, height: 6),
            const SizedBox(height: 6),
            Text(
              unlocked
                  ? (progress.unlockedAt == null
                      ? context.tr('badges.unlocked')
                      : context.shortDateStr(progress.unlockedAt!))
                  : context.tr('badges.progress'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
