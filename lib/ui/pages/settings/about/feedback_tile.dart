import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class FeedbackTile extends StatelessWidget {
  const FeedbackTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AboutViewModel>(context, listen: false);
    return ListTile(
        title: Text(AppLocalizations.of(context)!.feedback),
        subtitle: const Text(AboutViewModel.feedbackUri),
        leading: const Icon(Icons.feedback),
        onTap: () => viewModel.launchUri(AboutViewModel.feedbackUri),
        onLongPress: () =>
            viewModel.copyToClipboard(context, AboutViewModel.feedbackUri));
  }
}
