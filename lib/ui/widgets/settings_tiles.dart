import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'common.dart';

/// مجموعة إعدادات داخل بطاقة واحدة مع فواصل.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children, this.subtitle, this.icon});

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: title, subtitle: subtitle, icon: icon),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 1, indent: 56, endIndent: 12, color: Theme.of(context).dividerColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// سطر إعداد عام.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color color = iconColor ?? context.palette.seed;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              tapHaptic(context);
              onTap!.call();
            },
      borderRadius: BorderRadius.circular(16 * context.st.radiusScale),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: dense ? 10 : 14,
        ),
        child: Row(
          children: <Widget>[
            if (icon != null)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withAlpha(context.isDark ? 60 : 30),
                  borderRadius: BorderRadius.circular(11 * context.st.radiusScale),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            if (icon != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null)
              Icon(
                Icons.chevron_left_rounded,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
          ],
        ),
      ),
    );
  }
}

/// سطر إعداد مع مفتاح تشغيل.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      onTap: enabled
          ? () {
              tapHaptic(context);
              onChanged(!value);
            }
          : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: enabled
            ? (bool v) {
                tapHaptic(context);
                onChanged(v);
              }
            : null,
      ),
    );
  }
}

/// سطر يعرض قيمة نصية.
class SettingsValueTile extends StatelessWidget {
  const SettingsValueTile({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.palette.seed),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_left_rounded,
            size: 20,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ],
      ),
    );
  }
}

/// شريط خطر (حذف البيانات).
class DangerTile extends StatelessWidget {
  const DangerTile({super.key, required this.title, this.subtitle, required this.onTap, this.icon = Icons.delete_forever_rounded});

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color danger = Color(0xFFE05B5B);
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: danger,
      onTap: onTap,
      trailing: const Icon(Icons.chevron_left_rounded, color: danger, size: 20),
    );
  }
}
