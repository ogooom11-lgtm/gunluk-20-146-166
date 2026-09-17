import '../utils/dates.dart';

/// أسماء الأيام والأشهر والتنسيقات النصية للتواريخ (عربي/إنجليزي).
class DateNames {
  DateNames._();

  /// مرتّبة حسب ترتيب Dart للأيام: 1=الاثنين ... 7=الأحد
  static const List<String> arWeekdays = <String>[
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static const List<String> arWeekdaysShort = <String>[
    'اثن',
    'ثلا',
    'أرب',
    'خمي',
    'جمع',
    'سبت',
    'أحد',
  ];

  /// الحروف المفردة لرأس التقويم
  static const List<String> arWeekdaysLetter = <String>['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

  static const List<String> enWeekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> enWeekdaysShort = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const List<String> enWeekdaysLetter = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static const List<String> arMonths = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<String> arMonthsShort = <String>[
    'ينا',
    'فبر',
    'مار',
    'أبر',
    'ماي',
    'يون',
    'يول',
    'أغس',
    'سبت',
    'أكت',
    'نوف',
    'ديس',
  ];

  static const List<String> enMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> enMonthsShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> hijriMonths = <String>[
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static bool isAr(String lang) => lang == 'ar';

  static String weekday(DateTime d, String lang, {bool short = false}) {
    final int i = d.weekday - 1;
    if (isAr(lang)) return short ? arWeekdaysShort[i] : arWeekdays[i];
    return short ? enWeekdaysShort[i] : enWeekdays[i];
  }

  static String weekdayLetter(int weekday, String lang) {
    final int i = weekday - 1;
    return isAr(lang) ? arWeekdaysLetter[i] : enWeekdaysLetter[i];
  }

  static String month(int m, String lang, {bool short = false}) {
    if (m < 1 || m > 12) m = 1;
    if (isAr(lang)) return short ? arMonthsShort[m - 1] : arMonths[m - 1];
    return short ? enMonthsShort[m - 1] : enMonths[m - 1];
  }

  static String hijriMonth(int m) {
    if (m < 1 || m > 12) m = 1;
    return hijriMonths[m - 1];
  }

  /// تحويل الأرقام إلى أرقام عربية-هندية عند الحاجة.
  static String digits(String input, bool arabicIndic) {
    if (!arabicIndic) return input;
    const List<String> eastern = <String>['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final StringBuffer sb = StringBuffer();
    for (final int code in input.runes) {
      if (code >= 48 && code <= 57) {
        sb.write(eastern[code - 48]);
      } else {
        sb.writeCharCode(code);
      }
    }
    return sb.toString();
  }

  /// تنسيق الوقت: 12 أو 24 ساعة مع ص/م بالعربية.
  static String time(int minutes, {required bool use24, required String lang, bool arabicDigits = false}) {
    final int m = ((minutes % 1440) + 1440) % 1440;
    final int h24 = m ~/ 60;
    final int mm = m % 60;
    if (use24) {
      final String s = '${_two(h24)}:${_two(mm)}';
      return digits(s, arabicDigits);
    }
    final int h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final String suffix = isAr(lang) ? (h24 < 12 ? 'ص' : 'م') : (h24 < 12 ? 'AM' : 'PM');
    final String s = '$h12:${_two(mm)} $suffix';
    return digits(s, arabicDigits);
  }

  static String hourLabel(int hour, {required bool use24, required String lang, bool arabicDigits = false}) {
    return time(hour * 60, use24: use24, lang: lang, arabicDigits: arabicDigits);
  }

  /// التاريخ الكامل: الجمعة ١٥ سبتمبر ٢٠٢٦
  static String fullDate(DateTime d, String lang, {bool arabicDigits = false, bool withWeekday = true}) {
    final String name = month(d.month, lang);
    final String body = isAr(lang)
        ? '${digits('${d.day}', arabicDigits)} $name ${digits('${d.year}', arabicDigits)}'
        : '$name ${d.day}, ${d.year}';
    if (!withWeekday) return body;
    return isAr(lang) ? '${weekday(d, lang)} $body' : '${weekday(d, lang)}, $body';
  }

  /// تاريخ مختصر: ١٥ سبتمبر
  static String shortDate(DateTime d, String lang, {bool arabicDigits = false}) {
    if (isAr(lang)) return '${digits('${d.day}', arabicDigits)} ${month(d.month, lang, short: true)}';
    return '${month(d.month, lang, short: true)} ${d.day}';
  }

  static String dateTime(DateTime d, String lang, {required bool use24, bool arabicDigits = false}) {
    final int minutes = d.hour * 60 + d.minute;
    return '${shortDate(d, lang, arabicDigits: arabicDigits)} • ${time(minutes, use24: use24, lang: lang, arabicDigits: arabicDigits)}';
  }

  static String hijri(DateTime d, String lang, {bool arabicDigits = false}) {
    final HijriDate h = HijriDateHelper.of(d);
    if (!isAr(lang)) return '${h.day}/${h.month}/${h.year} AH';
    return '${digits('${h.day}', arabicDigits)} ${hijriMonth(h.month)} ${digits('${h.year}', arabicDigits)} هـ';
  }

  /// وصف المدة بالدقائق: ١ س ٢٥ د
  static String duration(int minutes, String lang, {bool arabicDigits = false}) {
    if (minutes <= 0) return isAr(lang) ? '٠ د' : '0m';
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    if (isAr(lang)) {
      final String hs = h > 0 ? '${digits('$h', arabicDigits)} س' : '';
      final String ms = m > 0 ? '${digits('$m', arabicDigits)} د' : '';
      return ('$hs $ms').trim();
    }
    final String hs = h > 0 ? '${h}h' : '';
    final String ms = m > 0 ? '${m}m' : '';
    return ('$hs $ms').trim();
  }

  /// وصف مجموعة أيام الأسبوع: كل يوم / كل ثلاثاء / أيام محددة
  static String repeatLabel(Set<int> days, String lang, {bool arabicDigits = false, bool prefix = true}) {
    if (days.isEmpty || days.length == 7) {
      return isAr(lang) ? (prefix ? 'كل يوم' : 'يوميًا') : (prefix ? 'Every day' : 'Daily');
    }
    if (days.length == 1) {
      final String d = weekday(_dateForWeekday(days.first), lang);
      return isAr(lang) ? '${prefix ? 'كل ' : ''}$d' : '${prefix ? 'Every ' : ''}$d';
    }
    if (days.length == 2 || days.length == 3) {
      final List<int> sorted = days.toList()..sort();
      final String joined = sorted.map((int w) => weekday(_dateForWeekday(w), lang)).join(isAr(lang) ? ' و' : ' & ');
      return isAr(lang) ? '${prefix ? 'كل ' : ''}$joined' : '${prefix ? 'Every ' : ''}$joined';
    }
    return isAr(lang)
        ? '${digits('${days.length}', arabicDigits)} أيام أسبوعيًا'
        : '${days.length} days a week';
  }

  /// تاريخ يمثّل يوم الأسبوع المطلوب (لأغراض الطباعة فقط).
  static DateTime _dateForWeekday(int weekday) {
    final DateTime base = DateTime(2024, 1, 1); // الاثنين
    return Dates.addDays(base, weekday - 1);
  }

  static String _two(int n) => n < 10 ? '0$n' : '$n';
}

/// واجهة صغيرة لفصل حساب الهجري (يسهّل الاستبدال مستقبلًا).
class HijriDateHelper {
  HijriDateHelper._();
  static HijriDate of(DateTime d) => HijriDate.fromGregorian(d);
}
