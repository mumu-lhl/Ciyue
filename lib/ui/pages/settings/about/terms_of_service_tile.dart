import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class TermsOfServicePageListTile extends StatelessWidget {
  const TermsOfServicePageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AboutViewModel>(context, listen: false);
    return ListTile(
      leading: const Icon(Icons.article),
      title: Text(AppLocalizations.of(context)!.termsOfService),
      onTap: () => viewModel.openTermsOfService(context),
    );
  }
}
