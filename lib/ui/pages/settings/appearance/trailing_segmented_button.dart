import "package:material_ui/material_ui.dart";

/// A segmented button for the trailing slot of a list tile.
///
/// A list tile hands its title whatever space the trailing widget leaves
/// over, and a button whose labels grow with the translation takes that
/// space away. The title is then left so narrow that it breaks into a single
/// character per line, which happened with the Gothic translation and, for a
/// two-character title such as the Chinese 主题, with the default one as
/// well.
///
/// A segmented button does not shrink, so the button falls back to what fits:
/// the labels next to their icons, the labels alone, and finally the icons
/// alone with the wording in a tooltip.
class TrailingSegmentedButton<T> extends StatelessWidget {
  const TrailingSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    required this.availableWidth,
    this.showSelectedIcon = false,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  /// The width the list tile has, so that the button can tell what fits.
  final double availableWidth;

  final bool showSelectedIcon;

  /// The leading icon, the gaps and the padding of the list tile take their
  /// part of the width first, and the title keeps the rest.
  double get _budget => (availableWidth - 88) * 0.75;

  @override
  Widget build(BuildContext context) {
    if (_neededWidth(context, withIcons: true) <= _budget) {
      return _button(context, withIcons: true);
    }
    if (_neededWidth(context, withIcons: false) <= _budget) {
      return _button(context, withIcons: false);
    }
    // Even the labels alone do not fit, so the icons carry the meaning and
    // the wording waits for the tooltip.
    return _button(context, withIcons: false, iconsOnly: true);
  }

  Widget _button(
    BuildContext context, {
    required bool withIcons,
    bool iconsOnly = false,
  }) {
    return SegmentedButton<T>(
      segments: [
        for (final segment in segments)
          ButtonSegment(
            value: segment.value,
            icon: withIcons ? segment.icon : null,
            // The icon goes into the label, because a segment that has no
            // label of its own does not draw one.
            label: iconsOnly ? _iconWithTooltip(segment) : _onOneLine(segment),
          ),
      ],
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      showSelectedIcon: showSelectedIcon,
    );
  }

  /// The width the segments ask for, with the size the button gives its
  /// labels.
  double _neededWidth(BuildContext context, {required bool withIcons}) {
    var needed = 0.0;
    for (final segment in segments) {
      final label = segment.label;
      if (label is! Text) return double.infinity;
      final painter = TextPainter(
        text: TextSpan(
          text: label.data ?? "",
          style: (label.style ?? const TextStyle()).copyWith(fontSize: 14),
        ),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      // The icon, the gap next to it and the padding of the segment.
      needed +=
          painter.width + (withIcons && segment.icon != null ? 32 : 0) + 12;
    }
    return needed;
  }

  /// Keeps a label on one line, so that a long translation cannot widen the
  /// button it sits in.
  Widget? _onOneLine(ButtonSegment<T> segment) {
    final label = segment.label;
    if (label is! Text) return label;
    return Text(
      label.data ?? "",
      style: label.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget? _iconWithTooltip(ButtonSegment<T> segment) {
    final icon = segment.icon;
    if (icon == null) return const Text("");
    final label = segment.label;
    return Tooltip(
      message: label is Text ? (label.data ?? "") : "",
      child: icon,
    );
  }
}
