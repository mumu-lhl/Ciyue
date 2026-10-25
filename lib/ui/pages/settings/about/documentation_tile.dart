import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class DocumentationTile extends ConsumerWidget {
  const DocumentationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aboutViewModelProvider);
    return ListTile(
      title: Text(AppLocalizations.of(context)!.documentation),
      subtitle: const Text(AboutViewModel.docsUri),
      leading: const Icon(Icons.menu_book_outlined),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () => viewModel.launchUri(AboutViewModel.docsUri),
      onLongPress: () =>
          viewModel.copyToClipboard(context, AboutViewModel.docsUri),
    );
  }
}
