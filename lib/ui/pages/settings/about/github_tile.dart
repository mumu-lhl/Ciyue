import "package:ciyue/core/providers.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class GithubTile extends ConsumerWidget {
  const GithubTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aboutViewModelProvider);
    return ListTile(
      title: const Text("Github"),
      subtitle: const Text(AboutViewModel.githubUri),
      leading: const Icon(Icons.public),
      onTap: () => viewModel.launchUri(AboutViewModel.githubUri),
      onLongPress: () =>
          viewModel.copyToClipboard(context, AboutViewModel.githubUri),
    );
  }
}
