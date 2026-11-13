import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/entry_pager.dart";
import "package:material_ui/material_ui.dart";

/// One "previous / next screen" button.
///
/// It carries no state of its own: the active pager is shared through
/// [activeEntryPager], and each pager reports its boundaries through
/// [EntryPager.bounds], so both the mobile bottom bar and the desktop toolbar
/// grey the button out at the start or the end of the entry.
class PagingButton extends StatelessWidget {
  /// Negative pages up, positive pages down.
  final int screens;

  /// The compact size used inside the mobile bottom bar.
  final bool compact;

  /// Whether the button also spells out its direction.
  final bool showLabel;

  const PagingButton({
    super.key,
    required this.screens,
    this.compact = false,
    this.showLabel = false,
  });

  /// The key the tests (and the mobile bar) use to find a button.
  static ValueKey<String> keyFor(int screens) =>
      ValueKey<String>(screens < 0 ? "paging-up" : "paging-down");

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EntryPager?>(
      valueListenable: activeEntryPager,
      builder: (context, pager, child) {
        if (pager == null) {
          return _buildButton(context, disabled: true);
        }
        return ValueListenableBuilder<PageBounds>(
          valueListenable: pager.bounds,
          builder: (context, bounds, child) {
            return _buildButton(
              context,
              disabled: screens < 0 ? bounds.atStart : bounds.atEnd,
            );
          },
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, {required bool disabled}) {
    final locale = AppLocalizations.of(context)!;
    final label = screens < 0 ? locale.previousScreen : locale.nextScreen;
    final icon = Icon(
      screens < 0
          ? Icons.keyboard_arrow_up_rounded
          : Icons.keyboard_arrow_down_rounded,
      size: compact ? 20 : 24,
    );
    final onPressed = disabled ? null : () => pageActiveEntry(screens);

    if (!showLabel) {
      return IconButton(
        key: keyFor(screens),
        tooltip: label,
        icon: icon,
        visualDensity: compact ? VisualDensity.compact : null,
        onPressed: onPressed,
      );
    }

    return TextButton.icon(
      key: keyFor(screens),
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
    );
  }
}

/// The full-width paging bar shown under an entry that has no bottom bar of
/// its own (the desktop layouts).
///
/// It draws no shadow and no ripple: on an e-ink panel both only add
/// ghosting. The bar hides itself while no entry pager is on screen.
class EInkPageBar extends StatelessWidget {
  const EInkPageBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EntryPager?>(
      valueListenable: activeEntryPager,
      builder: (context, pager, child) {
        if (pager == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.35,
                    ),
                    width: 0.8,
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(child: PagingButton(screens: -1, showLabel: true)),
                  Expanded(child: PagingButton(screens: 1, showLabel: true)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Builds the bottom bar of an entry page.
///
/// The caller may already pass a bottom bar (the mobile browser passes the
/// Chrome-style bar, which carries the paging buttons itself); that bar is
/// returned unchanged so the buttons never appear twice. Otherwise the e-ink
/// bar is stacked above the bottom search box, and a screen with neither
/// keeps no bottom bar at all.
Widget? buildEntryBottomBar({
  required bool eInkMode,
  required Widget? existing,
  required Widget? searchBar,
}) {
  if (existing != null) return existing;
  final bottomSearchBar = searchBar == null
      ? null
      : BottomAppBar(child: searchBar);
  if (!eInkMode) return bottomSearchBar;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [const EInkPageBar(), ?bottomSearchBar],
  );
}
