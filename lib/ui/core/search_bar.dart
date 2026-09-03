import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/home.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

class WordSearchBarWithSuggestions extends StatefulWidget {
  final String word;
  final SearchController controller;
  final FocusNode? focusNode;
  final bool isHome;
  final bool autoFocus;

  const WordSearchBarWithSuggestions({
    super.key,
    required this.word,
    required this.controller,
    this.focusNode,
    this.isHome = false,
    this.autoFocus = false,
  });

  @override
  State<WordSearchBarWithSuggestions> createState() =>
      _WordSearchBarWithSuggestionsState();
}

class _WordSearchBarWithSuggestionsState
    extends State<WordSearchBarWithSuggestions> {
  @override
  void initState() {
    super.initState();
    widget.controller.text = widget.word;
  }

  @override
  void didUpdateWidget(covariant WordSearchBarWithSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.word != oldWidget.word) {
      widget.controller.text = widget.word;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SearchAnchor(
          viewHintText: AppLocalizations.of(context)!.search,
          builder: (context, controller) => SearchBar(
            autoFocus: widget.autoFocus,
            focusNode: widget.focusNode,
            controller: controller,
            hintText: AppLocalizations.of(context)!.search,
            constraints: const BoxConstraints(
              maxHeight: 42,
              minHeight: 42,
              maxWidth: 500,
            ),
            onTap: () => controller.openView(),
            onChanged: (_) => controller.openView(),
            leading: const Icon(Icons.search),
          ),
          searchController: widget.controller,
          isFullScreen: !isLargeScreen(context),
          viewOnSubmitted: (String word) {
            final normalizedWord = word.trim();
            if (normalizedWord.isNotEmpty) {
              context.read<HistoryModel>().addHistory(normalizedWord);
              context.push("/word/${Uri.encodeComponent(normalizedWord)}");
            }
          },
          suggestionsBuilder:
              (BuildContext context, SearchController controller) async {
                final searchWord = controller.text.trim();

                if (searchWord.isEmpty) {
                  return [const SizedBox.shrink()];
                }

                final suggestions = await dictionaryLookup.searchSuggestions(
                  searchWord,
                );
                if (!context.mounted) {
                  return const <Widget>[];
                }
                final l10n = AppLocalizations.of(context)!;

                ListTile buildSuggestionTile(String word) {
                  return ListTile(
                    title: Text(word),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      if (!context.mounted) return;
                      context.read<HistoryModel>().addHistory(word);
                      context.push("/word/${Uri.encodeComponent(word)}");

                      if (widget.isHome && settings.autoRemoveSearchWord) {
                        controller.text = "";
                      }
                    },
                  );
                }

                return [
                  if (settings.aiExplainWord) buildSuggestionTile(searchWord),
                  ...suggestions.dictionarySuggestions.map(buildSuggestionTile),
                  if (suggestions.spellingSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 16,
                        top: 10,
                        bottom: 5,
                      ),
                      child: Text(
                        l10n.spellingSuggestions,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ...suggestions.spellingSuggestions.map(buildSuggestionTile),
                ];
              },
        ),
      ),
    );
  }
}
