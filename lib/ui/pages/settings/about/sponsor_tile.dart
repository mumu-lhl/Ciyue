import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class SponsorListTile extends ConsumerWidget {
  const SponsorListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(aboutViewModelProvider);
    return ListTile(
      title: Text(AppLocalizations.of(context)!.sponsor),
      leading: const Icon(Icons.favorite),
      onTap: () => viewModel.showSponsorSheet(context),
      onLongPress: () =>
          viewModel.copyToClipboard(context, AboutViewModel.sponsorUri),
    );
  }
}
