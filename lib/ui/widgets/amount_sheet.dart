import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/plan.dart';
import '../../core/utils/dates.dart';
import '../../data/app_state.dart';
import '../app_scope.dart';
import 'common.dart';

/// تنسيق الكمّية: بلا أصفار زائدة (٦٠ لا ٦٠٫٠، و٧١٫٥ تبقى كما هي).
String formatAmount(BuildContext context, double value) {
  final String text = value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return context.numStr(text);
}

/// ورقة «سجّل ما أنجزت»: كم قرأت/أنجزت اليوم من الخطة الكمّية.
///
/// تُحفظ في سجلّ الخطة نفسه (لا في المهمة) فلا يضيع شيء، ثم يُعاد توزيع
/// المطلوب على الأيام القادمة.
Future<void> showPlanAmountSheet(
  BuildContext context, {
  required String planId,
  required DateTime day,
}) async {
  final AppState app = context.appRead;
  final Plan? plan = app.planById(planId);
  if (plan == null || !plan.isQuantified) return;
  final double required = plan.requiredOn(day);
  final double current = plan.progressOn(day);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext ctx) => _AmountSheet(
      planId: planId,
      day: day,
      required: required,
      current: current,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.planId,
    required this.day,
    required this.required,
    required this.current,
  });

  final String planId;
  final DateTime day;
  final double required;
  final double current;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _value = TextEditingController(
    text: widget.current <= 0 ? '' : _plain(widget.current),
  );
  bool _busy = false;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  double get _entered {
    final double? parsed = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    return parsed == null || parsed < 0 ? 0 : parsed;
  }

  void _add(double delta) {
    final double next = _entered + delta;
    setState(() => _value.text = _plain(next < 0 ? 0 : next));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final String unit = context.tr('quant.unitPart', <String, String>{
      'unit': context.appRead.planById(widget.planId)?.unit ?? '',
    });
    final double value = _entered;
    final String saved = formatAmount(context, value);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await context.appRead.logPlanAmount(widget.planId, widget.day, value);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(context.tr('quant.saved', <String, String>{
          'v': saved,
          'unit': unit,
        }).trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Plan? plan = context.app.planById(widget.planId);
    final String unit = plan?.unit ?? '';
    final double nextRequired = plan?.requiredOn(Dates.addDays(widget.day, 1)) ?? 0;
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
                  Icon(Icons.edit_note_rounded, size: 20, color: context.palette.seed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(context.tr('quant.log'), style: Theme.of(context).textTheme.titleMedium),
                        Text(context.dateStr(widget.day), style: Theme.of(context).textTheme.labelSmall),
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
              const SizedBox(height: 8),
              if (widget.required > 0)
                Text(
                  context.tr('quant.dailyTarget', <String, String>{
                    'v': formatAmount(context, widget.required),
                    'unit': unit,
                  }),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey<String>('quant_amount_field'),
                controller: _value,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: unit,
                  prefixIcon: const Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (widget.required > 0)
                    _chip(
                      context,
                      context.tr('quant.markDoneFull'),
                      () => setState(() => _value.text = _plain(widget.required)),
                    ),
                  for (final int step in <int>[1, 5, 10, 25])
                    _chip(context, '+${context.numStr(step)}', () => _add(step.toDouble())),
                  _chip(
                    context,
                    context.tr('quant.nothing'),
                    () => setState(() => _value.text = ''),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (nextRequired > 0)
                Text(
                  context.tr('quant.nextAfter', <String, String>{
                    'v': formatAmount(context, nextRequired),
                    'unit': unit,
                  }),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey<String>('quant_amount_save'),
                      onPressed: _busy ? null : _save,
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

  Widget _chip(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: context.palette.seed.withAlpha(context.isDark ? 34 : 18),
          borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.palette.seed),
        ),
      ),
    );
  }
}

/// صف صغير يعرض كمّية يوم من خطة كمّية (يُستخدم في تفاصيل الخطة والمهام).
class AmountBar extends StatelessWidget {
  const AmountBar({
    super.key,
    required this.done,
    required this.target,
    required this.unit,
    this.color,
    this.height = 6,
  });

  final double done;
  final double target;
  final String unit;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? context.palette.seed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.auto_graph_rounded, size: 13, color: tint),
            const SizedBox(width: 5),
            Text(
              context.tr('quant.ofPair', <String, String>{
                'done': formatAmount(context, done),
                'total': formatAmount(context, target),
                'unit': unit,
              }).trim(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tint),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ThinProgress(value: target <= 0 ? 0 : (done / target).clamp(0.0, 1.0), color: tint, height: height),
      ],
    );
  }
}
