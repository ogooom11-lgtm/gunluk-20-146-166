import '../core/utils/secure_data.dart';

/// نتيجة استيراد نسخة احتياطية (عادية أو مشفّرة).
enum ImportStatus {
  /// تم الاستيراد بنجاح.
  ok,

  /// الملف مشفّر وكلمة السر غير صحيحة (أو الملف مُعدَّل).
  wrongPassword,

  /// الملف تالف أو غير مدعوم.
  badFile,

  /// النص ليس نسخة احتياطية من هذا التطبيق.
  notBackup,
}

/// مهمة إنشاء بصمة الرمز — تُنفَّذ في عزلة منفصلة (PBKDF2 ثقيل نسبيًا).
Map<String, dynamic> hashPinTask(Map<String, dynamic> args) {
  try {
    return <String, dynamic>{
      'ok': true,
      'data': SecureData.hashPassword((args['password'] ?? '').toString()),
    };
  } catch (_) {
    return <String, dynamic>{'ok': false, 'key': 'secure.hashFailed'};
  }
}

/// مهمة التحقق من الرمز — في عزلة منفصلة حتى تبقى الواجهة سلسة.
Map<String, dynamic> verifyPinTask(Map<String, dynamic> args) {
  try {
    final bool ok = SecureData.verifyPassword(
      (args['password'] ?? '').toString(),
      (args['hash'] ?? '').toString(),
    );
    return <String, dynamic>{'ok': ok};
  } catch (_) {
    return <String, dynamic>{'ok': false};
  }
}

/// مهام التشفير الثقيلة — تُنفَّذ في عزلة منفصلة عبر `compute` حتى لا تتجمّد الواجهة.
///
/// تُعيد قواميس بسيطة (نصوص فقط) لتكون آمنة تمامًا عند نقلها بين العُزَل:
/// `{'ok': true, 'data': ...}` أو `{'ok': false, 'key': مفتاح_رسالة}`.
Map<String, dynamic> encryptBackupTask(Map<String, dynamic> args) {
  try {
    final String file = SecureData.encryptBackup(
      plainJson: args['json'] as String,
      password: args['password'] as String,
      iterations: (args['iterations'] as int?) ?? SecureData.defaultIterations,
    );
    return <String, dynamic>{'ok': true, 'data': file};
  } on SecureDataException catch (e) {
    return <String, dynamic>{'ok': false, 'key': e.messageKey};
  } catch (_) {
    return <String, dynamic>{'ok': false, 'key': 'secure.badFile'};
  }
}

Map<String, dynamic> decryptBackupTask(Map<String, dynamic> args) {
  try {
    final String plain = SecureData.decryptBackup(
      fileText: args['file'] as String,
      password: args['password'] as String,
    );
    return <String, dynamic>{'ok': true, 'data': plain};
  } on SecureDataException catch (e) {
    return <String, dynamic>{'ok': false, 'key': e.messageKey};
  } catch (_) {
    return <String, dynamic>{'ok': false, 'key': 'secure.badFile'};
  }
}

/// ترجمة مفتاح الخطأ إلى حالة استيراد مفهومة.
ImportStatus importStatusForKey(String key) {
  switch (key) {
    case 'secure.wrongPassword':
      return ImportStatus.wrongPassword;
    case 'secure.notBackup':
    case 'secure.unsupportedVersion':
    case 'secure.unsupportedCipher':
    case 'secure.emptyPassword':
      return ImportStatus.badFile;
    default:
      return ImportStatus.badFile;
  }
}
