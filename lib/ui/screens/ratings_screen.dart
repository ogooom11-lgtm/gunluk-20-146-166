import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/day_note.dart';
import '../../core/utils/dates.dart';
import '../../data/app_state.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/settings_tiles.dart';

/// صفحة «تقييمات الأيام»: كل يوم قيّمته + ملخص الشهر حسب التقييمات اليومية.
class RatingsScreen extends StatelessWidget {
  const RatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = context.app;
    final DateTime now = Dates.today();
    final List<DayNote> rated = app.ratedNotes();
    final double? monthAvg = app.averageRating(now.year, now.month);
    final int monthCount = app.ratedCountIn(now.year, now.month);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('rate.title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 28),
        children: <Widget>[
          // ===== ملخص الشهر الحالي =====
          _MonthSummary(
            title: context.tr('rate.thisMonth'),
            average: monthAvg,
            count: monthCount,
            daysInMonth: DateTime(now.year, now.month + 1, 0).day,
          ),
          const SizedBox(height: 16),

          // ===== آخر ١٤ يومًا =====
          SectionHeader(title: context.tr('rate.last14'), icon: Icons.insights_rounded),
          AppCard(
            child: _SparkBars(
              values: <int>[
                for (int i = 13; i >= 0; i--)
                  app.ratingFor(Dates.addDays(now, -i)),
              ],
              onTapDay: (int index) {
                final DateTime day = Dates.addDays(now, -(13 - index));
                showRatingSheet(context, day: day);
              },
            ),
          ),
          const SizedBox(height: 16),

          // ===== الأشهر السابقة =====
          SectionHeader(title: context.tr('rate.byMonth'), icon: Icons.calendar_month_rounded),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 1; i <= 6; i++)
                  Builder(
                    builder: (BuildContext context) {
                      final DateTime m = DateTime(now.year, now.month - i, 1);
                      final double? avg = app.averageRating(m.year, m.month);
                      final int count = app.ratedCountIn(m.year, m.month);
                      return Column(
                        children: <Widget>[
                          SettingsTile(
                            title: _monthName(context, m),
                            subtitle: context.tr('rate.ratedDays', <String, String>{
                              'n': context.numStr(count),
                            }),
                            icon: Icons.star_half_rounded,
                            trailing: Text(
                              avg == null ? '—' : '${avg.toStringAsFixed(1)} ★',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          if (i < 6)
                            Divider(
                              height: 1,
                              indent: 56,
                              endIndent: 12,
                              color: Theme.of(context).dividerColor,
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ===== كل الأيام المُقيَّمة =====
          SectionHeader(title: context.tr('rate.allDays'), icon: Icons.event_note_rounded),
          if (rated.isEmpty)
            EmptyState(
              icon: Icons.star_outline_rounded,
              title: context.tr('rate.emptyTitle'),
              message: context.tr('rate.emptyMessage'),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < rated.length; i++)
                    Column(
                      children: <Widget>[
                        _RatedDayTile(note: rated[i]),
                        if (i < rated.length - 1)
                          Divider(
                            height: 1,
                            indent: 56,
                            endIndent: 12,
                            color: Theme.of(context).dividerColor,
                          ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _monthName(BuildContext context, DateTime date) =>
      context.dateStr(date, withWeekday: false);
}

/// ملخص الشهر: المتوسط الكبير + شريط التوزيع + عدد الأيام.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.title,
    required this.average,
    required this.count,
    required this.daysInMonth,
  });

  final String title;
  final double? average;
  final int count;
  final int daysInMonth;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.calendar_month_rounded, size: 20, color: context.palette.seed),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                average == null ? '—' : average!.toStringAsFixed(1),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.palette.seed,
                    ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(context.tr('rate.outOfFive'), style: Theme.of(context).textTheme.labelMedium),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    context.tr('rate.ratedDays', <String, String>{'n': context.numStr(count)}),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    context.tr('rate.ofDays', <String, String>{'n': context.numStr(daysInMonth)}),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          StarRow(value: average == null ? -1 : (average!.round() - 1).clamp(0, 4), size: 26),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: daysInMonth == 0 ? 0 : (count / daysInMonth).clamp(0, 1),
              backgroundColor: context.palette.seed.withAlpha(40),
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط آخر ١٤ يومًا: كل عمود يوم، وارتفاعه حسب التقييم.
class _SparkBars extends StatelessWidget {
  const _SparkBars({required this.values, required this.onTapDay});

  final List<int> values;
  final ValueChanged<int> onTapDay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < values.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTapDay(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        values[i] < 0 ? '' : '${values[i] + 1}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: values[i] < 0 ? 8 : 12 + values[i] * 14,
                        decoration: BoxDecoration(
                          color: values[i] < 0
                              ? context.palette.seed.withAlpha(40)
                              : _colorFor(context, values[i]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _colorFor(BuildContext context, int value) {
    switch (value) {
      case 0:
        return const Color(0xFFE05B5B);
      case 1:
        return const Color(0xFFE08A2E);
      case 2:
        return const Color(0xFFE0C12E);
      case 3:
        return const Color(0xFF7AB55C);
      default:
        return const Color(0xFF2FA86A);
    }
  }
}

/// صفّ نجوم قابل للضغط (٠ = سيء … ٤ = ممتاز).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.value, this.onChanged, this.size = 30});

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 5; i++)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(),
            onPressed: onChanged == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged!(i);
                  },
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i <= value ? const Color(0xFFE0A02E) : Theme.of(context).disabledColor,
            ),
          ),
      ],
    );
  }
}

/// سطر يوم مُقيَّم: التاريخ + النجوم + مقتطف الملاحظة.
class _RatedDayTile extends StatelessWidget {
  const _RatedDayTile({required this.note});

  final DayNote note;

  @override
  Widget build(BuildContext context) {
    final DateTime? day = Dates.parseKey(note.day);
    return SettingsTile(
      title: day == null ? note.day : context.dateStr(day),
      subtitle: note.text.trim().isEmpty ? null : note.text.trim(),
      icon: Icons.star_rounded,
      iconColor: const Color(0xFFE0A02E),
      trailing: note.mood < 0
          ? Text(context.tr('rate.noRating'), style: Theme.of(context).textTheme.labelSmall)
          : Text('${note.mood + 1} ★', style: Theme.of(context).textTheme.labelMedium),
      onTap: day == null ? null : () => showRatingSheet(context, day: day),
    );
  }
}

/// ورقة تقييم اليوم: نجوم + ملاحظة سريعة عن اليوم — تُحفظ فورًا.
Future<void> showRatingSheet(BuildContext context, {required DateTime day}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext ctx) => _RatingSheet(day: day),
  );
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.day});

  final DateTime day;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  late int _rating;
  late final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    final DayNote? note = context.appRead.noteFor(widget.day);
    _rating = note?.mood ?? -1;
    _text.text = note?.text ?? '';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.appRead.saveNote(widget.day, _text.text.trim(), _rating);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 14, context.gap.screenPadding, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.seed.withAlpha(70),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Icon(Icons.star_rounded, size: 20, color: context.palette.seed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(context.tr('rate.dayTitle'), style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          context.dateStr(widget.day),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.tr('common.cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: StarRow(
                  value: _rating,
                  size: 40,
                  onChanged: (int value) => setState(() => _rating = value),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _rating < 0
                      ? context.tr('rate.tapToRate')
                      : context.tr('rate.labels.$_rating'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('rate.noteLabel'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                maxLines: 4,
                minLines: 2,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: context.tr('rate.noteHint'),
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(context.tr('common.save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
