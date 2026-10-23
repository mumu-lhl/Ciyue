import "package:ciyue/core/providers.dart";
import "package:ciyue/services/changelog.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:go_router/go_router.dart";

class ChangelogDialog extends ConsumerWidget {
  const ChangelogDialog({
    super.key,
    required this.changelogContent,
    this.latestOnly = false,
  });

  final String changelogContent;

  /// True for the post-upgrade popup: show just the newest version's
  /// notes under a version title. False (the About page) shows the full
  /// history grouped by version, older versions collapsed.
  final bool latestOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final sections = ChangelogService.parseChangelogSections(changelogContent);

    Widget title = Text(localizations.changelog);
    Widget content;
    if (sections.isEmpty) {
      // Unparseable file: keep the previous whole-file rendering.
      content = SelectionArea(child: GptMarkdown(changelogContent));
    } else if (latestOnly) {
      final latest = sections.first;
      title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(localizations.changelog),
          const SizedBox(height: 2),
          Text(
            latest.date == null
                ? latest.version
                : "${latest.version} · ${latest.date}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
      content = SelectionArea(child: GptMarkdown(latest.body));
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sections.length; i++)
            ExpansionTile(
              title: Text(sections[i].version),
              subtitle: sections[i].date == null
                  ? null
                  : Text(sections[i].date!),
              initiallyExpanded: i == 0,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectionArea(child: GptMarkdown(sections[i].body)),
                ),
              ],
            ),
        ],
      );
    }

    return AlertDialog(
      title: title,
      content: SingleChildScrollView(child: content),
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
