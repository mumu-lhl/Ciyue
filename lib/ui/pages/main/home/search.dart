import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class BottomSearchBar extends StatelessWidget {
  const BottomSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<HomeModel, int>((value) => value.state);

    if (!settings.searchBarInAppBar) {
      return Selector<DictManagerModel, bool>(
          selector: (_, model) => model.isEmpty,
          builder: (_, isEmpty, __) {
            if (isEmpty) {
              return const SizedBox.shrink();
            }

            return const Padding(
                padding:
                    EdgeInsets.only(left: 20, right: 20, bottom: 10, top: 10),
                child: HomeSearchBar());
          });
    } else {
      return const SizedBox.shrink();
    }
  }
}

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final searchWord =
        context.select<HomeModel, String>((model) => model.searchWord);
    final model = context.read<HomeModel>();

    return FocusScope(
      child: WordSearchBarWithSuggestions(
        word: searchWord,
        controller: model.searchController,
        focusNode: model.searchBarFocusNode,
        isHome: true,
        autoFocus: settings.autoFocusSearch,
      ),
    );
  }
}

class Searcher {
  final String text;

  Searcher(this.text);

  Future<List<String>> getSearchResult() async {
    final searchers = <Future<List<String>>>[];
    for (final dict in dictManager.dicts.values) {
      searchers.add(dict.search(text));
    }

    final searchResult = [for (final i in await Future.wait(searchers)) ...i];
    searchResult.sort((a, b) => a.compareTo(b));

    final seen = <String>{};
    final deduped = <String>[];
    for (final s in searchResult) {
      if (seen.add(s)) {
        deduped.add(s);
      }
    }

    return deduped;
  }
}
