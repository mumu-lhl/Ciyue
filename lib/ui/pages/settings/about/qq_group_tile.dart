import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class QQGroupTile extends StatelessWidget {
  const QQGroupTile({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AboutViewModel>(context, listen: false);
    return ListTile(
      leading: const Icon(Icons.group),
      title: const Text("QQ"),
      subtitle: const Text(AboutViewModel.qqGroupNumber),
      onTap: () =>
          viewModel.copyToClipboard(context, AboutViewModel.qqGroupNumber),
      onLongPress: () =>
          viewModel.copyToClipboard(context, AboutViewModel.qqGroupNumber),
    );
  }
}
