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
class HeadwordPaneList extends StatefulWidget {
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
  State<HeadwordPaneList> createState() => _HeadwordPaneListState();
}

class _HeadwordPaneListState extends State<HeadwordPaneList> {
  /// No vertical padding: the rows are laid out at a fixed extent, and the
  /// reveal arithmetic below depends on row 0 starting at offset 0.
  static const _padding = EdgeInsets.symmetric(horizontal: 12);

  final ScrollController _scroll = ScrollController();

  /// The selection the list has already scrolled to, so a rebuild for an
  /// unrelated reason does not scroll again.
  int _revealed = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Fixed row height, so a row can be scrolled to without measuring it.
  ///
  /// Follows the text scale: the extent wins over the tile's intrinsic height,
  /// and a fixed 56 would clip large type.
  double _rowExtent(BuildContext context) {
    final base = widget.model.mode == SearchMode.fullText ? 72.0 : 56.0;
    return base * MediaQuery.textScalerOf(context).scale(1);
  }

  void _reveal(int index, double extent) {
    if (index < 0 || !_scroll.hasClients) return;
    final position = _scroll.position;
    final top = index * extent;
    final visibleTop = position.pixels;
    final visibleBottom = visibleTop + position.viewportDimension;
    final double? target;
    if (top < visibleTop) {
      target = top;
    } else if (top + extent > visibleBottom) {
      target = top + extent - position.viewportDimension;
    } else {
      target = null;
    }
    if (target == null) return;
    _scroll.animateTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final model = widget.model;
    final extent = _rowExtent(context);
    final selectedIndex = model.selectedIndex;
    if (selectedIndex != _revealed) {
      _revealed = selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(selectedIndex, extent);
      });
    }

    final rows = model.rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?_statusTile(locale),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            // A new query starts at the top of the new list instead of keeping
            // the offset of the previous one.
            key: ValueKey("${model.mode.name}:${model.text}"),
            itemExtent: extent,
            padding: _padding,
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Listener(
                onPointerDown: (event) {
                  if (event.buttons == kTertiaryButton &&
                      widget.onWordTertiarySelected != null) {
                    widget.onWordTertiarySelected!(row.headword);
                  }
                },
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: index == selectedIndex,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                  title: Text(row.headword),
                  subtitle: row.snippet == null
                      ? null
                      : Text(
                          row.snippet!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => widget.onWordSelected(row.headword),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Why the list is empty in the modes that need the full-text index.
  ///
  /// Informational only: the overlay and the full-text page own the actions
  /// that build or retry an index, and duplicating them here would put two
  /// different build entry points in one screen.
  Widget? _statusTile(AppLocalizations locale) {
    if (widget.model.mode == SearchMode.prefix) return null;
    return switch (widget.model.indexStatus) {
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
