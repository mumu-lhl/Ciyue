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

                final searchResult = [
                  ...await dictionaryLookup.searchSuggestions(searchWord),
                ];

                if (settings.aiExplainWord) {
                  searchResult.insert(0, searchWord);
                }

                return searchResult.map(
                  (e) => ListTile(
                    title: Text(e),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      context.read<HistoryModel>().addHistory(e);
                      context.push("/word/${Uri.encodeComponent(e)}");

                      if (widget.isHome && settings.autoRemoveSearchWord) {
                        controller.text = "";
                      }
                    },
                  ),
                );
              },
        ),
      ),
    );
  }
}
