import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class DiscordTile extends StatelessWidget {
  const DiscordTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AboutViewModel>(context, listen: false);
    return ListTile(
        title: const Text("Discord"),
        subtitle: const Text(AboutViewModel.discordUri),
        leading: const Icon(Icons.discord),
        onTap: () => viewModel.launchUri(AboutViewModel.discordUri),
        onLongPress: () =>
            viewModel.copyToClipboard(context, AboutViewModel.discordUri));
  }
}
