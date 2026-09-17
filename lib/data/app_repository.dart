import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// التخزين المحلي للتطبيق: مستند JSON واحد داخل SharedPreferences.
/// بسيط، سريع، سهل النسخ الاحتياطي، ولا يحتاج إنترنت ولا قاعدة بيانات.
class AppRepository {
  AppRepository();

  static const String dataKey = 'injaz.data.v1';
  static const String opsKey = 'injaz.pendingOps.v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  SharedPreferences? get prefsOrNull => _prefs;

  /// قراءة كل بيانات التطبيق.
  Map<String, dynamic> read() {
    final SharedPreferences? p = _prefs;
    if (p == null) return <String, dynamic>{};
    final String? raw = p.getString(dataKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> write(Map<String, dynamic> data) async {
    final SharedPreferences p = await ensure();
    await p.setString(dataKey, jsonEncode(data));
  }

  /// إعادة تحميل القيم من النظام (لاستقبال العمليات التي نُفّذت من إشعار في الخلفية).
  Future<void> reload() async {
    final SharedPreferences p = await ensure();
    await p.reload();
  }

  Future<void> clearAll() async {
    final SharedPreferences p = await ensure();
    await p.remove(dataKey);
    await p.remove(opsKey);
  }

  /// إضافة عملية معلّقة (تُنفَّذ عند فتح التطبيق) — تُستدعى من معالج الإشعارات.
  Future<void> pushOp(Map<String, dynamic> op) async {
    final SharedPreferences p = await ensure();
    final List<Map<String, dynamic>> ops = _decodeOps(p.getString(opsKey));
    ops.add(op);
    if (ops.length > 50) {
      ops.removeRange(0, ops.length - 50);
    }
    await p.setString(opsKey, jsonEncode(ops));
  }

  Future<List<Map<String, dynamic>>> takeOps() async {
    final SharedPreferences p = await ensure();
    final List<Map<String, dynamic>> ops = _decodeOps(p.getString(opsKey));
    if (ops.isNotEmpty) {
      await p.remove(opsKey);
    }
    return ops;
  }

  List<Map<String, dynamic>> _decodeOps(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  // ===== أدوات مساعدة للقراءة الآمنة =====

  static Map<String, dynamic> map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic> list(dynamic value) => value is List ? value : <dynamic>[];

  static List<Map<String, dynamic>> mapList(dynamic value) => list(value)
      .whereType<Map>()
      .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
      .toList();
}
