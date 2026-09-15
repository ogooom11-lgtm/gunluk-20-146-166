import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// خطأ عام في التشفير/فك التشفير.
class SecureDataException implements Exception {
  const SecureDataException(this.messageKey);

  /// مفتاح رسالة يترجم في الواجهة.
  final String messageKey;

  @override
  String toString() => 'SecureDataException($messageKey)';
}

/// كلمة سر خاطئة أو ملف مُعدَّل (فشل التحقق من البصمة).
class WrongPasswordException extends SecureDataException {
  const WrongPasswordException() : super('secure.wrongPassword');
}

/// ملف نسخة احتياطية غير صالح أو غير مدعوم.
class BackupFormatException extends SecureDataException {
  const BackupFormatException([super.messageKey = 'secure.badFile']);
}

/// أدوات التشفير المحلية: PBKDF2-HMAC-SHA256 لاشتقاق المفاتيح،
/// و AES-256-CTR للتشفير، و HMAC-SHA256 للتحقق من السلامة (Encrypt-then-MAC).
///
/// كل شيء يعمل على الجهاز بلا إنترنت ولا مكتبات أصلية.
class SecureData {
  SecureData._();

  static const String formatId = 'injaz.encrypted-backup';
  static const int formatVersion = 1;
  static const String kdfId = 'pbkdf2-hmac-sha256';
  static const String cipherId = 'aes-256-ctr-hmac-sha256';

  /// عدد تكرارات الاشتقاق للنسخ الاحتياطية (يُخفّض في الاختبارات فقط).
  static const int defaultIterations = 60000;

  /// عدد تكرارات بصمة كلمة سر قفل التطبيق.
  static const int passwordIterations = 80000;

  static final Random _random = Random.secure();

  static Uint8List randomBytes(int length) {
    final Uint8List out = Uint8List(length);
    for (int i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  static String b64(List<int> bytes) => base64.encode(bytes);

  static Uint8List unb64(String value) {
    try {
      return base64.decode(value.trim());
    } catch (_) {
      throw const BackupFormatException();
    }
  }

  // ===== PBKDF2-HMAC-SHA256 =====

  /// اشتقاق مفتاح من كلمة السر (RFC 8018).
  static Uint8List pbkdf2(
    Uint8List password,
    Uint8List salt,
    int iterations, [
    int length = 32,
  ]) {
    if (iterations < 1) {
      throw const BackupFormatException();
    }
    final Hmac hmac = Hmac(sha256, password);
    const int hLen = 32;
    final int blocks = (length + hLen - 1) ~/ hLen;
    final Uint8List out = Uint8List(blocks * hLen);
    for (int block = 1; block <= blocks; block++) {
      final Uint8List seed = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (block >> 24) & 0xff
        ..[salt.length + 1] = (block >> 16) & 0xff
        ..[salt.length + 2] = (block >> 8) & 0xff
        ..[salt.length + 3] = block & 0xff;
      Uint8List u = Uint8List.fromList(hmac.convert(seed).bytes);
      final Uint8List acc = Uint8List.fromList(u);
      for (int i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int k = 0; k < hLen; k++) {
          acc[k] ^= u[k];
        }
      }
      out.setRange((block - 1) * hLen, block * hLen, acc);
    }
    return Uint8List.sublistView(out, 0, length);
  }

  /// مقارنة ثابتة الزمن (تمنع هجمات التوقيت).
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  // ===== بصمة كلمة سر قفل التطبيق =====

  /// تُنتج نصًا بصيغة `pbkdf2-sha256$iterations$salt$hash`.
  static String hashPassword(String password, {int iterations = passwordIterations}) {
    final Uint8List salt = randomBytes(16);
    final Uint8List hash = pbkdf2(_utf8(password), salt, iterations, 32);
    return 'pbkdf2-sha256\$$iterations\$${b64(salt)}\$${b64(hash)}';
  }

  static bool verifyPassword(String password, String stored) {
    final List<String> parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') return false;
    final int? iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } catch (_) {
      return false;
    }
    final Uint8List actual = pbkdf2(_utf8(password), salt, iterations, expected.length);
    return constantTimeEquals(actual, expected);
  }

  // ===== النسخة الاحتياطية المشفرة =====

  /// يشفّر نص JSON ويعيد محتوى الملف (JSON مقروء) الجاهز للحفظ.
  static String encryptBackup({
    required String plainJson,
    required String password,
    int iterations = defaultIterations,
    DateTime? createdAt,
    Uint8List? salt,
    Uint8List? iv,
  }) {
    if (password.isEmpty) {
      throw const SecureDataException('secure.emptyPassword');
    }
    final Uint8List saltBytes = salt ?? randomBytes(16);
    final Uint8List ivBytes = iv ?? randomBytes(12);
    final DateTime created = createdAt ?? DateTime.now();
    final String createdIso = created.toIso8601String();

    final Uint8List keys = pbkdf2(_utf8(password), saltBytes, iterations, 64);
    final Uint8List encKey = Uint8List.sublistView(keys, 0, 32);
    final Uint8List macKey = Uint8List.sublistView(keys, 32, 64);

    final Uint8List plain = _utf8(plainJson);
    final Uint8List cipherText = aesCtrProcess(encKey, _counterBlock(ivBytes), plain);

    final String header = _headerString(
      iterations: iterations,
      saltB64: b64(saltBytes),
      ivB64: b64(ivBytes),
      createdIso: createdIso,
    );
    final Digest mac = Hmac(sha256, macKey).convert(<int>[..._utf8(header), 0, ...cipherText]);

    final Map<String, dynamic> envelope = <String, dynamic>{
      'app': 'injazi',
      'format': formatId,
      'v': formatVersion,
      'created': createdIso,
      'kdf': kdfId,
      'iter': iterations,
      'salt': b64(saltBytes),
      'cipher': cipherId,
      'iv': b64(ivBytes),
      'mac': b64(mac.bytes),
      'payload': b64(cipherText),
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// يفك تشفير محتوى ملف نسخة احتياطية ويعيد نص JSON الأصلي.
  static String decryptBackup({required String fileText, required String password}) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(fileText.trim());
    } catch (_) {
      throw const BackupFormatException('secure.notBackup');
    }
    if (decoded is! Map) throw const BackupFormatException('secure.notBackup');
    final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
    if (map['format'] != formatId) throw const BackupFormatException('secure.notBackup');
    final int version = (map['v'] as num?)?.toInt() ?? 0;
    if (version != formatVersion) throw const BackupFormatException('secure.unsupportedVersion');
    if (map['kdf'] != kdfId || map['cipher'] != cipherId) {
      throw const BackupFormatException('secure.unsupportedCipher');
    }
    final int iterations = (map['iter'] as num?)?.toInt() ?? 0;
    if (iterations < 1) throw const BackupFormatException();
    final String createdIso = (map['created'] ?? '').toString();
    final Uint8List salt = unb64((map['salt'] ?? '').toString());
    final Uint8List iv = unb64((map['iv'] ?? '').toString());
    final Uint8List tag = unb64((map['mac'] ?? '').toString());
    final Uint8List cipherText = unb64((map['payload'] ?? '').toString());
    if (salt.length != 16 || iv.length != 12 || tag.length != 32) {
      throw const BackupFormatException();
    }

    final Uint8List keys = pbkdf2(_utf8(password), salt, iterations, 64);
    final Uint8List macKey = Uint8List.sublistView(keys, 32, 64);
    final String header = _headerString(
      iterations: iterations,
      saltB64: b64(salt),
      ivB64: b64(iv),
      createdIso: createdIso,
    );
    final Digest expected = Hmac(sha256, macKey).convert(<int>[..._utf8(header), 0, ...cipherText]);
    if (!constantTimeEquals(expected.bytes, tag)) {
      throw const WrongPasswordException();
    }

    final Uint8List encKey = Uint8List.sublistView(keys, 0, 32);
    final Uint8List plain = aesCtrProcess(encKey, _counterBlock(iv), cipherText);
    try {
      return _utf8decode(plain);
    } catch (_) {
      throw const BackupFormatException();
    }
  }

  /// هل النص يبدو نسخة احتياطية مشفّرة من هذا التطبيق؟
  static bool looksEncrypted(String text) {
    try {
      final dynamic decoded = jsonDecode(text.trim());
      if (decoded is! Map) return false;
      return decoded['format'] == formatId;
    } catch (_) {
      return false;
    }
  }

  /// معلومات مختصرة عن ملف مشفر (بدون كلمة سر) للعرض في الواجهة.
  static Map<String, dynamic>? peek(String text) {
    try {
      final dynamic decoded = jsonDecode(text.trim());
      if (decoded is! Map) return null;
      if (decoded['format'] != formatId) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static String _headerString({
    required int iterations,
    required String saltB64,
    required String ivB64,
    required String createdIso,
  }) =>
      <String>[
        formatId,
        '$formatVersion',
        kdfId,
        '$iterations',
        saltB64,
        cipherId,
        ivB64,
        createdIso,
      ].join('\n');

  static Uint8List _counterBlock(Uint8List iv) {
    final Uint8List block = Uint8List(16);
    block.setRange(0, 12, iv);
    return block; // العدّاد يبدأ من الصفر في آخر ٤ بايتات.
  }

  static Uint8List _utf8(String value) => Uint8List.fromList(utf8.encode(value));

  static String _utf8decode(Uint8List bytes) => utf8.decode(bytes);

  // ===== AES-256-CTR (تنفيذ FIPS-197 كامل) =====

  /// تشفير/فك تشفير بنمط CTR — نفس العملية للاتجاهين.
  ///
  /// [initialCounter] كتلة عدّاد من ١٦ بايت، ويُزاد كعدد صحيح ١٢٨ بت
  /// بترتيب البايتات الكبير (مطابق لـ NIST SP 800-38A).
  static Uint8List aesCtrProcess(
    Uint8List key,
    Uint8List initialCounter,
    Uint8List data,
  ) {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw ArgumentError('AES key must be 16, 24 or 32 bytes');
    }
    if (initialCounter.length != 16) {
      throw ArgumentError('Counter block must be 16 bytes');
    }
    final _Aes aes = _Aes(key);
    final Uint8List out = Uint8List(data.length);
    final Uint8List counter = Uint8List.fromList(initialCounter);
    final Uint8List stream = Uint8List(16);
    int offset = 0;
    while (offset < data.length) {
      aes.encryptBlock(counter, stream);
      final int end = min(16, data.length - offset);
      for (int i = 0; i < end; i++) {
        out[offset + i] = data[offset + i] ^ stream[i];
      }
      offset += end;
      _incrementCounter(counter);
    }
    return out;
  }

  static void _incrementCounter(Uint8List counter) {
    for (int i = 15; i >= 0; i--) {
      counter[i] = (counter[i] + 1) & 0xff;
      if (counter[i] != 0) break;
    }
  }
}

/// تنفيذ مبسّط لخوارزمية AES (Rijndael) بنسخة 128/192/256 بت.
class _Aes {
  _Aes(List<int> key) : _rounds = _roundsFor(key.length), _w = _expandKey(key) {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw ArgumentError('Invalid AES key length');
    }
  }

  final int _rounds;

  /// جدول المفاتيح الموسّع (كلمات ٣٢ بت).
  final Uint32List _w;

  static int _roundsFor(int keyLength) {
    switch (keyLength) {
      case 16:
        return 10;
      case 24:
        return 12;
      case 32:
        return 14;
      default:
        throw ArgumentError('Invalid AES key length');
    }
  }

  static Uint32List _expandKey(List<int> key) {
    final int nk = key.length ~/ 4;
    final int nr = _roundsFor(key.length);
    final int words = 4 * (nr + 1);
    final Uint32List w = Uint32List(words);
    for (int i = 0; i < nk; i++) {
      w[i] = (key[4 * i] << 24) | (key[4 * i + 1] << 16) | (key[4 * i + 2] << 8) | key[4 * i + 3];
    }
    int rcon = 1;
    for (int i = nk; i < words; i++) {
      int temp = w[i - 1];
      if (i % nk == 0) {
        temp = _subWord(_rotWord(temp)) ^ (rcon << 24);
        rcon = _xtime(rcon);
      } else if (nk > 6 && i % nk == 4) {
        temp = _subWord(temp);
      }
      w[i] = w[i - nk] ^ temp;
    }
    return w;
  }

  static int _rotWord(int word) => ((word << 8) | (word >>> 24)) & 0xffffffff;

  static int _subWord(int word) {
    return (_sbox[(word >>> 24) & 0xff] << 24) |
        (_sbox[(word >>> 16) & 0xff] << 16) |
        (_sbox[(word >>> 8) & 0xff] << 8) |
        _sbox[word & 0xff];
  }

  /// ضرب في 2 داخل الحقل GF(2^8).
  static int _xtime(int value) {
    final int v = (value << 1) & 0xff;
    return (value & 0x80) != 0 ? v ^ 0x1b : v;
  }

  /// تشفير كتلة واحدة (16 بايت) من [input] إلى [output].
  void encryptBlock(List<int> input, Uint8List output) {
    final Uint8List s = Uint8List.fromList(input.sublist(0, 16));
    _addRoundKey(s, 0);
    for (int round = 1; round < _rounds; round++) {
      _subBytes(s);
      _shiftRows(s);
      _mixColumns(s);
      _addRoundKey(s, round);
    }
    _subBytes(s);
    _shiftRows(s);
    _addRoundKey(s, _rounds);
    output.setRange(0, 16, s);
  }

  void _addRoundKey(Uint8List state, int round) {
    for (int c = 0; c < 4; c++) {
      final int word = _w[round * 4 + c];
      state[4 * c] ^= (word >>> 24) & 0xff;
      state[4 * c + 1] ^= (word >>> 16) & 0xff;
      state[4 * c + 2] ^= (word >>> 8) & 0xff;
      state[4 * c + 3] ^= word & 0xff;
    }
  }

  static void _subBytes(Uint8List state) {
    for (int i = 0; i < 16; i++) {
      state[i] = _sbox[state[i]];
    }
  }

  static void _shiftRows(Uint8List state) {
    // الصف 1: إزاحة بايت واحدة، الصف 2: اثنتان، الصف 3: ثلاث.
    final int t1 = state[1];
    state[1] = state[5];
    state[5] = state[9];
    state[9] = state[13];
    state[13] = t1;

    final int t2 = state[2];
    final int t6 = state[6];
    state[2] = state[10];
    state[6] = state[14];
    state[10] = t2;
    state[14] = t6;

    final int t3 = state[15];
    state[15] = state[11];
    state[11] = state[7];
    state[7] = state[3];
    state[3] = t3;
  }

  static void _mixColumns(Uint8List s) {
    for (int c = 0; c < 4; c++) {
      final int i = 4 * c;
      final int a0 = s[i];
      final int a1 = s[i + 1];
      final int a2 = s[i + 2];
      final int a3 = s[i + 3];
      final int t = a0 ^ a1 ^ a2 ^ a3;
      s[i] = a0 ^ t ^ _xtime(a0 ^ a1);
      s[i + 1] = a1 ^ t ^ _xtime(a1 ^ a2);
      s[i + 2] = a2 ^ t ^ _xtime(a2 ^ a3);
      s[i + 3] = a3 ^ t ^ _xtime(a3 ^ a0);
    }
  }

  static const List<int> _sbox = <int>[
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
  ];
}
