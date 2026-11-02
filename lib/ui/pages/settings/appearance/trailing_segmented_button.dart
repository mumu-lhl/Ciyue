import "package:material_ui/material_ui.dart";

/// A segmented button for the trailing slot of a list tile.
///
/// A list tile hands its title whatever space the trailing widget leaves
/// over. A button whose labels grow with the translation takes that space
/// away, and a language that writes long words without spaces — Gothic, for
/// one — then ends up with a single character per line in the title.
///
/// The icon goes above the label and the label is allowed to wrap, so the
/// button is only as wide as its icons need and the text stays readable
/// instead of being cut off.
class TrailingSegmentedButton<T> extends StatelessWidget {
  const TrailingSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.labelWidth = 48,
    this.maxWidth = 200,
    this.showSelectedIcon = false,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  /// How wide the text of a single segment may grow before it wraps.
  final double labelWidth;

  /// How wide the whole button may grow.
  final double maxWidth;

  final bool showSelectedIcon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SegmentedButton<T>(
        segments: [
          for (final segment in segments)
            ButtonSegment(value: segment.value, label: _stacked(segment)),
        ],
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        showSelectedIcon: showSelectedIcon,
      ),
    );
  }

  /// The icon on top, the text below it, wrapping rather than being cut off.
  Widget _stacked(ButtonSegment<T> segment) {
    final label = segment.label;
    final icon = segment.icon;
    if (label is! Text) {
      return label ?? const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?icon,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: labelWidth),
          child: Text(
            label.data ?? "",
            style: label.style,
            textAlign: TextAlign.center,
            softWrap: true,
          ),
        ),
      ],
    );
  }
}
