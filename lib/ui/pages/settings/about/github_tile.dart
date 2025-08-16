import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class GithubTile extends StatelessWidget {
  const GithubTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AboutViewModel>(context, listen: false);
    return ListTile(
        title: const Text("Github"),
        subtitle: const Text(AboutViewModel.githubUri),
        leading: const Icon(Icons.public),
        onTap: () => viewModel.launchUri(AboutViewModel.githubUri),
        onLongPress: () =>
            viewModel.copyToClipboard(context, AboutViewModel.githubUri));
  }
}
