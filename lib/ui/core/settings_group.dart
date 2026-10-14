import "package:material_ui/material_ui.dart";

/// A Material 3 grouped card for settings rows, matching the settings hub.
///
/// Rows are separated by hairline dividers aligned with the row titles.
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 52,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A padded Material 3 card for a single settings control, such as a text
/// field or a selection chip. Pair it with a [SettingsSectionLabel] or a
/// [TitleText] above it.
class SettingsFieldCard extends StatelessWidget {
  const SettingsFieldCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

/// A small section label placed above a [SettingsGroupCard], matching the
/// settings hub's group headers.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6, top: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
