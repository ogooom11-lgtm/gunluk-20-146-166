import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/enums.dart';
import 'core/l10n/app_strings.dart';
import 'data/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/app_scope.dart';
import 'ui/root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // شريط حالة شفاف مع أيقونات متناسقة
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final AppState state = AppState();
  runApp(InjaziApp(state: state));
  // التهيئة في الخلفية كي لا تتأخر الواجهة الأولى
  await state.initOnce();
}

/// الواجهة الجذرية للتطبيق.
class InjaziApp extends StatefulWidget {
  const InjaziApp({super.key, required this.state});

  final AppState state;

  @override
  State<InjaziApp> createState() => _InjaziAppState();
}

class _InjaziAppState extends State<InjaziApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // استقبال أي عمليات نُفّذت من أزرار الإشعارات أثناء إغلاق التطبيق
      widget.state.refreshFromStorage();
      widget.state.rebuildReminders(immediate: true);
      widget.state.handleResumed();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      widget.state.handleBackgrounded();
      widget.state.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      // يعيد بناء MaterialApp عند أي تغيير في الحالة، فتسري السمة واللغة
      // والاتجاه وحجم الخط فورًا من الإعدادات.
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (BuildContext context, Widget? _) {
          final AppState app = widget.state;
          final settings = app.settings;
          final ThemeMode mode = switch (settings.themeMode) {
            AppThemeMode.dark => ThemeMode.dark,
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.system => ThemeMode.system,
          };

          return MaterialApp(
            title: 'إنجازي',
            debugShowCheckedModeBanner: false,
            locale: Locale(settings.language),
            supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(settings),
            darkTheme: AppTheme.dark(settings),
            themeMode: mode,
            builder: (BuildContext context, Widget? child) {
              final MediaQueryData mq = MediaQuery.of(context);
              final double scaled = (mq.textScaler.scale(1.0) * settings.fontScale).clamp(0.8, 1.8);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(scaled)),
                child: Directionality(
                  textDirection: settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: const RootShell(),
          );
        },
      ),
    );
  }
}
