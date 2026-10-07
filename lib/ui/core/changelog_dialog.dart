import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:go_router/go_router.dart";

class ChangelogDialog extends ConsumerWidget {
  const ChangelogDialog({super.key, required this.changelogContent});

  final String changelogContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.changelog),
      content: SingleChildScrollView(
        child: SelectionArea(child: GptMarkdown(changelogContent)),
      ),
      actions: [
        TextButton.icon(
          onPressed: () =>
              ref.read(aboutViewModelProvider).showSponsorSheet(context),
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
