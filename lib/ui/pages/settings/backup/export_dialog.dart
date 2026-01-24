import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/backup/export_state.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class ExportOptionsDialog extends ConsumerWidget {
  const ExportOptionsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(exportOptionsProvider);
    final notifier = ref.read(exportOptionsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.export),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: Text(l10n.wordBook),
              value: options.wordbook,
              onChanged: (val) => notifier.toggleWordbook(val ?? false),
            ),
            CheckboxListTile(
              title: Text(l10n.history),
              value: options.searchHistory,
              onChanged: (val) => notifier.toggleSearchHistory(val ?? false),
            ),
            CheckboxListTile(
              title: Text(l10n.writingCheckHistory),
              value: options.writingCheckHistory,
              onChanged: (val) =>
                  notifier.toggleWritingCheckHistory(val ?? false),
            ),
            CheckboxListTile(
              title: Text(l10n.translationHistory),
              value: options.translateHistory,
              onChanged: (val) => notifier.toggleTranslateHistory(val ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(options),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
