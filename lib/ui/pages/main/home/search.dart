import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class BottomSearchBar extends ConsumerStatefulWidget {
  const BottomSearchBar({super.key});

  @override
  ConsumerState<BottomSearchBar> createState() => _BottomSearchBarState();
}

class _BottomSearchBarState extends ConsumerState<BottomSearchBar> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _waitForLoading();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(homeModelProvider.select((value) => value.state));

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (!settings.searchBarInAppBar || settings.aiExplainWord) {
      final isEmpty = ref.watch(
        dictManagerModelProvider.select((model) => model.isEmpty),
      );

      if (isEmpty && !settings.aiExplainWord) {
        return const SizedBox.shrink();
      }

      return const Padding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: 10, top: 10),
        child: HomeSearchBar(),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Future<void> _waitForLoading() async {
    while (dictManager.isLoading) {
      await Future.delayed(const Duration(milliseconds: 40));
    }

    setState(() {
      _isLoading = false;
    });
  }
}

class HomeSearchBar extends ConsumerWidget {
  final ValueChanged<String>? onWordSelected;

  const HomeSearchBar({super.key, this.onWordSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchWord = ref.watch(
      homeModelProvider.select((model) => model.searchWord),
    );
    final model = ref.read(homeModelProvider);

    return FocusScope(
      child: WordSearchBarWithSuggestions(
        word: searchWord,
        controller: model.searchController,
        focusNode: model.searchBarFocusNode,
        isHome: true,
        autoFocus: settings.autoFocusSearch,
        onWordSelected: onWordSelected,
      ),
    );
  }
}
