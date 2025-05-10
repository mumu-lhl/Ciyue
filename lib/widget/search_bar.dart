import "package:ciyue/pages/main/home.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

class WordSearchBarWithSuggestions extends StatelessWidget {
  final String word;
  final SearchController controller;
  final FocusNode? focusNode;
  final bool isHome;

  const WordSearchBarWithSuggestions({
    super.key,
    required this.word,
    required this.controller,
    this.focusNode,
    this.isHome = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SearchAnchor(
          viewHintText: AppLocalizations.of(context)!.search,
          builder: (context, controller) => SearchBar(
            focusNode: focusNode,
            controller: controller,
            hintText: AppLocalizations.of(context)!.search,
            constraints: const BoxConstraints(
                maxHeight: 42, minHeight: 42, maxWidth: 500),
            onTap: () => controller.openView(),
            onChanged: (_) => controller.openView(),
            leading: const Icon(Icons.search),
          ),
          searchController: controller..text = word,
          isFullScreen: !isLargeScreen(context),
          viewOnSubmitted: (String word) {
            if (controller.text.isNotEmpty) {
              context.push("/word", extra: {"word": word});
            }
          },
          suggestionsBuilder:
              (BuildContext context, SearchController controller) async {
            if (controller.text.isEmpty) {
              return [const SizedBox.shrink()];
            }

            final searchResult =
                await Searcher(controller.text).getSearchResult();

            if (settings.aiExplainWord) {
              searchResult.insert(0, controller.text);
            }

            return searchResult.map((e) => ListTile(
                  title: Text(e),
                  trailing: Icon(Icons.arrow_forward),
                  onTap: () {
                    context.push("/word", extra: {"word": e});
                    if (isHome && settings.autoRemoveSearchWord) {
                      controller.text = "";
                    }
                  },
                ));
          },
        ),
      ),
    );
  }
}
