import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class ChangelogPageListTile extends ConsumerWidget {
  const ChangelogPageListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aboutViewModelProvider);
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(AppLocalizations.of(context)!.changelog),
      onTap: () => viewModel.showChangelog(context),
    );
  }
}
