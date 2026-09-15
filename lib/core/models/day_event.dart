import '../utils/dates.dart';
import '../utils/ids.dart';

/// حدث يومي: شيء حصل (أو سيحصل) في يوم معيّن — يُحفظ للأبد فلا يُحذف تلقائيًا.
///
/// يمكن أن يكون له وقت محدّد، مكان، ملاحظات، فئة، وعلامة «مميّز».
class DayEvent {
  DayEvent({
    required this.id,
    required this.title,
    required this.day,
    this.minutes,
    this.notes = '',
    this.place = '',
    this.categoryId = 'general',
    this.iconKey,
    this.starred = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory DayEvent.fromJson(Map<String, dynamic> json) => DayEvent(
        id: (json['id'] ?? Ids.next('ev')).toString(),
        title: (json['t'] ?? '').toString(),
        day: Dates.parseKey((json['d'] ?? '').toString()) ?? Dates.today(),
        minutes: (json['m'] as num?)?.toInt(),
        notes: (json['n'] ?? '').toString(),
        place: (json['p'] ?? '').toString(),
        categoryId: (json['c'] ?? 'general').toString(),
        iconKey: json['i']?.toString(),
        starred: json['s'] == true,
        createdAt: json['ca'] != null ? DateTime.tryParse(json['ca'].toString()) : null,
        updatedAt: json['u'] != null ? DateTime.tryParse(json['u'].toString()) : null,
      );

  final String id;
  String title;

  /// يوم الحدث (بلا وقت).
  DateTime day;

  /// دقائق من منتصف الليل، و null يعني «بلا وقت محدّد».
  int? minutes;

  String notes;
  String place;
  String categoryId;

  /// مفتاح أيقونة مخصّص (اختياري) — يُستخدم بدل أيقونة الفئة.
  String? iconKey;

  bool starred;
  DateTime createdAt;
  DateTime updatedAt;

  bool get hasTime => minutes != null;

  String get dayKey => Dates.key(day);

  bool isOn(DateTime other) => Dates.sameDay(day, other);

  /// ترتيب عرض الأحداث: الأحدث يومًا أولًا، وداخل اليوم حسب الساعة
  /// (الموقوتة قبل غير الموقوتة)، ثم الأحدث إضافةً.
  static int compareDesc(DayEvent a, DayEvent b) {
    final int byDay = b.day.compareTo(a.day);
    if (byDay != 0) return byDay;
    final int? am = a.minutes;
    final int? bm = b.minutes;
    if (am != null && bm != null) return am.compareTo(bm);
    if (am != null) return -1;
    if (bm != null) return 1;
    return b.createdAt.compareTo(a.createdAt);
  }

  /// ترتيب تصاعدي داخل اليوم الواحد (يُستخدم في عرض اليوم).
  static int compareInDay(DayEvent a, DayEvent b) {
    final int? am = a.minutes;
    final int? bm = b.minutes;
    if (am != null && bm != null) return am.compareTo(bm);
    if (am != null) return -1;
    if (bm != null) return 1;
    return a.createdAt.compareTo(b.createdAt);
  }

  DayEvent copyWith({
    String? title,
    DateTime? day,
    int? minutes,
    bool clearMinutes = false,
    String? notes,
    String? place,
    String? categoryId,
    String? iconKey,
    bool clearIcon = false,
    bool? starred,
  }) =>
      DayEvent(
        id: id,
        title: title ?? this.title,
        day: day ?? this.day,
        minutes: clearMinutes ? null : (minutes ?? this.minutes),
        notes: notes ?? this.notes,
        place: place ?? this.place,
        categoryId: categoryId ?? this.categoryId,
        iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
        starred: starred ?? this.starred,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        't': title,
        'd': dayKey,
        'm': minutes,
        'n': notes,
        'p': place,
        'c': categoryId,
        'i': iconKey,
        's': starred,
        'ca': createdAt.toIso8601String(),
        'u': updatedAt.toIso8601String(),
      };
}
