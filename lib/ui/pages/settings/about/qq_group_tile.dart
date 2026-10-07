import "package:ciyue/core/providers.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class QQGroupTile extends ConsumerWidget {
  const QQGroupTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aboutViewModelProvider);
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
