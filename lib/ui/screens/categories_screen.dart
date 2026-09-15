import 'package:flutter/material.dart';

import '../../core/models/subtask.dart';
import '../../core/models/task.dart';
import '../../core/utils/ids.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/selectors.dart';

/// إدارة التصنيفات: إضافة، تعديل، أرشفة، وحذف.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final List<Category> categories = List<Category>.from(app.categories)
      ..sort((Category a, Category b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('category.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('category.new')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 8, context.gap.screenPadding, 120),
        children: <Widget>[
          Text(context.tr('category.taskCount'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          for (final Category category in categories) ...<Widget>[
            AppCard(
              onTap: () => _openEditor(context, category),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(category.color).withAlpha(context.isDark ? 60 : 26),
                      borderRadius: BorderRadius.circular(13 * context.st.radiusScale),
                    ),
                    child: Icon(category.icon, color: Color(category.color), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(category.name, style: Theme.of(context).textTheme.titleSmall),
                            if (category.isDefault) ...<Widget>[
                              const SizedBox(width: 8),
                              Pill(label: context.tr('category.general'), dense: true, color: Colors.blueGrey),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${context.tr('category.taskCount')}: '
                          '${context.numStr(app.tasks.where((Task t) => t.categoryId == category.id).length)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openEditor(context, category),
                    icon: const Icon(Icons.edit_rounded, size: 19),
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(context, category),
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, Category? category) async {
    final app = context.appRead;
    String name = category?.name ?? '';
    int color = category?.color ?? CategoryColors.values.first;
    String iconKey = category?.iconKey ?? CategoryIcons.keys.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: context.gap.screenPadding,
                right: context.gap.screenPadding,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 18,
              ),
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  Text(
                    category == null ? context.tr('category.new') : context.tr('category.edit'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    autofocus: true,
                    controller: TextEditingController(text: name),
                    onChanged: (String value) => name = value,
                    decoration: InputDecoration(
                      labelText: context.tr('category.name'),
                      prefixIcon: const Icon(Icons.label_important_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(context.tr('category.color'), style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  ColorSelector(value: color, onChanged: (int value) => setSheet(() => color = value)),
                  const SizedBox(height: 18),
                  Text(context.tr('category.icon'), style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  IconSelector(value: iconKey, onChanged: (String value) => setSheet(() => iconKey = value)),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () async {
                      final String trimmed = name.trim();
                      if (trimmed.isEmpty) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(context.tr('toast.titleRequired'))));
                        return;
                      }
                      await app.upsertCategory(
                        Category(
                          id: category?.id ?? Ids.next('c'),
                          name: trimmed,
                          color: color,
                          iconKey: iconKey,
                          isDefault: category?.isDefault ?? false,
                          order: category?.order ?? app.categories.length,
                        ),
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: Text(context.tr('common.save')),
                  ),
                  if (category != null && !category.isDefault) ...<Widget>[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await app.upsertCategory(
                          Category(
                            id: category.id,
                            name: category.name,
                            color: category.color,
                            iconKey: category.iconKey,
                            isDefault: category.isDefault,
                            archived: !category.archived,
                            order: category.order,
                          ),
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(context.tr('common.edit')),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Category category) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: context.tr('common.delete'),
      message: context.tr('category.deleteConfirm'),
      confirmLabel: context.tr('common.delete'),
    );
    if (!confirmed) return;
    await context.appRead.deleteCategory(category.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr('toast.deleted'))));
  }
}

/// بطاقة تصنيف مختصرة تُستخدم في الشاشات الأخرى.
class CategoryChipTile extends StatelessWidget {
  const CategoryChipTile({super.key, required this.category, this.onTap, this.selected = false});

  final Category category;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color color = Color(category.color);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: selected ? color.withAlpha(context.isDark ? 55 : 26) : null,
      border: Border.all(color: selected ? color.withAlpha(160) : Theme.of(context).dividerColor),
      child: Row(
        children: <Widget>[
          Icon(category.icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(category.name, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// ألوان مقترحة لتصنيف جديد (لون واحد لكل سطر).
class CategoryPaletteRow extends StatelessWidget {
  const CategoryPaletteRow({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ColorSelector(value: value, onChanged: onChanged);
  }
}
