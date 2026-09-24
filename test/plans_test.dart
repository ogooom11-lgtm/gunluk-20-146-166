import 'package:flutter_test/flutter_test.dart';
import 'package:gunluk/core/enums.dart';
import 'package:gunluk/core/models/plan.dart';
import 'package:gunluk/core/models/subtask.dart';
import 'package:gunluk/core/models/task.dart';

Plan _weekly() => Plan(
      id: 'p1',
      title: 'قراءة كتاب',
      startDate: DateTime(2026, 1, 1),
      repeatType: RepeatType.weekly,
      weekdays: <int>{DateTime.tuesday},
      startMinutes: 20 * 60,
      durationMinutes: 30,
    );

void main() {
  group('تكرار الخطة', () {
    test('أسبوعي: الثلاثاء فقط', () {
      final Plan plan = _weekly();
      expect(plan.occursOn(DateTime(2026, 1, 6)), isTrue);
      expect(plan.occursOn(DateTime(2026, 1, 7)), isFalse);
      expect(plan.occursOn(DateTime(2025, 12, 30)), isFalse, reason: 'قبل تاريخ البداية');

      final List<DateTime> days = plan.occurrences(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      expect(days.length, 4);
      expect(days.first, DateTime(2026, 1, 6));
      expect(days.last, DateTime(2026, 1, 27));
    });

    test('تخطّي يوم لا يُنشئ نسخة', () {
      final Plan plan = _weekly();
      plan.skippedDates.add('2026-01-13');
      expect(plan.occursOn(DateTime(2026, 1, 13)), isFalse);
      expect(plan.occurrences(DateTime(2026, 1, 1), DateTime(2026, 1, 31)).length, 3);
    });

    test('كل ن أيام', () {
      final Plan plan = Plan(
        id: 'p2',
        title: 'رياضة',
        startDate: DateTime(2026, 1, 1),
        repeatType: RepeatType.interval,
        intervalDays: 3,
      );
      expect(plan.occursOn(DateTime(2026, 1, 4)), isTrue);
      expect(plan.occursOn(DateTime(2026, 1, 5)), isFalse);
      expect(plan.occursOn(DateTime(2026, 1, 7)), isTrue);
    });

    test('شهري: يوم ٣١ في شهر قصير يصبح آخر يوم', () {
      final Plan plan = Plan(
        id: 'p3',
        title: 'تقرير شهري',
        startDate: DateTime(2026, 1, 1),
        repeatType: RepeatType.monthly,
        dayOfMonth: 31,
      );
      expect(plan.occursOn(DateTime(2026, 2, 28)), isTrue);
      expect(plan.occursOn(DateTime(2026, 2, 27)), isFalse);
      expect(plan.occursOn(DateTime(2026, 3, 31)), isTrue);
    });

    test('يومي مع تاريخ نهاية', () {
      final Plan plan = Plan(
        id: 'p4',
        title: 'ورد يومي',
        startDate: DateTime(2026, 1, 1),
        repeatType: RepeatType.daily,
        endDate: DateTime(2026, 1, 5),
      );
      expect(plan.occursOn(DateTime(2026, 1, 5)), isTrue);
      expect(plan.occursOn(DateTime(2026, 1, 6)), isFalse);
      expect(plan.totalSpanDays(until: DateTime(2026, 1, 10)), 5);
    });

    test('الموعد القادم وحالة الخطة', () {
      final Plan plan = _weekly();
      expect(plan.nextOccurrence(DateTime(2026, 1, 7)), DateTime(2026, 1, 13));
      expect(plan.nextOccurrence(DateTime(2026, 1, 6)), DateTime(2026, 1, 6));
      expect(plan.statusAt(DateTime(2025, 12, 31)), PlanStatus.notStarted);
      expect(plan.statusAt(DateTime(2026, 1, 3)), PlanStatus.active);
      expect(plan.copyWith(paused: true).statusAt(DateTime(2026, 1, 3)), PlanStatus.paused);
      expect(plan.copyWith(endDate: DateTime(2026, 2, 1)).statusAt(DateTime(2026, 3, 1)),
          PlanStatus.finished);
    });

    test('نسخة اليوم من الخطة لها معرّف ثابت ومرتبط بالخطة', () {
      final Plan plan = _weekly();
      final Task occurrence = plan.occurrenceTask(DateTime(2026, 1, 6, 15, 30));
      expect(occurrence.id, 'po_p1_2026-01-06');
      expect(occurrence.planId, 'p1');
      expect(occurrence.fromPlan, isTrue);
      expect(occurrence.date, DateTime(2026, 1, 6));
      expect(occurrence.startMinutes, 20 * 60);
      expect(occurrence.title, plan.title);
      expect(occurrence.done, isFalse);
    });

    test('قوالب الخطوات تُنسخ مع كل نسخة', () {
      final Plan plan = _weekly();
      plan.subtaskTemplates.add(Subtask.create('قراءة ١٠ صفحات'));
      final Task occurrence = plan.occurrenceTask(DateTime(2026, 1, 13));
      expect(occurrence.subtasks.length, 1);
      expect(occurrence.subtasks.first.title, 'قراءة ١٠ صفحات');
      expect(occurrence.subtasks.first.done, isFalse);
    });
  });
}
