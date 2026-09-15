import '../utils/ids.dart';

/// ملاحظة/انطباع عن يوم معيّن (سجل اليوم) — مع تقييم مزاجي بسيط.
class DayNote {
  DayNote({
    required this.day,
    this.text = '',
    this.mood = -1,
    this.updatedAt,
  });

  factory DayNote.fromJson(Map<String, dynamic> json) => DayNote(
        day: (json['d'] ?? '').toString(),
        text: (json['t'] ?? '').toString(),
        mood: (json['m'] as num?)?.toInt() ?? -1,
        updatedAt: json['u'] != null ? DateTime.tryParse(json['u'].toString()) : null,
      );

  /// بصيغة yyyy-MM-dd.
  final String day;
  String text;

  /// 0 = سيء … 4 = ممتاز، و -1 يعني لم يُحدّد.
  int mood;

  DateTime? updatedAt;

  bool get isEmpty => text.trim().isEmpty && mood < 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'd': day,
        't': text,
        'm': mood,
        'u': updatedAt?.toIso8601String(),
      };
}

/// جلسة تركيز (مؤقّت بومودورو) — تُحسب في التقارير.
class FocusSession {
  FocusSession({
    required this.id,
    required this.start,
    required this.minutes,
    this.taskId,
    this.label = '',
    this.completed = true,
  });

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: (json['id'] ?? Ids.next('fs')).toString(),
        start: DateTime.tryParse((json['s'] ?? '').toString()) ?? DateTime.now(),
        minutes: (json['m'] as num?)?.toInt() ?? 0,
        taskId: json['t']?.toString(),
        label: (json['l'] ?? '').toString(),
        completed: json['c'] != false,
      );

  final String id;
  final DateTime start;
  final int minutes;
  final String? taskId;
  final String label;
  final bool completed;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        's': start.toIso8601String(),
        'm': minutes,
        't': taskId,
        'l': label,
        'c': completed,
      };
}
