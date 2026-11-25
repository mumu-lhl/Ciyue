import "package:ciyue/repositories/settings.dart";
import "package:material_ui/material_ui.dart";

/// The header of one expansion panel, drawn according to [PanelHeaderStyle]
/// and [PanelHeaderAlignment].
///
/// The header is Flutter UI rather than part of the entry's WebView, so the
/// dictionary's own CSS cannot reach it.
class ExpansionPanelHeader extends StatelessWidget {
  final String title;
  final PanelHeaderStyle style;
  final PanelHeaderAlignment alignment;

  const ExpansionPanelHeader({
    super.key,
    required this.title,
    required this.style,
    this.alignment = PanelHeaderAlignment.left,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = switch (style) {
      PanelHeaderStyle.plain => null,
      PanelHeaderStyle.primaryText => TextStyle(color: scheme.primary),
      PanelHeaderStyle.tintedBackground => TextStyle(
        color: scheme.onSecondaryContainer,
      ),
    };
    Widget label = Text(title, style: titleStyle);
    if (alignment == PanelHeaderAlignment.right) {
      label = Align(alignment: Alignment.centerRight, child: label);
    }
    return ListTile(
      tileColor: style == PanelHeaderStyle.tintedBackground
          ? scheme.secondaryContainer
          : null,
      title: label,
    );
  }
}
