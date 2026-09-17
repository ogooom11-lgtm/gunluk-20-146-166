import 'dart:typed_data';

import 'package:flutter/material.dart';

/// أولوية المهمة — تؤثر على ترتيب العرض، اللون، ونقاط الخبرة.
enum TaskPriority {
  low('priority.low', 0, 5, Color(0xFF7A8BA6)),
  medium('priority.medium', 1, 10, Color(0xFF3E8FD8)),
  high('priority.high', 2, 20, Color(0xFFE08A2E)),
  urgent('priority.urgent', 3, 30, Color(0xFFE05B5B));

  const TaskPriority(this.labelKey, this.rank, this.xp, this.color);

  final String labelKey;
  final int rank;
  final int xp;
  final Color color;

  static TaskPriority fromName(String? name) {
    for (final TaskPriority p in TaskPriority.values) {
      if (p.name == name) return p;
    }
    return TaskPriority.medium;
  }
}

/// حالة العنصر (مهمة أو نسخة خطة).
enum ItemState { pending, done, skipped, missed }

/// نوع تكرار الخطة.
enum RepeatType {
  daily('repeat.daily'),
  weekly('repeat.weekly'),
  interval('repeat.interval'),
  monthly('repeat.monthly');

  const RepeatType(this.labelKey);
  final String labelKey;

  static RepeatType fromName(String? name) {
    for (final RepeatType r in RepeatType.values) {
      if (r.name == name) return r;
    }
    return RepeatType.weekly;
  }
}

/// وضع السمة (فاتح/غامق/حسب النظام).
enum AppThemeMode {
  system('theme.system'),
  light('theme.light'),
  dark('theme.dark');

  const AppThemeMode(this.labelKey);
  final String labelKey;

  static AppThemeMode fromName(String? name) {
    for (final AppThemeMode m in AppThemeMode.values) {
      if (m.name == name) return m;
    }
    return AppThemeMode.system;
  }
}

/// كثافة العرض.
enum UiDensity {
  compact('density.compact'),
  cozy('density.cozy'),
  comfortable('density.comfortable');

  const UiDensity(this.labelKey);
  final String labelKey;

  static UiDensity fromName(String? name) {
    for (final UiDensity d in UiDensity.values) {
      if (d.name == name) return d;
    }
    return UiDensity.cozy;
  }
}

/// صوت الإشعار المختار (ملفات صوتية مرفقة داخل التطبيق).
enum AppSound {
  calm('sound.calm', 'injaz_calm'),
  chime('sound.chime', 'injaz_chime'),
  bell('sound.bell', 'injaz_bell'),
  soft('sound.soft', 'injaz_soft'),
  silent('sound.silent', null);

  const AppSound(this.labelKey, this.resource);

  final String labelKey;

  /// اسم الملف داخل res/raw (بدون الامتداد) — null يعني بدون صوت.
  final String? resource;

  static AppSound fromName(String? name) {
    for (final AppSound s in AppSound.values) {
      if (s.name == name) return s;
    }
    return AppSound.calm;
  }
}

/// نمط الاهتزاز.
enum AppVibration {
  normal('vibration.normal'),
  soft('vibration.soft'),
  strong('vibration.strong'),
  off('vibration.off');

  const AppVibration(this.labelKey);
  final String labelKey;

  static AppVibration fromName(String? name) {
    for (final AppVibration v in AppVibration.values) {
      if (v.name == name) return v;
    }
    return AppVibration.normal;
  }

  Int64List? get pattern {
    switch (this) {
      case AppVibration.normal:
        return Int64List.fromList(<int>[0, 350, 180, 300]);
      case AppVibration.soft:
        return Int64List.fromList(<int>[0, 150, 120, 150]);
      case AppVibration.strong:
        return Int64List.fromList(<int>[0, 600, 250, 600, 250, 600]);
      case AppVibration.off:
        return null;
    }
  }
}

/// نوع التذكير — يُستخدم لاختيار القناة والمحتوى.
enum ReminderKind {
  task('channel.taskName', 'channel.taskDesc'),
  upcoming('channel.upcomingName', 'channel.upcomingDesc'),
  nudge('channel.nudgeName', 'channel.nudgeDesc'),
  review('channel.reviewName', 'channel.reviewDesc'),
  morning('channel.morningName', 'channel.morningDesc'),
  alarm('channel.alarmName', 'channel.alarmDesc');

  const ReminderKind(this.nameKey, this.descKey);
  final String nameKey;
  final String descKey;

  /// معرّف القناة داخل أندرويد (يتغيّر مع رقم إصدار القناة).
  String channelId(String version) => 'injaz_${name}_$version';

  static ReminderKind fromName(String? name) {
    for (final ReminderKind k in ReminderKind.values) {
      if (k.name == name) return k;
    }
    return ReminderKind.task;
  }
}
