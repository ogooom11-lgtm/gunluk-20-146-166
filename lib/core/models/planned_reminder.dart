import '../enums.dart';

/// تذكير مُخطّط (بيانات خالصة بدون أي اعتماد على النظام) — يسهّل اختبار منطق
/// الجدولة في الاختبارات الآلية.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.key,
    required this.when,
    required this.kind,
    required this.title,
    required this.body,
    this.payload,
    this.lines = const <String>[],
    this.withActions = true,
    this.taskId,
  });

  /// معرّف الإشعار في نظام التشغيل (ثابت لكل عنصر/يوم).
  final int id;

  /// مفتاح فريد يُستخدم لتخصيص المعرّف وحفظه.
  final String key;

  final DateTime when;
  final ReminderKind kind;
  final String title;
  final String body;
  final String? payload;

  /// أسطر إضافية تُعرض بأسلوب Inbox داخل الإشعار.
  final List<String> lines;

  final bool withActions;
  final String? taskId;

  bool isInFuture(DateTime now) => when.isAfter(now.add(const Duration(seconds: 20)));

  @override
  String toString() => 'PlannedReminder($key, $when, ${kind.name})';
}
