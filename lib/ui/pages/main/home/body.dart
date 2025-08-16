import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "actions.dart";
import "history.dart";
import "search.dart";

class HomeBody extends StatelessWidget {
  const HomeBody({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    context.select<HomeModel, int>((value) => value.state);
    context.select<DictManagerModel, bool>((value) => value.isEmpty);

    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActionButtons(),
        HistoryLabel(),
        HistoryList(),
        BottomSearchBar(),
      ],
    );
  }
}
