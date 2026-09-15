import 'package:flutter/material.dart';

import '../core/models/subtask.dart';

/// البيانات الافتراضية: الفئات، العبارات التحفيزية، والشارات.
class Defaults {
  Defaults._();

  static List<Category> categories() => <Category>[
        Category(id: 'general', name: 'عام', color: 0xFF5B6BF0, iconKey: 'star', isDefault: true, order: 0),
        Category(id: 'worship', name: 'عبادة', color: 0xFF2FA8A0, iconKey: 'mosque', isDefault: true, order: 1),
        Category(id: 'work', name: 'عمل', color: 0xFF3E8FD8, iconKey: 'work', isDefault: true, order: 2),
        Category(id: 'study', name: 'تعلّم ودراسة', color: 0xFF6D5BD0, iconKey: 'book', isDefault: true, order: 3),
        Category(id: 'health', name: 'صحة ورياضة', color: 0xFF43A047, iconKey: 'fitness', isDefault: true, order: 4),
        Category(id: 'family', name: 'أسرة ومنزل', color: 0xFFD6497F, iconKey: 'home', isDefault: true, order: 5),
        Category(id: 'self', name: 'تطوير ذاتي', color: 0xFFE0A02E, iconKey: 'lightbulb', isDefault: true, order: 6),
        Category(id: 'finance', name: 'مالية', color: 0xFF8BC34A, iconKey: 'money', isDefault: true, order: 7),
        Category(id: 'project', name: 'مشروع', color: 0xFFE08A2E, iconKey: 'build', isDefault: true, order: 8),
      ];

  /// عبارات تحفيزية عربية (قصيرة، متنوعة، وبعضها مأثور).
  static const List<List<String>> quotes = <List<String>>[
    <String>['قليلٌ دائمٌ خيرٌ من كثيرٍ منقطع', 'حديث نبوي'],
    <String>['إن الله يحب إذا عمل أحدكم عملًا أن يتقنه', 'حديث نبوي'],
    <String>['خير العمل ما داوم عليه صاحبه', 'حديث نبوي'],
    <String>['خطوة واحدة كل يوم تكفي لتصل', ''],
    <String>['لا تؤجّل عمل اليوم إلى الغد', ''],
    <String>['الاستمرارية تتفوّق على الحماس', ''],
    <String>['ابدأ، ولو بدقيقة واحدة', ''],
    <String>['التخطيط نصف الإنجاز', ''],
    <String>['إنجازٌ صغير الآن خيرٌ من كمالٍ مؤجّل', ''],
    <String>['الوقت كالسيف إن لم تقطعه قطعك', ''],
    <String>['من جدّ وجد، ومن زرع حصد', ''],
    <String>['اصنع اليوم ما يفتخر به غدُك', ''],
    <String>['أنت أقرب إلى هدفك مما كنت أمس', ''],
    <String>['لا تقارن بدايتك بنهاية غيرك', ''],
    <String>['الروتين الهادئ يصنع إنجازًا عظيمًا', ''],
    <String>['كل يوم فرصة جديدة لا تتكرر', ''],
    <String>['أنجز ثم ارتح، فراحة بعد العمل أحلى', ''],
    <String>['صغار الأعمال المتكررة تبني الكبار', ''],
    <String>['حاسب نفسك قبل أن تُحاسب', ''],
    <String>['العلم في الصغر كالنقش على الحجر', ''],
    <String>['بالجدّ والاجتهاد تُنال المعالي', ''],
    <String>['لا شيء يستحق أن تُضيّع يومك من أجله', ''],
    <String>['النجاح مجموع خطوات صغيرة تتكرر', ''],
    <String>['اجعل هدفك واضحًا ثم اسرِ خطوة', ''],
    <String>['أفضل وقت لتبدأ كان بالأمس، والثاني الآن', ''],
    <String>['من نظّم وقته، ملك يومه', ''],
    <String>['قيمة الإنجاز في إتمامه لا في بدايته', ''],
    <String>['احبس نفسك على طاعة، تُحبس عليك البركة', ''],
  ];

  static List<String> quoteFor(DateTime day) {
    final int index = (day.year * 372 + day.month * 31 + day.day) % quotes.length;
    return quotes[index];
  }

  /// شارات الإنجاز مع أهدافها.
  static const List<BadgeDef> badges = <BadgeDef>[
    BadgeDef('firstTask', Icons.emoji_events_rounded, 1, BadgeMetric.totalDone),
    BadgeDef('streak3', Icons.local_fire_department_rounded, 3, BadgeMetric.streak),
    BadgeDef('streak7', Icons.whatshot_rounded, 7, BadgeMetric.streak),
    BadgeDef('streak30', Icons.calendar_month_rounded, 30, BadgeMetric.streak),
    BadgeDef('done30', Icons.done_all_rounded, 30, BadgeMetric.totalDone),
    BadgeDef('done100', Icons.military_tech_rounded, 100, BadgeMetric.totalDone),
    BadgeDef('perfectDay', Icons.wb_twilight_rounded, 1, BadgeMetric.perfectDays),
    BadgeDef('perfectWeek', Icons.auto_awesome_rounded, 7, BadgeMetric.perfectDaysInWeek),
    BadgeDef('planMaster', Icons.flag_circle_rounded, 1, BadgeMetric.finishedPlans),
    BadgeDef('earlyBird', Icons.wb_sunny_rounded, 10, BadgeMetric.earlyDone),
    BadgeDef('nightOwl', Icons.nightlight_round, 10, BadgeMetric.nightDone),
    BadgeDef('focusChampion', Icons.timer_rounded, 600, BadgeMetric.focusMinutes),
  ];
}

/// المقاييس المستخدمة لتقييم الشارات.
enum BadgeMetric { totalDone, streak, perfectDays, perfectDaysInWeek, finishedPlans, earlyDone, nightDone, focusMinutes }

/// تعريف شارة.
class BadgeDef {
  const BadgeDef(this.id, this.icon, this.target, this.metric);

  final String id;
  final IconData icon;
  final int target;
  final BadgeMetric metric;

  String get titleKey => 'badge.$id';
  String get descKey => 'badge.${id}Desc';
}

/// حالة شارة: القيمة الحالية مقابل الهدف.
class BadgeProgress {
  const BadgeProgress(this.def, this.value, this.unlockedAt);

  final BadgeDef def;
  final int value;
  final DateTime? unlockedAt;

  bool get unlocked => unlockedAt != null || value >= def.target;

  double get ratio => def.target == 0 ? 1 : (value / def.target).clamp(0.0, 1.0);

  int get remaining => (def.target - value) < 0 ? 0 : def.target - value;
}
