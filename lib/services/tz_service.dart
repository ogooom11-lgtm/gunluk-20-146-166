import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// تهيئة قاعدة بيانات المناطق الزمنية (مطلوبة لجدولة الإشعارات).
/// نحدد المنطقة الأقرب لإزاحة الجهاز الحالية — بدون الحاجة لأي إذن إضافي.
class TzService {
  TzService._();

  static bool _ready = false;

  static const List<String> _candidates = <String>[
    'Asia/Riyadh',
    'Asia/Dubai',
    'Asia/Qatar',
    'Asia/Kuwait',
    'Asia/Bahrain',
    'Asia/Muscat',
    'Asia/Baghdad',
    'Asia/Amman',
    'Asia/Beirut',
    'Asia/Damascus',
    'Asia/Gaza',
    'Asia/Hebron',
    'Asia/Aden',
    'Asia/Tehran',
    'Asia/Karachi',
    'Asia/Kolkata',
    'Africa/Cairo',
    'Africa/Tripoli',
    'Africa/Tunis',
    'Africa/Algiers',
    'Africa/Casablanca',
    'Africa/Khartoum',
    'Europe/Istanbul',
    'Europe/London',
    'Europe/Paris',
    'Europe/Berlin',
    'Europe/Moscow',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'Australia/Sydney',
    'UTC',
  ];

  static void ensure() {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(_resolve());
    } catch (_) {
      // في حال فشل أي شيء نبقى على UTC حتى لا يتعطّل التطبيق
    }
    _ready = true;
  }

  static tz.Location _resolve() {
    final int offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    for (final String name in _candidates) {
      try {
        final tz.Location location = tz.getLocation(name);
        if (location.currentTimeZone.offset == offsetMinutes) return location;
      } catch (_) {
        continue;
      }
    }
    // محاولة ثانية: مناطق ذات إزاحة ثابتة (Etc/GMT معكوسة الإشارة)
    final int hours = (offsetMinutes / 60).round();
    final String sign = hours <= 0 ? '+' : '-';
    final String etc = 'Etc/GMT$sign${hours.abs()}';
    try {
      return tz.getLocation(etc);
    } catch (_) {
      return tz.UTC;
    }
  }

  static tz.TZDateTime from(DateTime dateTime) {
    ensure();
    return tz.TZDateTime.from(dateTime, tz.local);
  }
}
