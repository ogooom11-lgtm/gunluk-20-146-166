import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/utils/secure_data.dart';

String _hex(List<int> bytes) =>
    bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _fromHex(String hex) => Uint8List.fromList(<int>[
      for (int i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
    ]);

void main() {
  group('PBKDF2-HMAC-SHA256 (متجهات معلومة)', () {
    test('password/salt بعدّاد ١', () {
      final Uint8List key = SecureData.pbkdf2(
        Uint8List.fromList(utf8.encode('password')),
        Uint8List.fromList(utf8.encode('salt')),
        1,
        32,
      );
      expect(_hex(key), '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    });

    test('password/salt بعدّاد ٤٠٩٦', () {
      final Uint8List key = SecureData.pbkdf2(
        Uint8List.fromList(utf8.encode('password')),
        Uint8List.fromList(utf8.encode('salt')),
        4096,
        32,
      );
      expect(_hex(key), 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });

    test('مفتاح أطول من كتلة واحدة (٤٠ بايت)', () {
      final Uint8List key = SecureData.pbkdf2(
        Uint8List.fromList(utf8.encode('passwordPASSWORDpassword')),
        Uint8List.fromList(utf8.encode('saltSALTsaltSALTsaltSALTsaltSALTsalt')),
        4096,
        40,
      );
      expect(
        _hex(key),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1'
        'c635518c7dac47e9',
      );
    });

    test('عدّاد غير صالح يُرفض', () {
      expect(
        () => SecureData.pbkdf2(Uint8List(1), Uint8List(1), 0),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('AES (متجهات FIPS-197)', () {
    test('AES-128: تشفير كتلة واحدة', () {
      final Uint8List key = _fromHex('000102030405060708090a0b0c0d0e0f');
      final Uint8List block = _fromHex('00112233445566778899aabbccddeeff');
      // في نمط CTR تكون النتيجة E(الكتلة) عند تشفير أصفار مع كتلة عدّاد = الكتلة.
      final Uint8List out = SecureData.aesCtrProcess(key, block, Uint8List(16));
      expect(_hex(out), '69c4e0d86a7b0430d8cdb78070b4c55a');
    });

    test('AES-256: تشفير كتلة واحدة', () {
      final Uint8List key =
          _fromHex('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f');
      final Uint8List block = _fromHex('00112233445566778899aabbccddeeff');
      final Uint8List out = SecureData.aesCtrProcess(key, block, Uint8List(16));
      expect(_hex(out), '8ea2b7ca516745bfeafc49904b496089');
    });

    test('AES-256-CTR: متجه NIST SP 800-38A (٤ كتل)', () {
      final Uint8List key =
          _fromHex('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
      final Uint8List counter = _fromHex('f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff');
      final Uint8List plain = _fromHex(
        '6bc1bee22e409f96e93d7e117393172a'
        'ae2d8a571e03ac9c9eb76fac45af8e51'
        '30c81c46a35ce411e5fbc1191a0a52ef'
        'f69f2445df4f9b17ad2b417be66c3710',
      );
      final Uint8List out = SecureData.aesCtrProcess(key, counter, plain);
      expect(
        _hex(out),
        '601ec313775789a5b7a7f504bbf3d228'
        'f443e3ca4d62b59aca84e990cacaf5c5'
        '2b0930daa23de94ce87017ba2d84988d'
        'dfc9c58db67aada613c2dd08457941a6',
      );
      // الفك يعيد النص الأصلي (CTR متماثل).
      expect(_hex(SecureData.aesCtrProcess(key, counter, out)), _hex(plain));
    });

    test('مفاتيح بأطوال غير صحيحة تُرفض', () {
      expect(
        () => SecureData.aesCtrProcess(Uint8List(15), Uint8List(16), Uint8List(4)),
        throwsArgumentError,
      );
      expect(
        () => SecureData.aesCtrProcess(Uint8List(16), Uint8List(12), Uint8List(4)),
        throwsArgumentError,
      );
    });
  });

  group('النسخة الاحتياطية المشفّرة', () {
    const String payload = '{"v":1,"tasks":[{"id":"t1","t":"قراءة"}]}';

    test('تشفير ثم فك التشفير يعيد نفس المحتوى', () {
      final String file = SecureData.encryptBackup(
        plainJson: payload,
        password: 'كلمة سر قوية 123',
        iterations: 1000,
      );
      expect(SecureData.looksEncrypted(file), isTrue);
      expect(file.contains('قراءة'), isFalse, reason: 'المحتوى يجب ألا يظهر في الملف');

      final String back = SecureData.decryptBackup(fileText: file, password: 'كلمة سر قوية 123');
      expect(back, payload);
    });

    test('نفس النص يعطي ملفات مختلفة (ملح وعشوائي جديدان)', () {
      final String a = SecureData.encryptBackup(plainJson: payload, password: 'p', iterations: 500);
      final String b = SecureData.encryptBackup(plainJson: payload, password: 'p', iterations: 500);
      expect(a == b, isFalse);
      expect(SecureData.decryptBackup(fileText: a, password: 'p'), payload);
      expect(SecureData.decryptBackup(fileText: b, password: 'p'), payload);
    });

    test('كلمة سر خاطئة تُرفض', () {
      final String file = SecureData.encryptBackup(plainJson: payload, password: 'صحيح', iterations: 500);
      expect(
        () => SecureData.decryptBackup(fileText: file, password: 'خطأ'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('تعديل المحتوى المشفّر يُكتشف', () {
      final String file = SecureData.encryptBackup(plainJson: payload, password: 'p', iterations: 500);
      final Map<String, dynamic> map = Map<String, dynamic>.from(jsonDecode(file) as Map);
      final Uint8List bytes = SecureData.unb64(map['payload'] as String);
      bytes[0] = bytes[0] ^ 0x01;
      map['payload'] = SecureData.b64(bytes);
      expect(
        () => SecureData.decryptBackup(fileText: jsonEncode(map), password: 'p'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('تعديل ترويسة الملف (عدد التكرارات/التاريخ) يُكتشف', () {
      final String file = SecureData.encryptBackup(plainJson: payload, password: 'p', iterations: 500);
      final Map<String, dynamic> a = Map<String, dynamic>.from(jsonDecode(file) as Map);
      a['iter'] = 400;
      expect(
        () => SecureData.decryptBackup(fileText: jsonEncode(a), password: 'p'),
        throwsA(isA<WrongPasswordException>()),
      );

      final Map<String, dynamic> b = Map<String, dynamic>.from(jsonDecode(file) as Map);
      b['created'] = DateTime(2000).toIso8601String();
      expect(
        () => SecureData.decryptBackup(fileText: jsonEncode(b), password: 'p'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('ملفات غير صالحة تُرفض برسالة واضحة', () {
      expect(
        () => SecureData.decryptBackup(fileText: 'ليس ملفًا', password: 'p'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => SecureData.decryptBackup(fileText: '{"format":"other","v":1}', password: 'p'),
        throwsA(isA<BackupFormatException>()),
      );
      final Map<String, dynamic> future =
          Map<String, dynamic>.from(jsonDecode(SecureData.encryptBackup(plainJson: payload, password: 'p', iterations: 200)) as Map);
      future['v'] = 99;
      expect(
        () => SecureData.decryptBackup(fileText: jsonEncode(future), password: 'p'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('كلمة سر فارغة لا تُشفّر', () {
      expect(
        () => SecureData.encryptBackup(plainJson: payload, password: ''),
        throwsA(isA<SecureDataException>()),
      );
    });

    test('بيانات بحجم واقعي (٦٤ كيلوبايت)', () {
      final String big = jsonEncode(<String, dynamic>{
        'tasks': List<Map<String, String>>.generate(
          800,
          (int i) => <String, String>{'id': 't$i', 'title': 'مهمة رقم $i', 'notes': 'ملاحظات $i'},
        ),
      });
      expect(big.length, greaterThan(40000));
      final String file = SecureData.encryptBackup(plainJson: big, password: 'p', iterations: 500);
      expect(SecureData.decryptBackup(fileText: file, password: 'p'), big);
    });

    test('peek يعرض معلومات الملف بدون كلمة سر', () {
      final String file = SecureData.encryptBackup(plainJson: payload, password: 'p', iterations: 1234);
      final Map<String, dynamic>? info = SecureData.peek(file);
      expect(info, isNotNull);
      expect(info!['iter'], 1234);
      expect(info['format'], SecureData.formatId);
      expect(SecureData.peek('{}'), isNull);
    });
  });

  group('بصمة كلمة سر القفل', () {
    test('التحقق ينجح مع كلمة السر الصحيحة ويفشل مع غيرها', () {
      final String stored = SecureData.hashPassword('سر123', iterations: 800);
      expect(stored.startsWith('pbkdf2-sha256\$800\$'), isTrue);
      expect(stored.contains('سر123'), isFalse, reason: 'كلمة السر لا تُخزَّن كنص');
      expect(SecureData.verifyPassword('سر123', stored), isTrue);
      expect(SecureData.verifyPassword('سر124', stored), isFalse);
      expect(SecureData.verifyPassword('', stored), isFalse);
    });

    test('نفس كلمة السر تعطي بصمتين مختلفتين (ملح عشوائي)', () {
      final String a = SecureData.hashPassword('same', iterations: 500);
      final String b = SecureData.hashPassword('same', iterations: 500);
      expect(a == b, isFalse);
      expect(SecureData.verifyPassword('same', a), isTrue);
      expect(SecureData.verifyPassword('same', b), isTrue);
    });

    test('بصمة تالفة تُرفض بأمان', () {
      expect(SecureData.verifyPassword('x', ''), isFalse);
      expect(SecureData.verifyPassword('x', 'pbkdf2-sha256\$abc\$aa\$bb'), isFalse);
      expect(SecureData.verifyPassword('x', 'md5\$1\$aa\$bb'), isFalse);
      expect(SecureData.verifyPassword('x', 'pbkdf2-sha256\$500\$غيرصالح\$غيرصالح'), isFalse);
    });
  });

  test('المقارنة ثابتة الزمن', () {
    expect(SecureData.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 3]), isTrue);
    expect(SecureData.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 4]), isFalse);
    expect(SecureData.constantTimeEquals(<int>[1, 2], <int>[1, 2, 3]), isFalse);
  });

  test('عشوائية الملح لا تتكرر', () {
    final Set<String> salts = <String>{
      for (int i = 0; i < 25; i++) SecureData.b64(SecureData.randomBytes(16)),
    };
    expect(salts.length, 25);
  });
}
