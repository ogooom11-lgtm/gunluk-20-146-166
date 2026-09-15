import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/models/day_event.dart';
import 'package:gunluk/core/utils/dates.dart';
import 'package:gunluk/core/utils/secure_data.dart';
import 'package:gunluk/data/app_state.dart';
import 'package:gunluk/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حالة تطبيق نظيفة تمامًا (بلا ملفات محفوظة) للاختبارات.
AppState _freshState() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppState(useIsolates: false);
}

void main() {
  group('الأحداث اليومية', () {
    test('إضافة حدث وحفظه للأبد', () async {
      final AppState app = _freshState();
      await app.init();

      final DateTime today = Dates.today();
      await app.upsertEvent(DayEvent(id: '', title: 'اجتماع الفريق', day: today, minutes: 10 * 60));
      await app.upsertEvent(DayEvent(id: '', title: 'زيارة عائلية', day: today));
      await app.upsertEvent(DayEvent(id: '', title: 'ذكرى التخرج', day: Dates.addDays(today, -400)));

      expect(app.events.length, 3);
      expect(app.eventCountOn(today), 2);
      // أحداث اليوم مرتّبة: الموقوتة أولًا.
      final List<DayEvent> todays = app.eventsOn(today);
      expect(todays.first.title, 'اجتماع الفريق');
      expect(todays.first.hasTime, isTrue);

      // حدث قديم جدًا لا يُحذف (خلاف المهام المجدولة).
      expect(app.events.any((DayEvent e) => e.title == 'ذكرى التخرج'), isTrue);

      // الترتيب العام: الأحدث يومًا أولًا.
      expect(app.eventsSorted.first.day, today);
    });

    test('التمييز والبحث والحذف', () async {
      final AppState app = _freshState();
      await app.init();
      final DateTime today = Dates.today();
      await app.upsertEvent(DayEvent(id: '', title: 'مباراة كرة', day: today, place: 'الملعب'));
      await app.upsertEvent(DayEvent(id: '', title: 'قراءة كتاب', day: today, notes: 'الفصل الثالث'));

      expect(app.searchEvents('كرة').length, 1);
      expect(app.searchEvents('الملعب').length, 1);
      expect(app.searchEvents('الفصل').length, 1);
      expect(app.searchEvents('لا يوجد').isEmpty, isTrue);

      final DayEvent first = app.events.first;
      await app.toggleEventStar(first.id);
      expect(app.starredEvents.length, 1);
      expect(app.starredEvents.first.id, first.id);

      await app.deleteEvent(first.id);
      expect(app.events.length, 1);
      expect(app.starredEvents.isEmpty, isTrue);
    });

    test('الأحداث القادمة والسابقة', () async {
      final AppState app = _freshState();
      await app.init();
      final DateTime today = Dates.today();
      await app.upsertEvent(DayEvent(id: '', title: 'غدًا', day: Dates.addDays(today, 1)));
      await app.upsertEvent(DayEvent(id: '', title: 'اليوم', day: today));
      await app.upsertEvent(DayEvent(id: '', title: 'أمس', day: Dates.addDays(today, -1)));

      expect(app.upcomingEvents().map((DayEvent e) => e.title), <String>['غدًا', 'اليوم']);
      expect(app.pastEvents().map((DayEvent e) => e.title), <String>['أمس']);
      expect(app.eventCountInMonth(today), 3);
    });

    test('الأحداث تُحفظ في التخزين وتعود بعد إعادة التشغيل', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppState first = AppState(useIsolates: false);
      await first.init();
      await first.upsertEvent(DayEvent(
        id: '',
        title: 'رحلة',
        day: Dates.addDays(Dates.today(), -30),
        minutes: 8 * 60,
        place: 'الجبال',
        notes: 'كان يومًا جميلًا',
        starred: true,
      ));
      await first.flush();

      // حالة جديدة تقرأ نفس التخزين.
      final AppState second = AppState(useIsolates: false);
      await second.init();
      expect(second.events.length, 1);
      final DayEvent loaded = second.events.first;
      expect(loaded.title, 'رحلة');
      expect(loaded.place, 'الجبال');
      expect(loaded.notes, 'كان يومًا جميلًا');
      expect(loaded.minutes, 8 * 60);
      expect(loaded.starred, isTrue);
      expect(loaded.dayKey, Dates.key(Dates.addDays(Dates.today(), -30)));
    });

    test('الأحداث تدخل في النسخة الاحتياطية وتُستعاد منها', () async {
      final AppState app = _freshState();
      await app.init();
      await app.upsertEvent(DayEvent(id: '', title: 'مؤتمر', day: Dates.today()));

      final Map<String, dynamic> data = app.exportData();
      expect(data['events'], isNotNull);
      expect((data['events'] as List<dynamic>).length, 1);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppState restored = AppState(useIsolates: false);
      await restored.init();
      expect(restored.events.isEmpty, isTrue);
      final bool ok = await restored.importJson(app.exportJson());
      expect(ok, isTrue);
      expect(restored.events.length, 1);
      expect(restored.events.first.title, 'مؤتمر');
    });
  });

  group('قفل التطبيق بكلمة السر', () {
    test('التفعيل والفتح والإلغاء', () async {
      final AppState app = _freshState();
      await app.init();
      expect(app.lockEnabled, isFalse);
      expect(app.locked, isFalse);

      await app.setLockPassword('سري1234');
      expect(app.lockEnabled, isTrue);
      expect(app.locked, isFalse, reason: 'لا يُقفل فورًا بعد التعيين');
      expect(app.settings.lockHash.contains('سري1234'), isFalse, reason: 'لا تُخزَّن كلمة السر');

      app.lockNow();
      expect(app.locked, isTrue);

      expect(await app.unlock('خطأ'), isFalse);
      expect(app.locked, isTrue);
      expect(await app.unlock('سري1234'), isTrue);
      expect(app.locked, isFalse);

      await app.removeLock();
      expect(app.lockEnabled, isFalse);
      expect(app.settings.lockHash, isEmpty);
    });

    test('القفل يُستعاد عند بدء التطبيق', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppState app = AppState(useIsolates: false);
      await app.init();
      await app.setLockPassword('123456');
      await app.flush();

      final AppState restarted = AppState(useIsolates: false);
      await restarted.init();
      expect(restarted.lockEnabled, isTrue);
      expect(restarted.locked, isTrue, reason: 'يبدأ مقفلًا بعد إعادة التشغيل');
      expect(await restarted.unlock('123456'), isTrue);
    });

    test('مهلة السماح عند مغادرة التطبيق', () async {
      final AppState app = _freshState();
      await app.init();
      await app.setLockPassword('1234');

      // مهلة ٦٠ ثانية: الخروج والعودة السريعة لا تقفل.
      await app.updateSettings(app.settings.copyWith(lockGraceSeconds: 60));
      app.handleBackgrounded();
      expect(app.locked, isFalse);
      app.handleResumed();
      expect(app.locked, isFalse);

      // بلا مهلة: القفل فوري عند المغادرة.
      await app.updateSettings(app.settings.copyWith(lockGraceSeconds: 0));
      app.handleBackgrounded();
      expect(app.locked, isTrue);

      // تعطيل القفل عند المغادرة لا يقفل التطبيق أبدًا.
      await app.unlock('1234');
      await app.updateSettings(app.settings.copyWith(
        lockWhenBackground: false,
        lockGraceSeconds: 0,
      ));
      app.handleBackgrounded();
      app.handleResumed();
      expect(app.locked, isFalse);
    });
  });

  group('النسخة الاحتياطية المشفّرة عبر حالة التطبيق', () {
    test('تصدير مشفّر ثم استيراده بكلمة السر', () async {
      final AppState app = _freshState();
      await app.init();
      await app.upsertEvent(DayEvent(id: '', title: 'حدث سرّي', day: Dates.today()));
      await app.flush();

      final String? file = await app.exportEncryptedJson('كلمة السر', iterations: 600);
      expect(file, isNotNull);
      expect(SecureData.looksEncrypted(file!), isTrue);
      expect(file.contains('حدث سرّي'), isFalse);

      // حالة جديدة (فارغة) تستورد الملف.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppState fresh = AppState(useIsolates: false);
      await fresh.init();
      expect(fresh.events.isEmpty, isTrue);

      expect(await fresh.importAny(file, password: 'خطأ'), ImportStatus.wrongPassword);
      expect(fresh.events.isEmpty, isTrue, reason: 'لا تغيير بعد فشل الفك');

      expect(await fresh.importAny(file, password: 'كلمة السر'), ImportStatus.ok);
      expect(fresh.events.length, 1);
      expect(fresh.events.first.title, 'حدث سرّي');
    });

    test('ملف مشفّر بلا كلمة سر يُرفض بطلب كلمة السر', () async {
      final AppState app = _freshState();
      await app.init();
      final String? file = await app.exportEncryptedJson('pw123456', iterations: 600);
      expect(await app.importAny(file!), ImportStatus.wrongPassword);
    });

    test('نص عادي يُستورد كنسخة غير مشفّرة', () async {
      final AppState app = _freshState();
      await app.init();
      expect(await app.importAny(app.exportJson()), ImportStatus.ok);
      expect(await app.importAny('ليس JSON'), ImportStatus.notBackup);
      expect(await app.importAny(jsonEncode(<String, dynamic>{'hello': 'world'})), ImportStatus.notBackup);
      expect(await app.importAny(''), ImportStatus.notBackup);
    });

    test('ملف مُعدَّل يُرفض', () async {
      final AppState app = _freshState();
      await app.init();
      final String? file = await app.exportEncryptedJson('pw123456', iterations: 600);
      final Map<String, dynamic> map = Map<String, dynamic>.from(jsonDecode(file!) as Map);
      map['iter'] = 100;
      expect(
        await app.importAny(jsonEncode(map), password: 'pw123456'),
        ImportStatus.wrongPassword,
      );
    });
  });
}
