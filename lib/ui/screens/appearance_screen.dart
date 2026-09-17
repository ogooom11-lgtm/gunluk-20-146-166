import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/app_settings.dart';
import '../../theme/palettes.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/progress_ring.dart';
import '../widgets/settings_tiles.dart';

/// شاشة المظهر: اللون، الوضع، الكثافة، حجم الخط، واستدارة الحواف.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final settings = app.settings;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings.appearance'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 40),
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                const AppLogomark(size: 54),
                const SizedBox(height: 10),
                Text(context.tr('app.tagline'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(context.tr('onboard.setupBody'), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Expanded(child: Pill(label: context.tr(context.palette.key), color: context.palette.seed)),
                    const SizedBox(width: 8),
                    Expanded(child: Pill(label: context.tr(settings.density.labelKey), color: const Color(0xFF9C4DCC))),
                    const SizedBox(width: 8),
                    Expanded(child: Pill(label: context.tr(settings.themeMode.labelKey), color: const Color(0xFF2FA8A0))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('settings.accent'), icon: Icons.color_lens_rounded),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                for (int i = 0; i < Palettes.all.length; i++)
                  GestureDetector(
                    onTap: () => app.updateSettings(settings.copyWith(accentIndex: i)),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: Palettes.all[i].gradient,
                              begin: AlignmentDirectional.topStart,
                              end: AlignmentDirectional.bottomEnd,
                            ),
                            shape: BoxShape.circle,
                            border: settings.accentIndex == i
                                ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.6)
                                : null,
                          ),
                          child: settings.accentIndex == i
                              ? const Icon(Icons.check_rounded, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 62,
                          child: Text(
                            context.tr(Palettes.all[i].key),
                            style: Theme.of(context).textTheme.labelSmall,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('settings.theme'), icon: Icons.dark_mode_rounded),
          Row(
            children: <Widget>[
              for (final AppThemeMode mode in AppThemeMode.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AppCard(
                      onTap: () => app.updateSettings(settings.copyWith(themeMode: mode)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: settings.themeMode == mode
                          ? context.palette.seed.withAlpha(context.isDark ? 60 : 26)
                          : null,
                      border: Border.all(
                        color: settings.themeMode == mode
                            ? context.palette.seed.withAlpha(150)
                            : Theme.of(context).dividerColor,
                      ),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            mode == AppThemeMode.system
                                ? Icons.brightness_auto_rounded
                                : mode == AppThemeMode.light
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                            color: context.palette.seed,
                          ),
                          const SizedBox(height: 6),
                          Text(context.tr(mode.labelKey), style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('settings.density'), icon: Icons.format_line_spacing_rounded),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: <Widget>[
                for (final UiDensity density in UiDensity.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => app.updateSettings(settings.copyWith(density: density)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: settings.density == density
                              ? context.palette.seed.withAlpha(context.isDark ? 70 : 30)
                              : null,
                          borderRadius: BorderRadius.circular(14 * settings.radiusScale),
                        ),
                        child: Center(
                          child: Text(context.tr(density.labelKey), style: Theme.of(context).textTheme.labelMedium),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('settings.fontScale'), icon: Icons.format_size_rounded),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Slider(
                        value: settings.fontScale.clamp(0.85, 1.35),
                        min: 0.85,
                        max: 1.35,
                        divisions: 10,
                        label: '${context.numStr((settings.fontScale * 100).round())}%',
                        onChanged: (double value) =>
                            app.updateSettings(settings.copyWith(fontScale: double.parse(value.toStringAsFixed(2)))),
                      ),
                    ),
                    Text(
                      '${context.numStr((settings.fontScale * 100).round())}%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                Text(context.tr('settings.tip'), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('settings.radiusScale'), icon: Icons.rounded_corner_rounded),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Slider(
                    value: settings.radiusScale.clamp(0.5, 1.5),
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                    label: '${context.numStr((settings.radiusScale * 100).round())}%',
                    onChanged: (double value) =>
                        app.updateSettings(settings.copyWith(radiusScale: double.parse(value.toStringAsFixed(2)))),
                  ),
                ),
                Container(
                  width: 54,
                  height: 34,
                  decoration: BoxDecoration(
                    color: context.palette.seed.withAlpha(40),
                    borderRadius: BorderRadius.circular(14 * settings.radiusScale),
                    border: Border.all(color: context.palette.seed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: context.tr('settings.weekStart'), icon: Icons.calendar_view_week_rounded),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: <Widget>[
                for (final int day in <int>[DateTime.saturday, DateTime.sunday, DateTime.monday])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => app.updateSettings(settings.copyWith(weekStart: day)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: settings.weekStart == day
                              ? context.palette.seed.withAlpha(context.isDark ? 70 : 30)
                              : null,
                          borderRadius: BorderRadius.circular(14 * settings.radiusScale),
                        ),
                        child: Center(
                          child: Text(
                            context.weekdayStr(DateTime(2024, 1, 1 + (day - 1))),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingsSwitches(settings: settings),
        ],
      ),
    );
  }
}

/// مفاتيح خيارات العرض المتنوعة.
class SettingsSwitches extends StatelessWidget {
  const SettingsSwitches({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final AppSettings s = settings;
    return Column(
      children: <Widget>[
        SectionHeader(title: context.tr('settings.general'), icon: Icons.toggle_on_rounded),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              SettingsSwitchTile(
                title: context.tr('settings.timeFormat'),
                subtitle: context.tr('settings.timeFormatHint'),
                icon: Icons.schedule_rounded,
                value: s.use24Hour,
                onChanged: (bool value) => app.updateSettings(s.copyWith(use24Hour: value)),
              ),
              SettingsSwitchTile(
                title: context.tr('settings.arabicDigits'),
                subtitle: context.tr('settings.arabicDigitsHint'),
                icon: Icons.pin_rounded,
                value: s.arabicDigits,
                onChanged: (bool value) => app.updateSettings(s.copyWith(arabicDigits: value)),
              ),
              SettingsSwitchTile(
                title: context.tr('settings.hijri'),
                subtitle: context.tr('settings.hijriHint'),
                icon: Icons.mosque_rounded,
                value: s.showHijri,
                onChanged: (bool value) => app.updateSettings(s.copyWith(showHijri: value)),
              ),
              SettingsSwitchTile(
                title: context.tr('settings.motivation'),
                subtitle: context.tr('settings.motivationHint'),
                icon: Icons.format_quote_rounded,
                value: s.showQuotes,
                onChanged: (bool value) => app.updateSettings(s.copyWith(showQuotes: value)),
              ),
              SettingsSwitchTile(
                title: context.tr('settings.quickAddHint'),
                icon: Icons.bolt_rounded,
                value: s.quickAddShortcuts,
                onChanged: (bool value) => app.updateSettings(s.copyWith(quickAddShortcuts: value)),
              ),
              SettingsSwitchTile(
                title: context.tr('settings.confetti'),
                icon: Icons.celebration_rounded,
                value: s.confetti,
                onChanged: (bool value) => app.updateSettings(s.copyWith(confetti: value)),
              ),
              SettingsSwitchTile(
                title: context.tr('settings.inAppSounds'),
                icon: Icons.music_note_rounded,
                value: s.inAppSounds,
                onChanged: (bool value) => app.updateSettings(s.copyWith(inAppSounds: value)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
