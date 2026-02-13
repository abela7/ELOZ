import 'package:flutter/material.dart';
import '../theme/color_schemes.dart';
import '../theme/typography.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool? isDarkOverride;

  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.isDarkOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOverride ?? Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final headerColor = colorScheme.onSurfaceVariant;
    final containerColor = isDark
        ? colorScheme.surfaceContainerLow
        : colorScheme.surfaceContainerHighest;
    final borderColor = colorScheme.outlineVariant.withOpacity(isDark ? 0.4 : 0.6);
    final shadowColor = colorScheme.shadow.withOpacity(isDark ? 0.2 : 0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: headerColor,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.labelSmall(context).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: headerColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: child,
          ),
        ),
      ],
    );
  }
}

class SettingsToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final Color color;
  final ValueChanged<bool>? onChanged;
  final bool compact;

  const SettingsToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final isDisabled = onChanged == null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 0 : 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12)),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColorSchemes.primaryGold,
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const SettingsTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.45),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  color: AppColorSchemes.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}
