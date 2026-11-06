import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

/// The global navigation row used on wide landscape windows.
///
/// It replaces the vertical NavigationRail, so the whole window width is
/// available to the page. Only navigation and the global chat entry live
/// here: the dictionary-group switcher and the home options belong to the
/// word tab bar of the split view.
class HomeTopNavBar extends StatelessWidget implements PreferredSizeWidget {
  final int currentIndex;
  final List<(Icon, String)> destinations;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onToggleNavStyle;

  const HomeTopNavBar({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    this.onToggleNavStyle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // Four labels plus the chat button need room. A narrow large-screen
    // window keeps the icons and relies on their tooltips instead.
    final showLabels = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          if (onToggleNavStyle != null)
            IconButton(
              tooltip: l10n.switchToSideNavigation,
              icon: const Icon(Icons.swap_horiz),
              onPressed: onToggleNavStyle,
            )
          else
            const SizedBox(width: 8),
          for (var index = 0; index < destinations.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildDestination(context, index, showLabels),
            ),
          const Spacer(),
          IconButton(
            tooltip: l10n.aiChat,
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push("/chat"),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildDestination(BuildContext context, int index, bool showLabels) {
    final (icon, label) = destinations[index];
    final selected = index == currentIndex;
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onDestinationSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colorScheme.secondaryContainer : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon.icon, size: 20, color: foreground),
              if (showLabels) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
