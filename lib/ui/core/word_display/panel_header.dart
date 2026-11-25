import "package:ciyue/repositories/settings.dart";
import "package:material_ui/material_ui.dart";

/// The header of one expansion panel, drawn according to [PanelHeaderStyle].
///
/// The header is Flutter UI rather than part of the entry's WebView, so the
/// dictionary's own CSS cannot reach it.
class ExpansionPanelHeader extends StatelessWidget {
  final String title;
  final PanelHeaderStyle style;

  const ExpansionPanelHeader({
    super.key,
    required this.title,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (style) {
      PanelHeaderStyle.plain => ListTile(title: Text(title)),
      PanelHeaderStyle.primaryText => ListTile(
        title: Text(title, style: TextStyle(color: scheme.primary)),
      ),
      PanelHeaderStyle.primaryBackground => ListTile(
        tileColor: scheme.primary,
        title: Text(title, style: TextStyle(color: scheme.onPrimary)),
      ),
    };
  }
}
