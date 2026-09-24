/// مساعدات قراءة JSON بأمان (بلا أي تبعية خارجية).
class AppJson {
  AppJson._();

  /// يحوّل قيمة JSON إلى خريطة نصّية — ويعيد خريطة فارغة لأي شكل آخر.
  static Map<String, dynamic> map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  /// يحوّل قيمة JSON إلى قائمة — ويعيد قائمة فارغة لأي شكل آخر.
  static List<dynamic> list(dynamic value) => value is List ? value : <dynamic>[];
}
