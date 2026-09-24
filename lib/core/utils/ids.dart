import 'dart:math' as math;

/// توليد معرّفات محلية قصيرة وثابتة.
class Ids {
  Ids._();

  static final math.Random _rnd = math.Random();

  static const String _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String next([String prefix = 'x']) {
    final int t = DateTime.now().millisecondsSinceEpoch;
    final StringBuffer sb = StringBuffer(prefix)..write('_')..write(t.toRadixString(36));
    for (int i = 0; i < 5; i++) {
      sb.write(_chars[_rnd.nextInt(_chars.length)]);
    }
    return sb.toString();
  }

  /// معرّف ثابت لنسخة خطة في يوم معيّن — يمنع تكرار المهام عند إعادة التوليد.
  static String planOccurrence(String planId, String dayKey) => 'po_${planId}_$dayKey';
}
