import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// نتيجة اختيار ملف من الجهاز.
class PickedFile {
  const PickedFile({required this.name, required this.text});

  final String name;
  final String text;
}

/// خدمة الملفات: حفظ/اختيار ملف عبر نظام أندرويد (SAF) بدون أي حزم خارجية.
///
/// المناداة تتم على قناة أصلية مكتوبة داخل التطبيق نفسه؛ وإن لم تكن متاحة
/// (مثل بيئة الاختبار) تُعاد null بدل الانهيار.
class FileService {
  FileService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'injaz/files';

  final MethodChannel _channel;

  /// يحفظ نصًا في ملف يختاره المستخدم (التنزيلات/درايف/أي مجلد).
  ///
  /// يعيد اسم الملف عند النجاح، أو null إذا ألغى المستخدم، أو 'error'.
  Future<String?> saveTextFile({
    required String fileName,
    required String text,
    String mimeType = 'application/json',
  }) async {
    try {
      final String? result = await _channel.invokeMethod<String>('saveFile', <String, dynamic>{
        'name': fileName,
        'mime': mimeType,
        'bytes': Uint8List.fromList(utf8.encode(text)),
      });
      return result;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return 'error';
    }
  }

  /// يفتح ملفًا نصيًا اختاره المستخدم.
  Future<PickedFile?> pickTextFile() async {
    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMapMethod<Object?, Object?>('pickFile', <String, dynamic>{
        'mime': 'application/json',
      });
      if (result == null) return null;
      final Object? bytes = result['bytes'];
      if (bytes is Uint8List) {
        return PickedFile(
          name: (result['name'] ?? '').toString(),
          text: utf8.decode(bytes, allowMalformed: true),
        );
      }
      return null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// منع التقاط الشاشة/ظهور المحتوى في مبدّل التطبيقات (FLAG_SECURE).
  Future<void> setSecureScreen(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setSecure', <String, dynamic>{'enabled': enabled});
    } on MissingPluginException {
      // تجاهل: القناة غير متاحة في هذه البيئة.
    } on PlatformException {
      // تجاهل.
    }
  }

  /// هل خدمة الملفات متاحة على هذا الجهاز؟
  Future<bool> isAvailable() async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>('available');
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
