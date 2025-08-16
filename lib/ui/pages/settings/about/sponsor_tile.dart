import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class SponsorListTile extends StatelessWidget {
  const SponsorListTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AboutViewModel>(context, listen: false);
    return ListTile(
        title: Text(AppLocalizations.of(context)!.sponsor),
        leading: const Icon(Icons.favorite),
        onTap: () => viewModel.showSponsorSheet(context),
        onLongPress: () =>
            viewModel.copyToClipboard(context, AboutViewModel.sponsorUri));
  }
}
