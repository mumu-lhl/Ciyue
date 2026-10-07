import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class AboutPageListTile extends ConsumerWidget {
  const AboutPageListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aboutViewModelProvider);
    return AboutListTile(
      icon: const Icon(Icons.info),
      applicationName: viewModel.applicationName,
      applicationVersion: viewModel.applicationVersion,
      applicationLegalese: viewModel.applicationLegalese,
    );
  }
}
