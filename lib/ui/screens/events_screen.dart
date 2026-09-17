import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/day_event.dart';
import '../../core/models/subtask.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/event_editor_sheet.dart';
import '../widgets/pickers.dart';

/// شاشة الأحداث اليومية: سجل كامل يبقى محفوظًا للأبد.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

enum _EventsTab { all, starred, upcoming, past }

class _EventsScreenState extends State<EventsScreen> {
  final TextEditingController _search = TextEditingController();
  _EventsTab _tab = _EventsTab.all;
  DateTime? _dayFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DayEvent> _list() {
    final app = context.app;
    final String query = _search.text.trim();
    List<DayEvent> base;
    if (query.isNotEmpty) {
      base = app.searchEvents(query);
    } else {
      switch (_tab) {
        case _EventsTab.all:
          base = app.eventsSorted;
        case _EventsTab.starred:
          base = app.starredEvents;
        case _EventsTab.upcoming:
          base = app.upcomingEvents(days: 3650);
        case _EventsTab.past:
          base = app.pastEvents(days: 3650);
      }
    }
    final DateTime? day = _dayFilter;
    if (day != null) {
      base = base.where((DayEvent e) => e.isOn(day)).toList();
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final List<DayEvent> events = _list();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('event.title')),
        actions: <Widget>[
          if (_dayFilter != null)
            IconButton(
              tooltip: context.tr('event.allDays'),
              onPressed: () => setState(() => _dayFilter = null),
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
          IconButton(
            tooltip: context.tr('event.filterByDay'),
            onPressed: _pickDayFilter,
            icon: const Icon(Icons.event_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEventEditorSheet(context, day: _dayFilter ?? Dates.today()),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('event.new')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 6, context.gap.screenPadding, 120),
        children: <Widget>[
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.tr('event.searchHint'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _search.clear()),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _summaryCard(context, app.events.length),
          const SizedBox(height: 6),
          Text(
            context.tr('event.kept'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 12),
          if (_search.text.trim().isEmpty) _tabs(context),
          if (_dayFilter != null) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(Icons.event_rounded, size: 16, color: context.palette.seed),
                const SizedBox(width: 6),
                Text(context.shortDateStr(_dayFilter!), style: Theme.of(context).textTheme.labelMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _dayFilter = null),
                  child: Text(context.tr('event.allDays')),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (events.isEmpty)
            EmptyState(
              icon: Icons.event_note_rounded,
              title: context.tr(_search.text.trim().isEmpty ? 'event.empty' : 'event.noneInList'),
              message: context.tr('event.emptyDesc'),
              actionLabel: context.tr('event.new'),
              onAction: () => showEventEditorSheet(context, day: _dayFilter ?? Dates.today()),
            )
          else
            _groupedList(context, events),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, int total) {
    final app = context.app;
    final int today = app.eventCountOn(Dates.today());
    final int month = app.eventCountInMonth(Dates.today());
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _miniStat(
              context,
              icon: Icons.today_rounded,
              label: context.tr('event.today'),
              value: context.numStr(today),
            ),
          ),
          Container(width: 1, height: 34, color: context.palette.seed.withAlpha(40)),
          Expanded(
            child: _miniStat(
              context,
              icon: Icons.calendar_month_rounded,
              label: context.monthStr(Dates.today().month),
              value: context.numStr(month),
            ),
          ),
          Container(width: 1, height: 34, color: context.palette.seed.withAlpha(40)),
          Expanded(
            child: _miniStat(
              context,
              icon: Icons.inventory_2_rounded,
              label: context.tr('event.tabAll'),
              value: context.numStr(total),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, {required IconData icon, required String label, required String value}) {
    return Column(
      children: <Widget>[
        Icon(icon, size: 17, color: context.palette.seed),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  Widget _tabs(BuildContext context) {
    const List<_EventsTab> order = <_EventsTab>[
      _EventsTab.all,
      _EventsTab.starred,
      _EventsTab.upcoming,
      _EventsTab.past,
    ];
    const Map<_EventsTab, String> keys = <_EventsTab, String>{
      _EventsTab.all: 'event.tabAll',
      _EventsTab.starred: 'event.tabStarred',
      _EventsTab.upcoming: 'event.tabUpcoming',
      _EventsTab.past: 'event.tabPast',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final _EventsTab tab in order) ...<Widget>[
            PressableScale(
              onTap: () => setState(() => _tab = tab),
              child: Pill(
                label: context.tr(keys[tab]!),
                dense: true,
                color: context.palette.seed,
                filled: _tab == tab,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// يجمع الأحداث حسب اليوم مع فواصل تاريخية.
  Widget _groupedList(BuildContext context, List<DayEvent> events) {
    final List<Widget> children = <Widget>[];
    String? currentDay;
    for (final DayEvent event in events) {
      final String key = event.dayKey;
      if (key != currentDay) {
        currentDay = key;
        children.add(_dayHeader(context, event.day, events.where((DayEvent e) => e.dayKey == key).length));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: EventTile(event: event),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _dayHeader(BuildContext context, DateTime day, int count) {
    final bool today = Dates.isToday(day);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: <Widget>[
          Text(
            today ? context.tr('common.today') : context.relativeDay(day),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.palette.seed),
          ),
          const SizedBox(width: 8),
          Text(context.weekdayStr(day), style: Theme.of(context).textTheme.labelSmall),
          const Spacer(),
          Text(
            context.tr('event.count', <String, String>{'n': context.numStr(count)}),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDayFilter() async {
    final DateTime? picked = await showDayPickerSheet(
      context,
      initial: _dayFilter ?? Dates.today(),
      allowClear: true,
      title: context.tr('event.filterByDay'),
    );
    if (!mounted) return;
    setState(() => _dayFilter = picked);
  }
}

/// سطر حدث واحد داخل القوائم.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, this.dense = false, this.showDay = false});

  final DayEvent event;
  final bool dense;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final Category? category = app.category(event.categoryId);
    final Color color = app.categoryColor(event.categoryId);

    return AppCard(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 10 : 12),
      onTap: () => showEventEditorSheet(context, event: event),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withAlpha(context.isDark ? 60 : 26),
              borderRadius: BorderRadius.circular(12 * context.st.radiusScale),
            ),
            child: Icon(
              event.iconKey != null ? CategoryIcons.byKey(event.iconKey!) : (category?.icon ?? Icons.event_rounded),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.starred) ...<Widget>[
                      const SizedBox(width: 6),
                      const Icon(Icons.star_rounded, size: 17, color: Color(0xFFE8A93C)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: <Widget>[
                    if (showDay || !Dates.isToday(event.day))
                      _meta(context, Icons.calendar_month_rounded, context.shortDateStr(event.day)),
                    if (event.hasTime)
                      _meta(
                        context,
                        Icons.schedule_rounded,
                        context.tr('event.atTime', <String, String>{'t': context.timeStr(event.minutes!)}),
                      ),
                    if (event.place.trim().isNotEmpty)
                      _meta(context, Icons.place_rounded, event.place.trim()),
                    if (category != null && !category.isDefault)
                      _meta(context, Icons.folder_rounded, category.name),
                  ],
                ),
                if (!dense && event.notes.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    event.notes.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: context.tr('event.star'),
            onPressed: () => context.appRead.toggleEventStar(event.id),
            icon: Icon(
              event.starred ? Icons.star_rounded : Icons.star_border_rounded,
              size: 20,
              color: event.starred ? const Color(0xFFE8A93C) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: context.palette.seed.withAlpha(200)),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
