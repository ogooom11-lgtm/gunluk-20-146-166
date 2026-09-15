import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/subtask.dart';
import '../../core/models/task.dart';
import '../../core/utils/dates.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/task_tile.dart';

enum SearchStatus { all, pending, done, skipped }

/// البحث في الإنجازات مع مرشّحات الحالة والتاريخ والتصنيف.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  SearchStatus _status = SearchStatus.all;
  String _categoryId = '';
  DateTime? _from;
  DateTime? _to;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Task> _results(BuildContext context) {
    final app = context.appRead;
    final String needle = _query.text.trim().toLowerCase();
    final List<Task> found = app.tasks.where((Task task) {
      if (_categoryId.isNotEmpty && task.categoryId != _categoryId) return false;
      if (_from != null && Dates.diffDays(_from!, task.date) < 0) return false;
      if (_to != null && Dates.diffDays(task.date, _to!) < 0) return false;
      switch (_status) {
        case SearchStatus.all:
          break;
        case SearchStatus.pending:
          if (task.done || task.skipped) return false;
          break;
        case SearchStatus.done:
          if (!task.done) return false;
          break;
        case SearchStatus.skipped:
          if (!task.skipped) return false;
          break;
      }
      if (needle.isEmpty) return true;
      if (task.title.toLowerCase().contains(needle)) return true;
      if (task.notes.toLowerCase().contains(needle)) return true;
      for (final String tag in task.tags) {
        if (tag.toLowerCase().contains(needle)) return true;
      }
      return false;
    }).toList();
    found.sort((Task a, Task b) => Dates.diffDays(b.date, a.date));
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final List<Task> results = _results(context);
    final bool hasFilters = _categoryId.isNotEmpty || _from != null || _to != null || _status != SearchStatus.all;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('search.title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 40),
        children: <Widget>[
          TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.tr('search.hint'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _query.clear()),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.tr('search.status'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              if (hasFilters)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _status = SearchStatus.all;
                    _categoryId = '';
                    _from = null;
                    _to = null;
                  }),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
                  label: Text(context.tr('common.clear')),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SearchStatus status in SearchStatus.values)
                ChoiceChip(
                  label: Text(context.tr(_statusKey(status))),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  onTap: () async {
                    final DateTime? picked = await showDayPickerSheet(
                      context,
                      initial: _from ?? Dates.addDays(Dates.today(), -30),
                      title: context.tr('search.dateRange'),
                      allowClear: true,
                    );
                    if (!mounted || picked == null) return;
                    if (picked != null) {
                      setState(() {
                        _from = picked;
                        if (_to != null && Dates.diffDays(_from!, _to!) < 0) _to = null;
                      });
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(context.tr('common.from'), style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 3),
                      Text(
                        _from == null ? '—' : context.shortDateStr(_from!),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  onTap: () async {
                    final DateTime? picked = await showDayPickerSheet(
                      context,
                      initial: _to ?? Dates.today(),
                      firstDate: _from,
                      title: context.tr('search.dateRange'),
                      allowClear: true,
                    );
                    if (!mounted || picked == null) return;
                    setState(() => _to = picked);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(context.tr('common.to'), style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 3),
                      Text(
                        _to == null ? '—' : context.shortDateStr(_to!),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SettingsGroup(
            title: context.tr('search.category'),
            children: <Widget>[
              SettingsValueTile(
                title: context.tr('search.category'),
                value: _categoryId.isEmpty ? context.tr('common.all') : app.categoryName(_categoryId),
                icon: _categoryId.isEmpty ? Icons.category_outlined : app.categoryIcon(_categoryId),
                iconColor: _categoryId.isEmpty ? null : app.categoryColor(_categoryId),
                onTap: () async {
                  final String? picked = await showChoiceSheet<String>(
                    context,
                    title: context.tr('search.category'),
                    value: _categoryId,
                    options: <ChoiceItem<String>>[
                      ChoiceItem<String>(value: '', label: context.tr('common.all'), icon: Icons.all_inclusive_rounded),
                      for (final Category category in app.categories)
                        ChoiceItem<String>(
                          value: category.id,
                          label: category.name,
                          icon: category.icon,
                          color: Color(category.color),
                        ),
                    ],
                  );
                  if (!mounted || picked == null) return;
                  setState(() => _categoryId = picked);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: context.tr(
              'search.results',
              <String, String>{'n': context.numStr(results.length)},
            ),
            icon: Icons.manage_search_rounded,
          ),
          if (results.isEmpty)
            AppCard(
              child: Column(
                children: <Widget>[
                  Icon(Icons.search_off_rounded, size: 30, color: context.palette.seed),
                  const SizedBox(height: 10),
                  Text(context.tr('search.noResults'), style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          else
            for (final Task task in results.take(120)) ...<Widget>[
              TaskTile(task: task, showDate: true, enableSwipe: false),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  String _statusKey(SearchStatus status) {
    switch (status) {
      case SearchStatus.all:
        return 'calendar.filterAll';
      case SearchStatus.pending:
        return 'calendar.filterPending';
      case SearchStatus.done:
        return 'calendar.filterDone';
      case SearchStatus.skipped:
        return 'task.stateSkipped';
    }
  }
}
