import "package:ciyue/ui/pages/settings/about.dart";
import "package:flutter/material.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

class ChangelogDialog extends StatelessWidget {
  const ChangelogDialog({
    super.key,
    required this.changelogContent,
  });

  final String changelogContent;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.changelog),
      content: SingleChildScrollView(
        child: SelectionArea(
          child: GptMarkdown(
            changelogContent,
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            launchUrl(Uri.parse(SponsorUrl.sponsorUri));
            context.pop();
          },
          icon: const Icon(Icons.favorite),
          label: Text(AppLocalizations.of(context)!.sponsor),
        ),
        TextButton(
          onPressed: () => context.pop(),
          child: Text(AppLocalizations.of(context)!.close),
        ),
      ],
    );
  }
}
