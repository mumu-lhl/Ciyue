import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

class BottomSearchBar extends StatefulWidget {
  const BottomSearchBar({super.key});

  @override
  State<BottomSearchBar> createState() => _BottomSearchBarState();
}

class _BottomSearchBarState extends State<BottomSearchBar> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _waitForLoading();
  }

  @override
  Widget build(BuildContext context) {
    context.select<HomeModel, int>((value) => value.state);

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (!settings.searchBarInAppBar || settings.aiExplainWord) {
      context.read<DictManagerModel>().checkIsEmpty();

      return Selector<DictManagerModel, bool>(
        selector: (_, model) => model.isEmpty,
        builder: (_, isEmpty, _) {
          if (isEmpty && !settings.aiExplainWord) {
            return const SizedBox.shrink();
          }

          return const Padding(
            padding: EdgeInsets.only(left: 20, right: 20, bottom: 10, top: 10),
            child: HomeSearchBar(),
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Future<void> _waitForLoading() async {
    while (dictManager.isLoading) {
      await Future.delayed(Duration(milliseconds: 40));
    }

    setState(() {
      _isLoading = false;
    });
  }
}

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final searchWord = context.select<HomeModel, String>(
      (model) => model.searchWord,
    );
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
