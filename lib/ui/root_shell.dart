import 'dart:async';

import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/utils/dates.dart';
import '../data/app_state.dart';
import '../services/notification_service.dart';
import 'app_scope.dart';
import 'screens/calendar_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/events_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/ratings_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/task_details_sheet.dart';
import 'widgets/confetti.dart';
import 'widgets/event_editor_sheet.dart';
import 'widgets/quick_add_sheet.dart';

/// الهيكل الجذري: شاشات التطبيق الخمس + زر الإضافة + التنبيهات.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  DateTime _selectedDay = Dates.today();
  bool _confetti = false;
  Timer? _ticker;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      // منبّه المهام العاجلة داخل التطبيق (حتى لو مُنعت الشاشة الكاملة للنظام).
      // لا نُعيد بناء الواجهة إلّا عند فتح منبّه فعليًا (توفيرًا للسلاسة).
      if (context.appRead.checkDueAlarm()) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _handlePostFrame() {
    final AppState app = context.appRead;
    if (app.newBadges.isNotEmpty) {
      final String id = app.newBadges.removeAt(0);
      final String name = context.tr('badge.$id');
      _toastTimer?.cancel();
      _toastTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: <Widget>[
                  const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('badges.newBadge', <String, String>{'name': name}))),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
      });
    }

    if (app.celebrationPending) {
      app.celebrationPending = false;
      setState(() => _confetti = true);
    }

    final NotifPayload? payload = app.lastTappedPayload;
    if (payload != null) {
      app.consumeTapPayload();
      if (payload.op == 'task' && payload.taskId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showTaskDetailsSheet(context, payload.taskId!);
        });
      } else if (payload.op == 'rate') {
        // إشعار «قيّم يومك»: نفتح صفحة التقييم مباشرة على اليوم المقصود.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final DateTime? day = payload.day == null ? null : Dates.parseKey(payload.day!);
          showRatingSheet(context, day: day ?? Dates.today());
        });
      } else if (payload.op == 'focus') {
        // إشعار جلسة التركيز: نفتح المؤقّت مباشرة.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FocusScreen()),
          );
        });
      } else if (payload.day != null) {
        final DateTime? day = Dates.parseKey(payload.day);
        if (day != null) {
          setState(() {
            _selectedDay = day;
            _index = 1;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.app;
    if (!app.ready) return const SplashScreen();
    // القفل أولًا: لا يظهر أي محتوى قبل إدخال كلمة السر.
    if (app.lockEnabled && app.locked) return const LockScreen();
    if (!app.settings.onboarded) return const OnboardingScreen();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handlePostFrame();
    });

    final List<Widget> pages = <Widget>[
      DashboardScreen(onOpenCalendar: (DateTime day) {
        setState(() {
          _selectedDay = day;
          _index = 1;
        });
      }),
      CalendarScreen(selectedDay: _selectedDay, onDayChanged: (DateTime day) => setState(() => _selectedDay = day)),
      const EventsScreen(),
      const PlansScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: <Widget>[
          IndexedStack(index: _index, children: pages),
          ConfettiOverlay(play: _confetti, onDone: () => setState(() => _confetti = false)),
        ],
      ),
      // الضغط الطويل يفتح المحرّر الكامل مباشرة (الزر نفسه لا يدعم onLongPress).
      floatingActionButton: GestureDetector(
        onLongPress: () => showQuickAddSheet(context, day: Dates.today(), fullEditor: true),
        child: FloatingActionButton(
          onPressed: () {
            // على تبويب الأحداث يُضيف حدثًا، وفي بقية التبويبات يُضيف مهمة سريعة.
            if (_index == 2) {
              showEventEditorSheet(context, day: _selectedDay);
              return;
            }
            showQuickAddSheet(context, day: _index == 1 ? _selectedDay : Dates.today());
          },
          tooltip: context.tr('home.quickAdd'),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: <Widget>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: context.tr('nav.home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month_rounded),
            label: context.tr('nav.calendar'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_note_outlined),
            selectedIcon: const Icon(Icons.event_note_rounded),
            label: context.tr('nav.events'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.repeat_outlined),
            selectedIcon: const Icon(Icons.repeat_rounded),
            label: context.tr('nav.plans'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: context.tr('nav.reports'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: context.tr('nav.settings'),
          ),
        ],
      ),
    );
  }
}
