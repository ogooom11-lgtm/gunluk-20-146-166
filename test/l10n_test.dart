import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/l10n/app_strings.dart';

final RegExp _placeholder = RegExp(r'\{([a-zA-Z0-9_]+)\}');

Set<String> _args(String value) =>
    _placeholder.allMatches(value).map((RegExpMatch m) => m.group(1)!).toSet();

void main() {
  group('نصوص التطبيق', () {
    test('لكل مفتاح ترجمة في اللغتين', () {
      final Set<String> onlyAr = L.ar.keys.toSet().difference(L.en.keys.toSet());
      final Set<String> onlyEn = L.en.keys.toSet().difference(L.ar.keys.toSet());
      expect(onlyAr, isEmpty, reason: 'مفاتيح ناقصة في الإنجليزية');
      expect(onlyEn, isEmpty, reason: 'مفاتيح ناقصة في العربية');
      expect(L.ar.length, greaterThan(300));
    });

    test('لا نصوص فارغة', () {
      for (final MapEntry<String, String> entry in L.ar.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: 'نص فارغ: ${entry.key}');
      }
      for (final MapEntry<String, String> entry in L.en.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: 'empty value: ${entry.key}');
      }
    });

    test('نفس القيم المتغيّرة في اللغتين', () {
      for (final MapEntry<String, String> entry in L.ar.entries) {
        final Set<String> ar = _args(entry.value);
        final Set<String> en = _args(L.en[entry.key] ?? '');
        expect(ar, en, reason: 'اختلاف القيم المتغيّرة في: ${entry.key}');
      }
    });

    test('تعويض القيم يعمل، والمفتاح المجهول يعود كما هو', () {
      const AppLocalizations ar = AppLocalizations(Locale('ar'));
      const AppLocalizations en = AppLocalizations(Locale('en'));
      expect(ar.t('app.name'), 'إنجازي');
      expect(ar.t('home.level', <String, String>{'n': '٣'}), 'المستوى ٣');
      expect(en.t('home.level', <String, String>{'n': '3'}), 'Level 3');
      expect(ar.t('key.that.does.not.exist'), 'key.that.does.not.exist');
      expect(ar.isArabic, isTrue);
      expect(en.isArabic, isFalse);
      expect(ar.lang, 'ar');
      expect(en.lang, 'en');
    });

    test('النصوص المطلوبة موجودة (التذكير الليلي وأيام الدوام والخطط)', () {
      for (final String key in <String>[
        'notif.evening',
        'notif.eveningTime',
        'notif.summaryBody',
        'notif.summaryAllDone',
        'notif.actionDone',
        'notif.actionSnooze',
        'plan.workDays',
        'plan.daysCount',
        'plan.weekdaysNote',
        'plan.endDateHint',
        'sound.calm',
        'sound.chime',
        'sound.bell',
        'sound.soft',
      ]) {
        expect(L.ar[key], isNotNull, reason: 'مفقود: $key');
        expect(L.en[key], isNotNull, reason: 'missing: $key');
      }
    });
  });
}
