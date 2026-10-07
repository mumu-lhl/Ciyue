import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "body.dart";
import "recommended.dart";

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeModelProvider.select((value) => value.state));
    ref.watch(dictManagerModelProvider.select((value) => value.isEmpty));

    final isNoDict = !dictManager.isLoading && dictManager.isEmpty;
    final content = isNoDict && !settings.aiExplainWord
        ? const RecommendedDictionaries()
        : const HomeBody();

    return content;
  }
}
