import "dart:math" as math;

import "package:material_ui/material_ui.dart";

/// A Material 3 dropdown replacing the stock DropdownButton across the app.
///
/// The button keeps the site's layout (a bordered field with an optional
/// label, or a compact pill when [dense]), while the popup menu is shared:
/// a rounded surfaceContainerHigh card with the selected item marked by a
/// check, opening with a short fade + scale + slide animation.
///
/// The currently selected label reuses the matching [DropdownMenuItem.child],
/// so swapping a stock dropdown over is mechanical.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.prefixIcon,
    this.dense = false,
  });

  /// The currently selected value; may be null when an item carries a
  /// null value (e.g. a "Default" entry).
  final T? value;

  /// The menu entries. Each item's [DropdownMenuItem.child] is reused as
  /// the row label, and its [DropdownMenuItem.value] as the result.
  final List<DropdownMenuItem<T>> items;

  /// Called with the tapped item's value (null when the tapped item
  /// carries a null value, e.g. a "Default" entry); null disables the
  /// control. This mirrors the stock DropdownButton's `ValueChanged<T?>`.
  final ValueChanged<T?>? onChanged;

  /// Small label rendered inside the field, like a text field's label.
  final String? label;

  /// Optional leading icon inside the field.
  final Widget? prefixIcon;

  /// Compact borderless pill (for ListTile trailing slots).
  final bool dense;

  DropdownMenuItem<T>? get _selectedItem {
    for (final item in items) {
      if (item.value == value) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final disabled = onChanged == null;
    final selectedLabel = _selectedItem?.child ?? const SizedBox.shrink();
    final chevron = Icon(
      Icons.keyboard_arrow_down_rounded,
      size: 20,
      color: colors.onSurfaceVariant,
    );

    final Widget button = dense
        ? Material(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: disabled ? null : () => _openMenu(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: selectedLabel),
                    const SizedBox(width: 2),
                    chevron,
                  ],
                ),
              ),
            ),
          )
        : Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: disabled ? null : () => _openMenu(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (prefixIcon != null) ...[
                      IconTheme(
                        data: IconThemeData(color: colors.onSurfaceVariant),
                        child: prefixIcon!,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: label == null
                          ? selectedLabel
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label!,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                selectedLabel,
                              ],
                            ),
                    ),
                    const SizedBox(width: 8),
                    chevron,
                  ],
                ),
              ),
            ),
          );

    return Opacity(opacity: disabled ? 0.5 : 1, child: button);
  }

  void _openMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    Navigator.of(context).push(
      _AppDropdownRoute<T>(
        buttonRect: rect,
        items: items,
        value: value,
        onSelected: (selected) => onChanged?.call(selected),
        dismissLabel: MaterialLocalizations.of(context)
            .modalBarrierDismissLabel,
      ),
    );
  }
}

class _MenuGeometry {
  const _MenuGeometry({required this.rect, required this.opensDownward});

  static const double itemHeight = 48;
  static const double verticalPadding = 6;
  static const double gap = 8;
  static const double screenMargin = 8;
  static const double minWidth = 240;

  final Rect rect;
  final bool opensDownward;

  static _MenuGeometry resolve(Size screen, Rect buttonRect, int itemCount) {
    final contentHeight = itemCount * itemHeight + verticalPadding * 2;
    final menuHeight = math.min(contentHeight, screen.height * 0.55);
    final menuWidth = math.min(
      math.max(buttonRect.width, minWidth),
      screen.width - screenMargin * 2,
    );
    final left = math.max(
      screenMargin,
      math.min(buttonRect.left, screen.width - screenMargin - menuWidth),
    );
    final spaceBelow = screen.height - buttonRect.bottom - gap - screenMargin;
    final spaceAbove = buttonRect.top - gap - screenMargin;
    final opensDownward = spaceBelow >= menuHeight || spaceBelow >= spaceAbove;
    final top = opensDownward
        ? buttonRect.bottom + gap
        : buttonRect.top - gap - menuHeight;
    return _MenuGeometry(
      rect: Rect.fromLTWH(left, top, menuWidth, menuHeight),
      opensDownward: opensDownward,
    );
  }
}

class _AppDropdownRoute<T> extends PopupRoute<void> {
  _AppDropdownRoute({
    required this.buttonRect,
    required this.items,
    required this.value,
    required this.onSelected,
    required this.dismissLabel,
  });

  final Rect buttonRect;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?> onSelected;
  final String dismissLabel;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => dismissLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final geometry = _MenuGeometry.resolve(
      MediaQuery.sizeOf(context),
      buttonRect,
      items.length,
    );
    return Stack(
      children: [
        Positioned.fromRect(
          rect: geometry.rect,
          child: _MenuCard(items: items, value: value, onSelected: onSelected),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final geometry = _MenuGeometry.resolve(
      MediaQuery.sizeOf(context),
      buttonRect,
      items.length,
    );
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * (geometry.opensDownward ? 6 : -6)),
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              alignment: geometry.opensDownward
                  ? Alignment.topCenter
                  : Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _MenuCard<T> extends StatelessWidget {
  const _MenuCard({
    required this.items,
    required this.value,
    required this.onSelected,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: _MenuGeometry.verticalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items)
                _MenuRow(
                  item: item,
                  selected: item.value == value,
                  onTap: () {
                    onSelected(item.value);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DropdownMenuItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _MenuGeometry.itemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: colors.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: DefaultTextStyle(
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: selected ? colors.primary : colors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    child: item.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
