import 'package:flutter/material.dart' show IconData, Icons;

import '../utils/ids.dart';

/// خطوة فرعية داخل مهمة أو قالب خطوات في خطة.
class Subtask {
  Subtask({required this.id, required this.title, this.done = false});

  factory Subtask.create(String title, {bool done = false}) =>
      Subtask(id: Ids.next('st'), title: title, done: done);

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
        id: (json['id'] ?? Ids.next('st')).toString(),
        title: (json['t'] ?? json['title'] ?? '').toString(),
        done: json['d'] == true || json['done'] == true,
      );

  final String id;
  String title;
  bool done;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 't': title, 'd': done};

  Subtask copy() => Subtask(id: id, title: title, done: done);

  Subtask copyWith({String? title, bool? done}) =>
      Subtask(id: id, title: title ?? this.title, done: done ?? this.done);
}

/// فئة (تصنيف) للمهام والخطط — قابلة للتخصيص بالكامل من المستخدم.
class Category {
  Category({
    required this.id,
    required this.name,
    required this.color,
    required this.iconKey,
    this.isDefault = false,
    this.archived = false,
    this.order = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['id'] ?? '').toString(),
        name: (json['n'] ?? '').toString(),
        color: (json['c'] as num?)?.toInt() ?? 0xFF5B6BF0,
        iconKey: (json['i'] ?? 'star').toString(),
        isDefault: json['def'] == true,
        archived: json['ar'] == true,
        order: (json['o'] as num?)?.toInt() ?? 0,
      );

  final String id;
  String name;

  /// قيمة اللون بصيغة ARGB.
  int color;
  String iconKey;
  bool isDefault;
  bool archived;
  int order;

  IconData get icon => CategoryIcons.byKey(iconKey);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'n': name,
        'c': color,
        'i': iconKey,
        'def': isDefault,
        'ar': archived,
        'o': order,
      };

  Category copyWith({String? name, int? color, String? iconKey, bool? archived, int? order}) => Category(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        iconKey: iconKey ?? this.iconKey,
        isDefault: isDefault,
        archived: archived ?? this.archived,
        order: order ?? this.order,
      );
}

/// مجموعة أيقونات جاهزة للفئات (ثوابت — بأمان مع تقليم الأيقونات في البناء).
class CategoryIcons {
  CategoryIcons._();

  static const Map<String, IconData> map = <String, IconData>{
    'star': Icons.star_rounded,
    'check': Icons.check_circle_rounded,
    'work': Icons.work_rounded,
    'book': Icons.menu_book_rounded,
    'mosque': Icons.mosque_rounded,
    'fitness': Icons.fitness_center_rounded,
    'run': Icons.directions_run_rounded,
    'home': Icons.home_rounded,
    'family': Icons.family_restroom_rounded,
    'heart': Icons.favorite_rounded,
    'brain': Icons.psychology_rounded,
    'school': Icons.school_rounded,
    'code': Icons.code_rounded,
    'brush': Icons.brush_rounded,
    'music': Icons.music_note_rounded,
    'money': Icons.savings_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'call': Icons.call_rounded,
    'mail': Icons.mail_rounded,
    'car': Icons.directions_car_rounded,
    'flight': Icons.flight_takeoff_rounded,
    'garden': Icons.yard_rounded,
    'water': Icons.water_drop_rounded,
    'food': Icons.restaurant_rounded,
    'sleep': Icons.bedtime_rounded,
    'sun': Icons.wb_sunny_rounded,
    'moon': Icons.nightlight_round,
    'timer': Icons.timer_rounded,
    'target': Icons.gps_fixed_rounded,
    'flag': Icons.flag_rounded,
    'trophy': Icons.emoji_events_rounded,
    'build': Icons.handyman_rounded,
    'science': Icons.science_rounded,
    'language': Icons.translate_rounded,
    'meditation': Icons.self_improvement_rounded,
    'groups': Icons.groups_rounded,
    'pets': Icons.pets_rounded,
    'lightbulb': Icons.lightbulb_rounded,
  };

  static const List<String> keys = <String>[
    'star',
    'check',
    'work',
    'book',
    'mosque',
    'fitness',
    'run',
    'home',
    'family',
    'heart',
    'brain',
    'school',
    'code',
    'brush',
    'music',
    'money',
    'shopping',
    'call',
    'mail',
    'car',
    'flight',
    'garden',
    'water',
    'food',
    'sleep',
    'sun',
    'moon',
    'timer',
    'target',
    'flag',
    'trophy',
    'build',
    'science',
    'language',
    'meditation',
    'groups',
    'pets',
    'lightbulb',
  ];

  static IconData byKey(String key) => map[key] ?? Icons.star_rounded;
}

/// لوحة الألوان المتاحة للفئات.
class CategoryColors {
  CategoryColors._();

  static const List<int> values = <int>[
    0xFF5B6BF0,
    0xFF3E8FD8,
    0xFF2FA8A0,
    0xFF43A047,
    0xFF8BC34A,
    0xFFE0A02E,
    0xFFE08A2E,
    0xFFE05B5B,
    0xFFD6497F,
    0xFF9C4DCC,
    0xFF6D5BD0,
    0xFF546E7A,
  ];
}
