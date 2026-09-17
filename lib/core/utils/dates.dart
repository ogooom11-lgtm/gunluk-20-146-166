import 'package:flutter/material.dart' show TimeOfDay;

/// أدوات حساب التواريخ والأوقات — كل الحسابات "آمنة" مع التوقيت الصيفي
/// لأنها تعتمد على مكوّنات التاريخ أو على أرقام أيام UTC بدل فروق الميلي ثانية.
class Dates {
  Dates._();

  static const int msPerDay = 86400000;

  /// بداية اليوم (00:00) بالوقت المحلي.
  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime today() => day(DateTime.now());

  /// مفتاح اليوم بصيغة yyyy-MM-dd — يُستخدم للتخزين والمقارنة.
  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parseKey(String? s) {
    if (s == null || s.length < 10) return null;
    final int? y = int.tryParse(s.substring(0, 4));
    final int? m = int.tryParse(s.substring(5, 7));
    final int? d = int.tryParse(s.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime d) => sameDay(d, DateTime.now());

  /// رقم اليوم (عدد الأيام من نقطة مرجعية) — للمقارنات بدون مشاكل التوقيت الصيفي.
  static int dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ msPerDay;

  static int diffDays(DateTime from, DateTime to) => dayNumber(to) - dayNumber(from);

  static DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  static DateTime addMonths(DateTime d, int n) {
    final int targetMonth = d.month + n;
    final int year = d.year + ((targetMonth - 1) ~/ 12);
    final int month = ((targetMonth - 1) % 12) + 1;
    final int last = daysInMonth(year, month);
    return DateTime(year, month, d.day > last ? last : d.day);
  }

  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// ترتيب الأسبوع حسب أول يوم يختاره المستخدم (1=الاثنين ... 7=الأحد).
  static List<int> weekOrder(int weekStart) {
    final List<int> out = <int>[];
    for (int i = 0; i < 7; i++) {
      int v = weekStart + i;
      if (v > 7) v -= 7;
      out.add(v);
    }
    return out;
  }

  /// أول يوم في الأسبوع الذي يحتوي التاريخ [d].
  static DateTime startOfWeek(DateTime d, int weekStart) {
    final int diff = (d.weekday - weekStart + 7) % 7;
    return addDays(d, -diff);
  }

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month, daysInMonth(d.year, d.month));

  /// شبكة الشهر للتقويم: ٦ أسابيع × ٧ أيام = 42 يومًا.
  static List<DateTime> monthGrid(DateTime month, int weekStart) {
    final DateTime first = startOfWeek(startOfMonth(month), weekStart);
    return List<DateTime>.generate(42, (int i) => addDays(first, i));
  }

  static int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

  static TimeOfDay timeOf(int minutes) {
    final int m = minutes % (24 * 60);
    return TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60);
  }

  /// تاريخ ووقت من يوم + دقائق من منتصف الليل.
  static DateTime at(DateTime dayDate, int minutes) =>
      DateTime(dayDate.year, dayDate.month, dayDate.day, (minutes ~/ 60) % 24, minutes % 60);

  static int nowMinutes() {
    final DateTime n = DateTime.now();
    return n.hour * 60 + n.minute;
  }

  /// الفرق بالدقائق بين وقتين في نفس اليوم (قد يكون سالبًا).
  static int diffMinutes(int a, int b) => b - a;

  static String twoDigits(int n) => n < 10 ? '0$n' : '$n';

  /// وصف مختصر للمدة بالدقائق (يُنسّق لاحقًا حسب اللغة).
  static int durationHours(int minutes) => minutes ~/ 60;

  static int durationRemainderMinutes(int minutes) => minutes % 60;
}

/// تحويل التاريخ الميلادي إلى الهجري (تقويم حسابي تقريبي ± يوم).
/// الطريقة المعروفة بـ "Kuwaiti algorithm" وتصلح للسنوات 1924–2077 ميلادي.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;
  final int month; // 1..12
  final int day; // 1..30

  static HijriDate fromGregorian(DateTime date) {
    int y = date.year;
    int m = date.month;
    if (m < 3) {
      y -= 1;
      m += 12;
    }
    final int a = (y / 100).floor();
    final int b = 2 - a + (a / 4).floor();
    final int jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + date.day + b - 1524;
    int l = jd - 1948440 + 10632;
    final int n = ((l - 1) / 10631).floor();
    l = l - 10631 * n + 354;
    final int j = (((10985 - l) / 5316).floor() * ((50 * l) / 17719).floor()) +
        ((l / 5670).floor() * ((43 * l) / 15238).floor());
    l = l -
        (((30 - j) / 15).floor() * ((17719 * j) / 50).floor()) -
        ((j / 16).floor() * ((15238 * j) / 43).floor()) +
        29;
    final int month = ((24 * l) / 709).floor();
    final int day = l - ((709 * month) / 24).floor();
    final int year = 30 * n + j - 30;
    return HijriDate(year, month, day);
  }
}
