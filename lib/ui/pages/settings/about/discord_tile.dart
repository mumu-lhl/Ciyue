import "package:ciyue/core/providers.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class DiscordTile extends ConsumerWidget {
  const DiscordTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aboutViewModelProvider);
    return ListTile(
      title: const Text("Discord"),
      subtitle: const Text(AboutViewModel.discordUri),
      leading: const Icon(Icons.discord),
      onTap: () => viewModel.launchUri(AboutViewModel.discordUri),
      onLongPress: () =>
          viewModel.copyToClipboard(context, AboutViewModel.discordUri),
    );
  }
}
