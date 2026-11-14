import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/entry_pager.dart";
import "package:material_ui/material_ui.dart";

/// One "previous / next screen" button.
///
/// It carries no state of its own: the pager it drives reports its boundaries
/// through [EntryPager.bounds], so the button greys itself out at the start or
/// the end of whatever it pages. Without an explicit [pager] it talks to the
/// entry on screen; the history list passes its own so the same widget can
/// page a second scrollable.
class PagingButton extends StatelessWidget {
  /// Negative pages up, positive pages down.
  final int screens;

  /// The compact size used inside the mobile bottom bar.
  final bool compact;

  /// The list to page. Null means the entry on screen.
  final EntryPager? pager;

  const PagingButton({
    super.key,
    required this.screens,
    this.compact = false,
    this.pager,
  });

  /// The key the tests (and the mobile bar) use to find a button.
  static ValueKey<String> keyFor(int screens) =>
      ValueKey<String>(screens < 0 ? "paging-up" : "paging-down");

  @override
  Widget build(BuildContext context) {
    final target = pager;
    if (target != null) return _buildFor(context, target);

    return ValueListenableBuilder<EntryPager?>(
      valueListenable: activeEntryPager,
      builder: (context, active, child) {
        if (active == null) {
          return _buildButton(context, disabled: true, onPage: null);
        }
        return _buildFor(context, active);
      },
    );
  }

  Widget _buildFor(BuildContext context, EntryPager target) {
    return ValueListenableBuilder<PageBounds>(
      valueListenable: target.bounds,
      builder: (context, bounds, child) {
        final disabled = screens < 0 ? bounds.atStart : bounds.atEnd;
        return _buildButton(
          context,
          disabled: disabled,
          onPage: () => target.pageBy(screens),
        );
      },
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required bool disabled,
    required VoidCallback? onPage,
  }) {
    final locale = AppLocalizations.of(context)!;
    return IconButton(
      key: keyFor(screens),
      tooltip: screens < 0 ? locale.previousScreen : locale.nextScreen,
      icon: Icon(
        screens < 0
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
        size: compact ? 20 : 24,
      ),
      visualDensity: compact ? VisualDensity.compact : null,
      onPressed: disabled ? null : onPage,
    );
  }
}
