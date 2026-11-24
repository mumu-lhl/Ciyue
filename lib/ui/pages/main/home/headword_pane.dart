import "package:ciyue/models/search_mode.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/headword_pane.dart";
import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";

/// The split view's live headword list, drawn under the pane's search box.
///
/// It replaces the history list while the box has text: the same matches the
/// suggestion overlay would show, but as a list that stays on screen and can
/// be scrolled, with the ordering the search mode implies (headword order, or
/// reverse order for [SearchMode.suffix]) instead of by relevance.
class HeadwordPaneList extends StatelessWidget {
  const HeadwordPaneList({
    super.key,
    required this.model,
    required this.onWordSelected,
    this.onWordTertiarySelected,
  });

  final HeadwordPaneModel model;
  final ValueChanged<String> onWordSelected;
  final ValueChanged<String>? onWordTertiarySelected;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final statusTile = _statusTile(locale);
    final rows = model.rows;
    return ListView.builder(
      // A new query starts at the top of the new list instead of keeping the
      // offset of the previous one.
      key: ValueKey("${model.mode.name}:${model.text}"),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: rows.length + (statusTile == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (statusTile != null) {
          if (index == 0) return statusTile;
          index -= 1;
        }
        final row = rows[index];
        return Listener(
          onPointerDown: (event) {
            if (event.buttons == kTertiaryButton &&
                onWordTertiarySelected != null) {
              onWordTertiarySelected!(row.headword);
            }
          },
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(row.headword),
            subtitle: row.snippet == null
                ? null
                : Text(
                    row.snippet!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () => onWordSelected(row.headword),
          ),
        );
      },
    );
  }

  /// Why the list is empty in the modes that need the full-text index.
  ///
  /// Informational only: the overlay and the full-text page own the actions
  /// that build or retry an index, and duplicating them here would put two
  /// different build entry points in one screen.
  Widget? _statusTile(AppLocalizations locale) {
    if (model.mode == SearchMode.prefix) return null;
    return switch (model.indexStatus) {
      FullTextIndexStatus.ready => null,
      FullTextIndexStatus.building => ListTile(
        leading: const Icon(Icons.hourglass_top),
        title: Text(locale.buildingFullTextIndex),
      ),
      FullTextIndexStatus.failed => ListTile(
        leading: const Icon(Icons.warning),
        title: Text(locale.fullTextIndexFailed),
      ),
      FullTextIndexStatus.notBuilt => ListTile(
        leading: const Icon(Icons.hourglass_top),
        title: Text(locale.searchModeIndexNotBuilt),
      ),
    };
  }
}
