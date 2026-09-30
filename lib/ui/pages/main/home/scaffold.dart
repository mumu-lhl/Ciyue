import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:ciyue/viewModels/home.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

import "body.dart";
import "group_switcher.dart";
import "recommended.dart";

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<HomeModel, int>((value) => value.state);
    context.select<DictManagerModel, bool>((value) => value.isEmpty);

    final content = dictManager.isEmpty && !settings.aiExplainWord
        ? const RecommendedDictionaries()
        : const HomeBody();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeGroupSwitcher(),
        Expanded(child: content),
      ],
    );
  }
}
