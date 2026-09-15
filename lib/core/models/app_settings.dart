import '../enums.dart';

/// كل إعدادات التطبيق — قابلة للتخصيص بدقة من شاشة الإعدادات.
class AppSettings {
  AppSettings({
    this.name = '',
    this.language = 'ar',
    this.themeMode = AppThemeMode.system,
    this.accentIndex = 0,
    this.fontScale = 1.0,
    this.radiusScale = 1.0,
    this.density = UiDensity.cozy,
    this.weekStart = DateTime.saturday,
    Set<int>? workDays,
    this.use24Hour = false,
    this.arabicDigits = false,
    this.showHijri = false,
    this.showQuotes = true,
    this.dailyGoal = 5,
    this.weeklyGoal = 25,
    this.haptics = true,
    this.inAppSounds = true,
    this.confetti = true,
    this.quickAddShortcuts = true,
    this.defaultLeadMinutes = 30,
    this.snoozeMinutes = 10,
    this.notificationsEnabled = true,
    this.eveningEnabled = true,
    this.eveningMinutes = 21 * 60,
    this.morningEnabled = false,
    this.morningMinutes = 8 * 60,
    this.nudgesEnabled = false,
    this.nudgeIntervalMinutes = 30,
    this.maxNudges = 2,
    this.sound = AppSound.calm,
    this.vibration = AppVibration.normal,
    this.privacyMode = false,
    this.actionButtons = true,
    this.groupNotifications = true,
    this.onboarded = false,
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.lockEnabled = false,
    this.lockHash = '',
    this.lockWhenBackground = true,
    this.lockGraceSeconds = 30,
    this.secureScreen = false,
    this.encryptBackupsByDefault = true,
    this.lastExport,
    this.createdAt,
  }) : workDays = workDays ?? <int>{DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday};

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final Set<int> days = <int>{};
    final dynamic rawDays = json['wd'];
    if (rawDays is List) {
      for (final dynamic v in rawDays) {
        if (v is num) days.add(v.toInt());
      }
    }
    return AppSettings(
      name: (json['n'] ?? '').toString(),
      language: (json['lg'] ?? 'ar').toString(),
      themeMode: AppThemeMode.fromName(json['tm']?.toString()),
      accentIndex: (json['ac'] as num?)?.toInt() ?? 0,
      fontScale: (json['fs'] as num?)?.toDouble() ?? 1.0,
      radiusScale: (json['rs'] as num?)?.toDouble() ?? 1.0,
      density: UiDensity.fromName(json['dn']?.toString()),
      weekStart: (json['ws'] as num?)?.toInt() ?? DateTime.saturday,
      workDays: days.isEmpty ? null : days,
      use24Hour: json['h24'] == true,
      arabicDigits: json['ad'] == true,
      showHijri: json['hj'] == true,
      showQuotes: json['q'] != false,
      dailyGoal: (json['dg'] as num?)?.toInt() ?? 5,
      weeklyGoal: (json['wg'] as num?)?.toInt() ?? 25,
      haptics: json['hp'] != false,
      inAppSounds: json['is'] != false,
      confetti: json['cf'] != false,
      quickAddShortcuts: json['qa'] != false,
      defaultLeadMinutes: (json['dl'] as num?)?.toInt() ?? 30,
      snoozeMinutes: (json['sz'] as num?)?.toInt() ?? 10,
      notificationsEnabled: json['ne'] != false,
      eveningEnabled: json['ee'] != false,
      eveningMinutes: (json['em'] as num?)?.toInt() ?? 21 * 60,
      morningEnabled: json['me'] == true,
      morningMinutes: (json['mm'] as num?)?.toInt() ?? 8 * 60,
      nudgesEnabled: json['nu'] == true,
      nudgeIntervalMinutes: (json['ni'] as num?)?.toInt() ?? 30,
      maxNudges: (json['mn'] as num?)?.toInt() ?? 2,
      sound: AppSound.fromName(json['so']?.toString()),
      vibration: AppVibration.fromName(json['vi']?.toString()),
      privacyMode: json['pv'] == true,
      actionButtons: json['ab'] != false,
      groupNotifications: json['gn'] != false,
      onboarded: json['ob'] == true,
      focusMinutes: (json['fm'] as num?)?.toInt() ?? 25,
      breakMinutes: (json['bm'] as num?)?.toInt() ?? 5,
      lockEnabled: json['lk'] == true,
      lockHash: (json['lh'] ?? '').toString(),
      lockWhenBackground: json['lb'] != false,
      lockGraceSeconds: (json['lg2'] as num?)?.toInt() ?? 30,
      secureScreen: json['ss'] == true,
      encryptBackupsByDefault: json['eb'] != false,
      lastExport: json['lx'] != null ? DateTime.tryParse(json['lx'].toString()) : null,
      createdAt: json['cr'] != null ? DateTime.tryParse(json['cr'].toString()) : null,
    );
  }

  String name;
  String language;
  AppThemeMode themeMode;
  int accentIndex;
  double fontScale;
  double radiusScale;
  UiDensity density;

  /// أول يوم في الأسبوع (1=الاثنين ... 7=الأحد).
  int weekStart;

  /// أيام الدوام (1..7) — تُستخدم لحساب "أيام الدوام" في الخطط.
  Set<int> workDays;

  bool use24Hour;
  bool arabicDigits;
  bool showHijri;
  bool showQuotes;
  int dailyGoal;
  int weeklyGoal;
  bool haptics;
  bool inAppSounds;
  bool confetti;
  bool quickAddShortcuts;

  /// التذكير الافتراضي قبل الموعد (دقائق).
  int defaultLeadMinutes;

  /// مدة التأجيل من الإشعار (دقائق).
  int snoozeMinutes;

  // ===== الإشعارات =====
  bool notificationsEnabled;
  bool eveningEnabled;
  int eveningMinutes;
  bool morningEnabled;
  int morningMinutes;
  bool nudgesEnabled;
  int nudgeIntervalMinutes;
  int maxNudges;
  AppSound sound;
  AppVibration vibration;
  bool privacyMode;
  bool actionButtons;
  bool groupNotifications;

  bool onboarded;
  int focusMinutes;
  int breakMinutes;

  // ===== الأمان =====
  /// قفل التطبيق بكلمة سر.
  bool lockEnabled;

  /// بصمة كلمة السر (PBKDF2-HMAC-SHA256) — لا تُخزَّن كلمة السر نفسها أبدًا.
  String lockHash;

  /// القفل تلقائيًا عند مغادرة التطبيق.
  bool lockWhenBackground;

  /// مهلة السماح قبل القفل بعد العودة للتطبيق (ثوانٍ).
  int lockGraceSeconds;

  /// منع التقاط الشاشة وإظهار المحتوى في مبدّل التطبيقات.
  bool secureScreen;

  /// تشفير النسخ الاحتياطية بكلمة سر افتراضيًا.
  bool encryptBackupsByDefault;

  DateTime? lastExport;
  DateTime? createdAt;

  bool get isArabic => language == 'ar';

  /// بصمة إعدادات القنوات — عند تغيّرها تُعاد إنشاء قنوات الإشعارات.
  String get channelVersion {
    final String s = sound.name;
    final String v = privacyMode ? 'p' : 'n';
    return 'v2_${s}_${v}_${vibration.name}';
  }

  AppSettings copyWith({
    String? name,
    String? language,
    AppThemeMode? themeMode,
    int? accentIndex,
    double? fontScale,
    double? radiusScale,
    UiDensity? density,
    int? weekStart,
    Set<int>? workDays,
    bool? use24Hour,
    bool? arabicDigits,
    bool? showHijri,
    bool? showQuotes,
    int? dailyGoal,
    int? weeklyGoal,
    bool? haptics,
    bool? inAppSounds,
    bool? confetti,
    bool? quickAddShortcuts,
    int? defaultLeadMinutes,
    int? snoozeMinutes,
    bool? notificationsEnabled,
    bool? eveningEnabled,
    int? eveningMinutes,
    bool? morningEnabled,
    int? morningMinutes,
    bool? nudgesEnabled,
    int? nudgeIntervalMinutes,
    int? maxNudges,
    AppSound? sound,
    AppVibration? vibration,
    bool? privacyMode,
    bool? actionButtons,
    bool? groupNotifications,
    bool? onboarded,
    int? focusMinutes,
    int? breakMinutes,
    bool? lockEnabled,
    String? lockHash,
    bool? lockWhenBackground,
    int? lockGraceSeconds,
    bool? secureScreen,
    bool? encryptBackupsByDefault,
    DateTime? lastExport,
    DateTime? createdAt,
  }) =>
      AppSettings(
        name: name ?? this.name,
        language: language ?? this.language,
        themeMode: themeMode ?? this.themeMode,
        accentIndex: accentIndex ?? this.accentIndex,
        fontScale: fontScale ?? this.fontScale,
        radiusScale: radiusScale ?? this.radiusScale,
        density: density ?? this.density,
        weekStart: weekStart ?? this.weekStart,
        workDays: workDays ?? Set<int>.from(this.workDays),
        use24Hour: use24Hour ?? this.use24Hour,
        arabicDigits: arabicDigits ?? this.arabicDigits,
        showHijri: showHijri ?? this.showHijri,
        showQuotes: showQuotes ?? this.showQuotes,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        weeklyGoal: weeklyGoal ?? this.weeklyGoal,
        haptics: haptics ?? this.haptics,
        inAppSounds: inAppSounds ?? this.inAppSounds,
        confetti: confetti ?? this.confetti,
        quickAddShortcuts: quickAddShortcuts ?? this.quickAddShortcuts,
        defaultLeadMinutes: defaultLeadMinutes ?? this.defaultLeadMinutes,
        snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        eveningEnabled: eveningEnabled ?? this.eveningEnabled,
        eveningMinutes: eveningMinutes ?? this.eveningMinutes,
        morningEnabled: morningEnabled ?? this.morningEnabled,
        morningMinutes: morningMinutes ?? this.morningMinutes,
        nudgesEnabled: nudgesEnabled ?? this.nudgesEnabled,
        nudgeIntervalMinutes: nudgeIntervalMinutes ?? this.nudgeIntervalMinutes,
        maxNudges: maxNudges ?? this.maxNudges,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        privacyMode: privacyMode ?? this.privacyMode,
        actionButtons: actionButtons ?? this.actionButtons,
        groupNotifications: groupNotifications ?? this.groupNotifications,
        onboarded: onboarded ?? this.onboarded,
        focusMinutes: focusMinutes ?? this.focusMinutes,
        breakMinutes: breakMinutes ?? this.breakMinutes,
        lockEnabled: lockEnabled ?? this.lockEnabled,
        lockHash: lockHash ?? this.lockHash,
        lockWhenBackground: lockWhenBackground ?? this.lockWhenBackground,
        lockGraceSeconds: lockGraceSeconds ?? this.lockGraceSeconds,
        secureScreen: secureScreen ?? this.secureScreen,
        encryptBackupsByDefault: encryptBackupsByDefault ?? this.encryptBackupsByDefault,
        lastExport: lastExport ?? this.lastExport,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'n': name,
        'lg': language,
        'tm': themeMode.name,
        'ac': accentIndex,
        'fs': fontScale,
        'rs': radiusScale,
        'dn': density.name,
        'ws': weekStart,
        'wd': workDays.toList()..sort(),
        'h24': use24Hour,
        'ad': arabicDigits,
        'hj': showHijri,
        'q': showQuotes,
        'dg': dailyGoal,
        'wg': weeklyGoal,
        'hp': haptics,
        'is': inAppSounds,
        'cf': confetti,
        'qa': quickAddShortcuts,
        'dl': defaultLeadMinutes,
        'sz': snoozeMinutes,
        'ne': notificationsEnabled,
        'ee': eveningEnabled,
        'em': eveningMinutes,
        'me': morningEnabled,
        'mm': morningMinutes,
        'nu': nudgesEnabled,
        'ni': nudgeIntervalMinutes,
        'mn': maxNudges,
        'so': sound.name,
        'vi': vibration.name,
        'pv': privacyMode,
        'ab': actionButtons,
        'gn': groupNotifications,
        'ob': onboarded,
        'fm': focusMinutes,
        'bm': breakMinutes,
        'lk': lockEnabled,
        'lh': lockHash,
        'lb': lockWhenBackground,
        'lg2': lockGraceSeconds,
        'ss': secureScreen,
        'eb': encryptBackupsByDefault,
        'lx': lastExport?.toIso8601String(),
        'cr': createdAt?.toIso8601String(),
      };
}
