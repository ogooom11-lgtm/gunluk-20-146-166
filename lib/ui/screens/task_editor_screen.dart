import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/l10n/date_names.dart';
import '../../core/models/plan.dart';
import '../../core/models/stats.dart';
import '../../core/models/subtask.dart';
import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/ids.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/selectors.dart';
import '../widgets/settings_tiles.dart';
import 'categories_screen.dart';

/// محرّر الإنجاز: مهمة واحدة أو خطة متكررة (مع معاينة أيام الخطة وأيام الدوام).
class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({
    super.key,
    this.taskId,
    this.planId,
    this.draft,
    this.initialIsPlan = false,
    this.initialDay,
  });

  final String? taskId;
  final String? planId;
  final Task? draft;
  final bool initialIsPlan;
  final DateTime? initialDay;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _subtask = TextEditingController();
  final TextEditingController _tag = TextEditingController();

  bool _isPlan = false;
  bool _loaded = false;

  // حقول المهمة
  String _categoryId = 'general';
  TaskPriority _priority = TaskPriority.medium;
  DateTime _date = Dates.today();
  int? _startMinutes;
  int _duration = 0;
  List<int> _leads = <int>[];
  int? _reminderAt;
  final List<Subtask> _subtasks = <Subtask>[];
  final List<String> _tags = <String>[];

  // حقول الخطة
  RepeatType _repeatType = RepeatType.weekly;
  Set<int> _weekdays = <int>{DateTime.tuesday};
  int _intervalDays = 2;
  int _dayOfMonth = 1;
  DateTime? _endDate;
  bool _paused = false;

  Task? _existingTask;
  Plan? _existingPlan;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final app = context.app;

    if (widget.taskId != null) {
      final Task? task = app.taskById(widget.taskId!);
      if (task != null) {
        _existingTask = task;
        _title.text = task.title;
        _notes.text = task.notes;
        _categoryId = task.categoryId;
        _priority = task.priority;
        _date = task.date;
        _startMinutes = task.startMinutes;
        _duration = task.durationMinutes;
        _leads = List<int>.from(task.reminderLeads);
        _reminderAt = task.reminderAtMinutes;
        _subtasks.addAll(task.subtasks.map((Subtask s) => s.copy()));
        _tags.addAll(task.tags);
      }
    } else if (widget.planId != null) {
      final Plan? plan = app.planById(widget.planId!);
      if (plan != null) {
        _isPlan = true;
        _existingPlan = plan;
        _title.text = plan.title;
        _notes.text = plan.notes;
        _categoryId = plan.categoryId;
        _priority = plan.priority;
        _repeatType = plan.repeatType;
        _weekdays = Set<int>.from(plan.weekdays);
        _intervalDays = plan.intervalDays;
        _dayOfMonth = plan.dayOfMonth;
        _date = plan.startDate;
        _endDate = plan.endDate;
        _startMinutes = plan.startMinutes;
        _duration = plan.durationMinutes;
        _leads = List<int>.from(plan.reminderLeads);
        _reminderAt = plan.reminderAtMinutes;
        _subtasks.addAll(plan.subtaskTemplates.map((Subtask s) => s.copy()));
        _tags.addAll(plan.tags);
        _paused = plan.paused;
      }
    } else if (widget.draft != null) {
      final Task draft = widget.draft!;
      _title.text = draft.title;
      _notes.text = draft.notes;
      _categoryId = draft.categoryId;
      _priority = draft.priority;
      _date = draft.date;
      _startMinutes = draft.startMinutes;
      _duration = draft.durationMinutes;
      _leads = List<int>.from(draft.reminderLeads);
      _reminderAt = draft.reminderAtMinutes;
      _subtasks.addAll(draft.subtasks.map((Subtask s) => s.copy()));
      _tags.addAll(draft.tags);
    } else {
      _isPlan = widget.initialIsPlan;
      _date = widget.initialDay ?? Dates.today();
      _leads = <int>[app.settings.defaultLeadMinutes];
      _categoryId = app.categories.first.id;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _subtask.dispose();
    _tag.dispose();
    super.dispose();
  }

  bool get _isEditing => _existingTask != null || _existingPlan != null;

  @override
  Widget build(BuildContext context) {
    final bool hasTime = _startMinutes != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isPlan
              ? (_existingPlan == null ? context.tr('task.newPlan') : context.tr('task.editPlan'))
              : (_existingTask == null ? context.tr('task.new') : context.tr('task.edit')),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: Text(context.tr('common.save'), style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 140),
        children: <Widget>[
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: InputDecoration(
              hintText: _isPlan ? context.tr('plan.nameHint') : context.tr('task.titleHint'),
              prefixIcon: const Icon(Icons.edit_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (_existingPlan == null && _existingTask == null) _typeSelector(context),
          if (!_isPlan) ...<Widget>[
            _sectionTitle(context, context.tr('task.category'), Icons.category_rounded),
            CategorySelector(
              value: _categoryId,
              onChanged: (String value) => setState(() => _categoryId = value),
              onManage: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle(context, context.tr('task.priority'), Icons.flag_rounded),
            PrioritySelector(
              value: _priority,
              onChanged: (TaskPriority value) => setState(() => _priority = value),
            ),
            const SizedBox(height: 18),
            _sectionTitle(context, context.tr('task.date'), Icons.event_rounded),
            _dateChips(context),
            const SizedBox(height: 18),
            _timeSection(context, hasTime: hasTime),
            const SizedBox(height: 18),
            _remindersSection(context, hasTime: hasTime),
          ] else ...<Widget>[
            _sectionTitle(context, context.tr('task.category'), Icons.category_rounded),
            CategorySelector(
              value: _categoryId,
              onChanged: (String value) => setState(() => _categoryId = value),
              onManage: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle(context, context.tr('task.priority'), Icons.flag_rounded),
            PrioritySelector(
              value: _priority,
              onChanged: (TaskPriority value) => setState(() => _priority = value),
            ),
            const SizedBox(height: 18),
            _sectionTitle(context, context.tr('plan.repeatType'), Icons.repeat_rounded),
            _repeatSection(context),
            const SizedBox(height: 18),
            _sectionTitle(context, context.tr('task.time'), Icons.schedule_rounded),
            _timeSection(context, hasTime: hasTime),
            const SizedBox(height: 18),
            _remindersSection(context, hasTime: hasTime),
            const SizedBox(height: 18),
            _planPreview(context),
            if (_existingPlan != null) ...<Widget>[
              const SizedBox(height: 12),
              SettingsSwitchTile(
                title: context.tr('plan.pause'),
                subtitle: context.tr('plan.paused'),
                icon: Icons.pause_circle_outline_rounded,
                value: _paused,
                onChanged: (bool value) => setState(() => _paused = value),
              ),
            ],
          ],
          const SizedBox(height: 18),
          _sectionTitle(context, context.tr('task.subtasks'), Icons.checklist_rounded),
          _subtasksSection(context),
          const SizedBox(height: 18),
          _sectionTitle(context, context.tr('task.tags'), Icons.sell_rounded),
          _tagsSection(context),
          const SizedBox(height: 18),
          _sectionTitle(context, context.tr('task.notes'), Icons.notes_rounded),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(hintText: context.tr('task.notesHint')),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(context.tr('common.save')),
          ),
          const SizedBox(height: 10),
          if (_isEditing)
            OutlinedButton.icon(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE05B5B)),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(context.tr('common.delete')),
            ),
        ],
      ),
    );
  }

  Widget _typeSelector(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _typeCard(
            context,
            title: context.tr('task.new'),
            subtitle: context.tr('task.singleDesc'),
            icon: Icons.check_circle_outline_rounded,
            selected: !_isPlan,
            onTap: () => setState(() => _isPlan = false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _typeCard(
            context,
            title: context.tr('task.repeatPlan'),
            subtitle: context.tr('task.repeatDesc'),
            icon: Icons.repeat_rounded,
            selected: _isPlan,
            onTap: () => setState(() => _isPlan = true),
          ),
        ),
      ],
    );
  }

  Widget _typeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final Color color = context.palette.seed;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: selected ? color.withAlpha(context.isDark ? 60 : 26) : null,
      border: Border.all(
        color: selected ? color.withAlpha(160) : Theme.of(context).dividerColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: selected ? color : Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 17, color: context.palette.seed),
          const SizedBox(width: 6),
          Text(title, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }

  Widget _dateChips(BuildContext context) {
    final bool isToday = Dates.isToday(_date);
    final bool isTomorrow = Dates.diffDays(Dates.today(), _date) == 1;
    Widget chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? context.palette.seed : context.palette.seed.withAlpha(context.isDark ? 30 : 16),
              borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : context.palette.seed,
                  ),
            ),
          ),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        chip(context.tr('quick.today'), isToday, () => setState(() => _date = Dates.today())),
        chip(context.tr('quick.tomorrow'), isTomorrow,
            () => setState(() => _date = Dates.addDays(Dates.today(), 1))),
        chip(
          isToday || isTomorrow ? context.tr('task.date') : context.dateStr(_date),
          !isToday && !isTomorrow,
          () async {
            final DateTime? picked = await showDayPickerSheet(context, initial: _date);
            if (!mounted || picked == null) return;
            setState(() => _date = picked);
          },
        ),
      ],
    );
  }

  Widget _timeSection(BuildContext context, {required bool hasTime}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: AppCard(
                onTap: () async {
                  final int? picked = await showTimeWheelSheet(
                    context,
                    initialMinutes: _startMinutes ?? 9 * 60,
                    allowClear: true,
                  );
                  if (!mounted || picked == null) return;
                  setState(() {
                    if (picked < 0) {
                      _startMinutes = null;
                      _duration = 0;
                    } else {
                      _startMinutes = picked;
                      if (_leads.isEmpty) _leads = <int>[context.st.defaultLeadMinutes];
                      if (_duration == 0) _duration = 30;
                    }
                  });
                },
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.schedule_rounded, size: 18, color: context.palette.seed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasTime ? context.timeStr(_startMinutes!) : context.tr('task.noTime'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (hasTime)
                      IconButton(
                        onPressed: () => setState(() {
                          _startMinutes = null;
                          _duration = 0;
                        }),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (hasTime) ...<Widget>[
          const SizedBox(height: 10),
          Text(context.tr('task.duration'), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final int minutes in <int>[15, 30, 45, 60, 90, 120])
                GestureDetector(
                  onTap: () => setState(() => _duration = minutes),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _duration == minutes
                          ? context.palette.seed
                          : context.palette.seed.withAlpha(context.isDark ? 30 : 16),
                      borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
                    ),
                    child: Text(
                      context.durStr(minutes),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: _duration == minutes ? Colors.white : context.palette.seed,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _remindersSection(BuildContext context, {required bool hasTime}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionTitle(context, context.tr('task.reminders'), Icons.notifications_active_rounded),
        if (hasTime) ...<Widget>[
          Text(context.tr('task.reminderBefore'), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          LeadTimeSelector(
            values: _leads,
            onChanged: (List<int> values) => setState(() => _leads = values),
          ),
        ] else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppCard(
                  onTap: () async {
                    final int? picked = await showTimeWheelSheet(
                      context,
                      initialMinutes: _reminderAt ?? 20 * 60,
                      allowClear: true,
                    );
                    if (!mounted || picked == null) return;
                    setState(() => _reminderAt = picked < 0 ? null : picked);
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.alarm_rounded, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _reminderAt == null
                              ? context.tr('task.addReminder')
                              : context.timeStr(_reminderAt!),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (_reminderAt != null)
                        IconButton(
                          onPressed: () => setState(() => _reminderAt = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _repeatSection(BuildContext context) {
    Widget chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? context.palette.seed : context.palette.seed.withAlpha(context.isDark ? 30 : 16),
              borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : context.palette.seed,
                  ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final RepeatType type in RepeatType.values)
              chip(context.tr(type.labelKey), _repeatType == type, () => setState(() => _repeatType = type)),
          ],
        ),
        const SizedBox(height: 14),
        if (_repeatType == RepeatType.weekly) ...<Widget>[
          Text(context.tr('plan.weekdaysNote'), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          WeekdaySelector(
            selected: _weekdays,
            onChanged: (Set<int> value) => setState(() => _weekdays = value),
          ),
        ],
        if (_repeatType == RepeatType.interval) ...<Widget>[
          Text(context.tr('plan.intervalDays'), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Slider(
                  value: _intervalDays.toDouble().clamp(2.0, 30.0),
                  min: 2,
                  max: 30,
                  divisions: 28,
                  label: context.numStr(_intervalDays),
                  onChanged: (double value) => setState(() => _intervalDays = value.round()),
                ),
              ),
              Text(context.numStr(_intervalDays), style: AppTheme.numeric(context, factor: 0.9)),
            ],
          ),
        ],
        if (_repeatType == RepeatType.monthly) ...<Widget>[
          Text(context.tr('plan.dayOfMonth'), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Slider(
                  value: _dayOfMonth.toDouble().clamp(1.0, 31.0),
                  min: 1,
                  max: 31,
                  divisions: 30,
                  label: context.numStr(_dayOfMonth),
                  onChanged: (double value) => setState(() => _dayOfMonth = value.round()),
                ),
              ),
              Text(context.numStr(_dayOfMonth), style: AppTheme.numeric(context, factor: 0.9)),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: AppCard(
                onTap: () async {
                  final DateTime? picked = await showDayPickerSheet(
                    context,
                    initial: _date,
                    title: context.tr('plan.startDate'),
                  );
                  if (!mounted || picked == null) return;
                  setState(() => _date = picked);
                },
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(context.tr('plan.startDate'), style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(context.dateStr(_date), style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppCard(
                onTap: () async {
                  final DateTime? picked = await showDayPickerSheet(
                    context,
                    initial: _endDate ?? Dates.addDays(_date, 30),
                    firstDate: _date,
                    title: context.tr('plan.endDate'),
                    allowClear: true,
                  );
                  if (!mounted || picked == null) return;
                  setState(() => _endDate = picked);
                },
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(context.tr('plan.endDate'), style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _endDate == null ? context.tr('plan.noEndDate') : context.dateStr(_endDate!),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (_endDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _endDate = null),
                            child: const Icon(Icons.close_rounded, size: 16),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(context.tr('plan.endDateHint'), style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _planPreview(BuildContext context) {
    final app = context.app;
    final Plan preview = _buildPlan(id: _existingPlan?.id ?? 'preview');
    final PlanStats stats = StatsEngine.planStats(
      plan: preview,
      tasks: _existingPlan == null ? <Task>[] : app.tasks,
      workDays: app.settings.workDays,
      now: DateTime.now(),
    );
    final List<int> workOrder = app.settings.workDays.toList()..sort();
    final String workDaysLabel = workOrder
        .map((int w) => DateNames.weekday(Dates.addDays(DateTime(2024, 1, 1), w - 1), context.langCode))
        .join('، ');

    return AppCard(
      padding: const EdgeInsets.all(16),
      color: context.palette.seed.withAlpha(context.isDark ? 32 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.insights_rounded, color: context.palette.seed, size: 19),
              const SizedBox(width: 8),
              Text(context.tr('plan.summary'), style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          _previewRow(context, 'plan.daysCount', context.numStr(stats.spanDays)),
          _previewRow(context, 'plan.scheduledDays', context.numStr(stats.scheduledTotal)),
          _previewRow(context, 'plan.workDays', context.numStr(stats.workDays)),
          _previewRow(context, 'plan.restDays', context.numStr(stats.restDays)),
          _previewRow(
            context,
            'plan.next',
            stats.next == null ? context.tr('plan.finished') : context.dateStr(stats.next!),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('plan.workDaysHint', <String, String>{'days': workDaysLabel}),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _previewRow(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(context.tr(key), style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }

  Widget _subtasksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_subtasks.isEmpty)
          Text(context.tr('task.subtasksHint'), style: Theme.of(context).textTheme.bodySmall),
        for (int i = 0; i < _subtasks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shadow: false,
              child: Row(
                children: <Widget>[
                  Checkbox(
                    value: _subtasks[i].done,
                    onChanged: (_) => setState(() => _subtasks[i].done = !_subtasks[i].done),
                  ),
                  Expanded(
                    child: Text(
                      _subtasks[i].title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            decoration: _subtasks[i].done ? TextDecoration.lineThrough : null,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _subtasks.removeAt(i)),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _subtask,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(hintText: context.tr('task.addSubtask')),
                onSubmitted: (String value) => _addSubtask(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addSubtask,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }

  void _addSubtask() {
    final String value = _subtask.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('toast.subtaskRequired'))));
      return;
    }
    setState(() {
      _subtasks.add(Subtask.create(value));
      _subtask.clear();
    });
  }

  Widget _tagsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String tag in _tags)
                Chip(
                  label: Text('#$tag'),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _tag,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(hintText: context.tr('task.tagsHint')),
                onSubmitted: (String value) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addTag,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }

  void _addTag() {
    final String value = _tag.text.trim();
    if (value.isEmpty) return;
    setState(() {
      if (!_tags.contains(value)) _tags.add(value);
      _tag.clear();
    });
  }

  Plan _buildPlan({String? id}) => Plan(
        id: id ?? Ids.next('pl'),
        title: _title.text.trim(),
        notes: _notes.text.trim(),
        categoryId: _categoryId,
        priority: _priority,
        repeatType: _repeatType,
        weekdays: _weekdays.isEmpty ? <int>{_date.weekday} : _weekdays,
        intervalDays: _intervalDays,
        dayOfMonth: _dayOfMonth,
        startDate: _date,
        endDate: _endDate,
        paused: _paused,
        startMinutes: _startMinutes,
        durationMinutes: _duration == 0 ? 30 : _duration,
        reminderLeads: _leads,
        reminderAtMinutes: _reminderAt,
        subtaskTemplates: _subtasks.map((Subtask s) => Subtask.create(s.title)).toList(),
        tags: List<String>.from(_tags),
        skippedDates: _existingPlan?.skippedDates ?? <String>{},
        createdAt: _existingPlan?.createdAt,
      );

  Future<void> _save() async {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('toast.titleRequired'))));
      return;
    }
    if (_isPlan && _repeatType == RepeatType.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('toast.planNoDays'))));
      return;
    }
    if (_isPlan && _endDate != null && Dates.diffDays(_date, _endDate!) < 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('toast.endBeforeStart'))));
      return;
    }
    final app = context.appRead;
    final NavigatorState navigator = Navigator.of(context);

    if (_isPlan) {
      await app.upsertPlan(_buildPlan(id: _existingPlan?.id ?? Ids.next('pl')));
      app.ensureOccurrences();
      await app.rebuildReminders(immediate: true);
      navigator.pop();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.tr('toast.planCreated'))));
      }
      return;
    }

    final Task task = Task(
      id: _existingTask?.id ?? Ids.next('t'),
      title: title,
      date: _date,
      notes: _notes.text.trim(),
      categoryId: _categoryId,
      priority: _priority,
      startMinutes: _startMinutes,
      durationMinutes: _duration,
      reminderLeads: _leads,
      reminderAtMinutes: _startMinutes == null ? _reminderAt : null,
      planId: _existingTask?.planId,
      subtasks: _subtasks,
      tags: List<String>.from(_tags),
      done: _existingTask?.done ?? false,
      completedAt: _existingTask?.completedAt,
      skipped: _existingTask?.skipped ?? false,
      createdAt: _existingTask?.createdAt,
    );
    await app.upsertTask(task);
    await app.rebuildReminders(immediate: true);
    navigator.pop();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('task.saved'))));
    }
  }

  Future<void> _delete() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: context.tr('common.delete'),
      message: _isPlan ? context.tr('plan.deleteConfirm') : context.tr('task.deleteConfirm'),
      confirmLabel: context.tr('common.delete'),
    );
    if (!confirmed) return;
    final app = context.appRead;
    final NavigatorState navigator = Navigator.of(context);
    if (_isPlan && _existingPlan != null) {
      await app.deletePlan(_existingPlan!.id);
    } else if (_existingTask != null) {
      await app.deleteTask(_existingTask!.id);
    }
    navigator.pop();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('toast.deleted'))));
    }
  }
}
