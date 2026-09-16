import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/ids.dart';
import '../app_scope.dart';
import '../screens/task_editor_screen.dart';
import 'common.dart';
import 'pickers.dart';

/// ورقة الإضافة السريعة: عنوان + يوم + وقت + فئة، أو الانتقال للتفاصيل الكاملة.
Future<void> showQuickAddSheet(BuildContext context, {DateTime? day, bool fullEditor = false}) {
  if (fullEditor) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TaskEditorScreen(draft: Task(id: '', title: '', date: day ?? Dates.today()))),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => _QuickAddSheet(initialDay: day ?? Dates.today()),
  );
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet({required this.initialDay});

  final DateTime initialDay;

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final TextEditingController _controller = TextEditingController();
  late DateTime _day = widget.initialDay;
  int? _minutes;
  String _categoryId = 'general';
  TaskPriority _priority = TaskPriority.medium;

  static const List<int> _quickTimes = <int>[7 * 60, 9 * 60, 12 * 60, 16 * 60, 20 * 60, 21 * 60];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> suggestions = <String>[
      context.tr('quick.book'),
      context.tr('quick.sport'),
      context.tr('quick.study'),
      context.tr('quick.work'),
      context.tr('category.general'),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 4, context.gap.screenPadding, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(context.tr('quick.title'), style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: context.tr('quick.hint'),
                  prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                ),
                onSubmitted: (_) => _save(context, false),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _chip(
                    context,
                    label: context.tr('quick.today'),
                    icon: Icons.today_rounded,
                    selected: Dates.isToday(_day),
                    onTap: () => setState(() => _day = Dates.today()),
                  ),
                  _chip(
                    context,
                    label: context.tr('quick.tomorrow'),
                    icon: Icons.event_rounded,
                    selected: Dates.diffDays(Dates.today(), _day) == 1,
                    onTap: () => setState(() => _day = Dates.addDays(Dates.today(), 1)),
                  ),
                  _chip(
                    context,
                    label: context.shortDateStr(_day),
                    icon: Icons.calendar_month_rounded,
                    selected: !Dates.isToday(_day) && Dates.diffDays(Dates.today(), _day) != 1,
                    onTap: () async {
                      final DateTime? picked = await showDayPickerSheet(context, initial: _day);
                      if (!mounted || picked == null) return;
                      setState(() => _day = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(context.tr('task.time'), style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final int minutes in _quickTimes)
                    _chip(
                      context,
                      label: context.timeStr(minutes),
                      selected: _minutes == minutes,
                      onTap: () => setState(() => _minutes = _minutes == minutes ? null : minutes),
                    ),
                  _chip(
                    context,
                    label: _minutes == null || _quickTimes.contains(_minutes)
                        ? context.tr('task.addReminder')
                        : context.timeStr(_minutes!),
                    icon: Icons.schedule_rounded,
                    selected: _minutes != null && !_quickTimes.contains(_minutes),
                    onTap: () async {
                      final int? picked = await showTimeWheelSheet(context, initialMinutes: _minutes ?? 9 * 60);
                      if (!mounted || picked == null || picked < 0) return;
                      setState(() => _minutes = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(context.tr('task.category'), style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: context.app.categories.length,
                  separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final category = context.app.categories[index];
                    final bool selected = _categoryId == category.id;
                    return GestureDetector(
                      onTap: () => setState(() => _categoryId = category.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? Color(category.color) : Color(category.color).withAlpha(context.isDark ? 45 : 22),
                          borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(category.icon, size: 15, color: selected ? Colors.white : Color(category.color)),
                            const SizedBox(width: 6),
                            Text(
                              category.name,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: selected ? Colors.white : Color(category.color),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text(context.tr('task.priority'), style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  for (final TaskPriority priority in TaskPriority.values)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = priority),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _priority == priority
                                ? priority.color
                                : priority.color.withAlpha(context.isDark ? 45 : 22),
                            borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
                          ),
                          child: Center(
                            child: Text(
                              context.tr(priority.labelKey),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _priority == priority ? Colors.white : priority.color,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (context.st.quickAddShortcuts) ...<Widget>[
                const SizedBox(height: 14),
                Text(context.tr('quick.suggestions'), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String suggestion in suggestions)
                      _chip(
                        context,
                        label: suggestion,
                        icon: Icons.bolt_rounded,
                        selected: false,
                        onTap: () => setState(() {
                          _controller.text = suggestion;
                          _controller.selection = TextSelection.collapsed(offset: suggestion.length);
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _save(context, true),
                      icon: const Icon(Icons.tune_rounded, size: 19),
                      label: Text(context.tr('common.more')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _save(context, false),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(context.tr('quick.add')),
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

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: () {
        tapHaptic(context);
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.palette.seed : context.palette.seed.withAlpha(context.isDark ? 30 : 16),
          borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: selected ? Colors.white : context.palette.seed),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : context.palette.seed,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, bool openEditor) async {
    final String title = _controller.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('toast.titleRequired'))));
      return;
    }
    final Task task = Task(
      id: Ids.next('t'),
      title: title,
      date: _day,
      startMinutes: _minutes,
      categoryId: _categoryId,
      priority: _priority,
      reminderLeads: _minutes == null
          ? <int>[]
          : <int>[context.st.defaultLeadMinutes],
    );
    final NavigatorState navigator = Navigator.of(context);
    if (openEditor) {
      navigator.pop();
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => TaskEditorScreen(draft: task)),
      );
      return;
    }
    await context.appRead.upsertTask(task);
    navigator.pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('task.saved'))));
    }
  }
}
