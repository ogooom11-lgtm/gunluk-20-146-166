import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/day_event.dart';
import '../../core/models/subtask.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/ids.dart';
import '../app_scope.dart';
import 'common.dart';
import 'pickers.dart';
import 'selectors.dart';
import 'settings_tiles.dart';

/// ورقة إضافة/تعديل حدث يومي.
Future<void> showEventEditorSheet(
  BuildContext context, {
  DayEvent? event,
  DateTime? day,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => _EventEditorSheet(event: event, day: day),
  );
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({this.event, this.day});

  final DayEvent? event;
  final DateTime? day;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _place;
  late DateTime _day;
  late int? _minutes;
  late String _categoryId;
  late bool _starred;
  String? _iconKey;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final DayEvent? event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    _notes = TextEditingController(text: event?.notes ?? '');
    _place = TextEditingController(text: event?.place ?? '');
    _day = Dates.day(event?.day ?? widget.day ?? Dates.today());
    _minutes = event?.minutes;
    _categoryId = event?.categoryId ?? 'general';
    _starred = event?.starred ?? false;
    _iconKey = event?.iconKey;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController controller) => ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 4, context.gap.screenPadding, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.tr(_isEditing ? 'event.edit' : 'event.new'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    tooltip: context.tr('common.delete'),
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE05B5B)),
                  ),
                IconButton(
                  tooltip: context.tr('common.close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              style: Theme.of(context).textTheme.titleMedium,
              decoration: InputDecoration(
                labelText: context.tr('event.name'),
                hintText: context.tr('event.nameHint'),
                prefixIcon: const Icon(Icons.event_note_rounded),
              ),
            ),
            const SizedBox(height: 14),
            _card(
              context,
              children: <Widget>[
                _row(
                  context,
                  icon: Icons.calendar_month_rounded,
                  label: context.tr('event.when'),
                  value: context.dateStr(_day),
                  onTap: _pickDay,
                ),
                const Divider(height: 18),
                _row(
                  context,
                  icon: Icons.schedule_rounded,
                  label: context.tr('event.time'),
                  value: _minutes == null
                      ? context.tr('event.noTime')
                      : context.timeStr(_minutes!),
                  onTap: _pickTime,
                  trailing: _minutes == null
                      ? null
                      : IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: context.tr('event.clearTime'),
                          onPressed: () => setState(() => _minutes = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _place,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('event.place'),
                hintText: context.tr('event.placeHint'),
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: context.tr('event.notes'),
                hintText: context.tr('event.notesHint'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(context.tr('event.category'), style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            CategorySelector(
              value: _categoryId,
              onChanged: (String id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 14),
            Text(context.tr('category.icon'), style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            _iconPicker(context),
            const SizedBox(height: 14),
            SettingsSwitchTile(
              title: context.tr('event.star'),
              value: _starred,
              icon: Icons.star_rounded,
              onChanged: (bool value) => setState(() => _starred = value),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('common.cancel')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(context.tr('common.save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required List<Widget> children}) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(children: children),
      );

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: context.palette.seed),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(value, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            if (trailing != null) trailing else const Icon(Icons.chevron_left_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _iconPicker(BuildContext context) {
    // أيقونة الحدث: أيقونة الفئة افتراضيًا، ويمكن تخصيصها.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            PressableScale(
              onTap: () => setState(() => _iconKey = null),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _iconKey == null
                      ? context.palette.seed.withAlpha(context.isDark ? 60 : 28)
                      : Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(14 * context.st.radiusScale),
                  border: _iconKey == null ? Border.all(color: context.palette.seed, width: 1.4) : null,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 19,
                  color: _iconKey == null ? context.palette.seed : null,
                ),
              ),
            ),
            for (final String key in CategoryIcons.keys)
              PressableScale(
                onTap: () => setState(() => _iconKey = key),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _iconKey == key
                        ? context.palette.seed.withAlpha(context.isDark ? 60 : 28)
                        : Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(14 * context.st.radiusScale),
                    border: _iconKey == key ? Border.all(color: context.palette.seed, width: 1.4) : null,
                  ),
                  child: Icon(
                    CategoryIcons.byKey(key),
                    size: 19,
                    color: _iconKey == key ? context.palette.seed : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDay() async {
    final DateTime? picked = await showDayPickerSheet(
      context,
      initial: _day,
      firstDate: DateTime(2000),
      lastDate: Dates.addDays(Dates.today(), 3650),
      title: context.tr('event.when'),
    );
    if (!mounted || picked == null) return;
    setState(() => _day = Dates.day(picked));
  }

  Future<void> _pickTime() async {
    final int? picked = await showTimeWheelSheet(
      context,
      initialMinutes: _minutes ?? 9 * 60,
      title: context.tr('event.time'),
      minuteStep: 5,
    );
    if (!mounted || picked == null) return;
    setState(() => _minutes = picked);
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('event.nameHint'))));
      return;
    }
    final app = context.appRead;
    final DayEvent base = widget.event ??
        DayEvent(id: Ids.next('ev'), title: title, day: _day);
    final DayEvent saved = DayEvent(
      id: base.id,
      title: title,
      day: _day,
      minutes: _minutes,
      notes: _notes.text.trim(),
      place: _place.text.trim(),
      categoryId: _categoryId,
      iconKey: _iconKey,
      starred: _starred,
      createdAt: base.createdAt,
      updatedAt: DateTime.now(),
    );
    await app.upsertEvent(saved);
    if (!mounted) return;
    successHaptic(context);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr('event.savedToast'))));
  }

  Future<void> _confirmDelete() async {
    final DayEvent? event = widget.event;
    if (event == null) return;
    final bool confirmed = await showConfirmDialog(
      context,
      title: context.tr('common.delete'),
      message: context.tr('event.deleteConfirm'),
      confirmLabel: context.tr('common.delete'),
    );
    if (!confirmed || !mounted) return;
    await context.appRead.deleteEvent(event.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
