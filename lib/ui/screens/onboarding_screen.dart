import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/date_names.dart';
import '../../core/utils/dates.dart';
import '../../theme/app_theme.dart';
import '../../theme/palettes.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/progress_ring.dart';

/// شاشة الترحيب والإعداد الأولي (٤ خطوات).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  final TextEditingController _name = TextEditingController();
  int _page = 0;
  int _eveningMinutes = 21 * 60;
  String _language = 'ar';
  int _accent = 0;
  AppThemeMode _themeMode = AppThemeMode.system;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _name.text = context.st.name;
    _language = context.st.language;
    _accent = context.st.accentIndex;
    _themeMode = context.st.themeMode;
    _eveningMinutes = context.st.eveningMinutes;
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              palette.gradient.first.withAlpha(context.isDark ? 90 : 40),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            begin: AlignmentDirectional.topCenter,
            end: AlignmentDirectional.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (int value) => setState(() => _page = value),
                  children: <Widget>[
                    _welcome(context),
                    _namePage(context),
                    _timePage(context),
                    _lookPage(context),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.gap.screenPadding),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < 4; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _page ? 22 : 8,
                        height: 8,
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        decoration: BoxDecoration(
                          color: i == _page ? palette.seed : palette.seed.withAlpha(70),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    const Spacer(),
                    if (_page > 0)
                      TextButton(
                        onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        ),
                        child: Text(context.tr('common.back')),
                      ),
                    FilledButton(
                      onPressed: _next,
                      child: Text(_page == 3 ? context.tr('onboard.start') : context.tr('common.next')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _next() async {
    if (_page < 3) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    final app = context.appRead;
    await app.updateSettings(
      app.settings.copyWith(
        name: _name.text.trim(),
        language: _language,
        accentIndex: _accent,
        themeMode: _themeMode,
        eveningMinutes: _eveningMinutes,
        eveningEnabled: true,
        notificationsEnabled: true,
        onboarded: true,
        createdAt: app.settings.createdAt ?? DateTime.now(),
      ),
      rescheduleNotifications: true,
    );
    await app.notifications.init(onTap: (payload) {});
    await app.notifications.requestNotificationPermission();
    await app.notifications.requestExactAlarmPermission();
    await app.rebuildReminders(immediate: true);
  }

  Widget _welcome(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.gap.screenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: context.palette.linearGradient,
              shape: BoxShape.circle,
            ),
            child: const AppLogomark(size: 84, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('onboard.welcomeTitle'),
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('onboard.welcomeBody'),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          _feature(context, Icons.repeat_rounded, 'onboard.featurePlans', 'onboard.featurePlansDesc'),
          _feature(context, Icons.calendar_month_rounded, 'onboard.featureCalendar', 'onboard.featureCalendarDesc'),
          _feature(context, Icons.notifications_active_rounded, 'onboard.featureNotif', 'onboard.featureNotifDesc'),
        ],
      ),
    );
  }

  Widget _feature(BuildContext context, IconData icon, String titleKey, String descKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: context.palette.seed.withAlpha(context.isDark ? 60 : 28),
              borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
            ),
            child: Icon(icon, color: context.palette.seed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.tr(titleKey), style: Theme.of(context).textTheme.titleSmall),
                Text(context.tr(descKey), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _namePage(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.gap.screenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.tr('onboard.nameTitle'), style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(context.tr('onboard.nameBody'), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 22),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: context.tr('settings.nameHint'),
              prefixIcon: const Icon(Icons.person_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timePage(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.gap.screenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            context.tr('onboard.timeTitle'),
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('onboard.timeBody'),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          AppCard(
            onTap: () async {
              final int? picked = await showTimeWheelSheet(
                context,
                initialMinutes: _eveningMinutes,
                title: context.tr('notif.eveningTime'),
              );
              if (picked != null && picked >= 0) setState(() => _eveningMinutes = picked);
            },
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Column(
              children: <Widget>[
                const Icon(Icons.nightlight_round, size: 34),
                const SizedBox(height: 12),
                Text(
                  DateNames.time(
                    _eveningMinutes,
                    use24: context.st.use24Hour,
                    lang: context.st.language,
                    arabicDigits: context.st.arabicDigits,
                  ),
                  style: AppTheme.numeric(context, factor: 1.9),
                ),
                const SizedBox(height: 6),
                Text(context.tr('notif.evening'), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 10),
                Text(context.tr('common.edit'), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lookPage(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.gap.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.tr('onboard.setupTitle'), style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(context.tr('onboard.setupBody'), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          Text(context.tr('settings.language'), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _choice(context, 'العربية', _language == 'ar', () => setState(() => _language = 'ar')),
              const SizedBox(width: 10),
              _choice(context, 'English', _language == 'en', () => setState(() => _language = 'en')),
            ],
          ),
          const SizedBox(height: 18),
          Text(context.tr('settings.accent'), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (int i = 0; i < Palettes.all.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _accent = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: Palettes.all[i].gradient),
                      shape: BoxShape.circle,
                      border: _accent == i
                          ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.4)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(context.tr('settings.theme'), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _choice(context, context.tr('theme.system'), _themeMode == AppThemeMode.system,
                  () => setState(() => _themeMode = AppThemeMode.system)),
              const SizedBox(width: 8),
              _choice(context, context.tr('theme.light'), _themeMode == AppThemeMode.light,
                  () => setState(() => _themeMode = AppThemeMode.light)),
              const SizedBox(width: 8),
              _choice(context, context.tr('theme.dark'), _themeMode == AppThemeMode.dark,
                  () => setState(() => _themeMode = AppThemeMode.dark)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            Dates.isToday(DateTime.now()) ? context.tr('app.tagline') : '',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _choice(BuildContext context, String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? context.palette.seed : context.palette.seed.withAlpha(context.isDark ? 30 : 16),
            borderRadius: BorderRadius.circular(14 * context.st.radiusScale),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? Colors.white : context.palette.seed,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
