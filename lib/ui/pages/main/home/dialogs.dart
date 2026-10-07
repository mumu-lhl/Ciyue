import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/tags_list.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

class AddHistoryToWordbookDialog extends ConsumerWidget {
  final List<WordbookTag> tags;

  final List<int> tagsOfWord;
  final List<int> toAdd;
  final List<int> toDel;
  final HistoryData item;
  const AddHistoryToWordbookDialog({
    super.key,
    required this.tags,
    required this.tagsOfWord,
    required this.toAdd,
    required this.toDel,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.tags),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TagsList(
            tags: tags,
            tagsOfWord: tagsOfWord,
            toAdd: toAdd,
            toDel: toDel,
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text(AppLocalizations.of(context)!.close),
          onPressed: () {
            context.pop(false);
          },
        ),
        TextButton(
          child: Text(AppLocalizations.of(context)!.remove),
          onPressed: () async {
            await ref
                .read(wordbookModelProvider)
                .removeWordWithAllTags(item.word);
            if (context.mounted) {
              context.pop(true);
              ref.read(wordbookModelProvider).updateWordList();
            }
          },
        ),
        TextButton(
          child: Text(AppLocalizations.of(context)!.confirm),
          onPressed: () async {
            if (!await wordbookDao.wordExist(item.word)) {
              if (!context.mounted) return;
              await ref.read(wordbookModelProvider).add(item.word);
            }

            if (!context.mounted) return;

            for (final tag in toAdd) {
              await ref.read(wordbookModelProvider).add(item.word, tag: tag);
            }

            if (!context.mounted) return;

            for (final tag in toDel) {
              await ref.read(wordbookModelProvider).delete(item.word, tag: tag);
            }

            if (context.mounted) {
              context.pop(true);
            }
          },
        ),
      ],
    );
  }
}

class MoreOptionsDialog extends ConsumerStatefulWidget {
  const MoreOptionsDialog({super.key});

  @override
  ConsumerState<MoreOptionsDialog> createState() => _MoreOptionsDialogState();
}

class _MoreOptionsDialogState extends ConsumerState<MoreOptionsDialog> {
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(AppLocalizations.of(context)!.more),
      children: [
        SimpleDialogOption(
          child: CheckboxListTile(
            value: settings.autoRemoveSearchWord,
            onChanged: (value) async {
              if (value != null) {
                settings.autoRemoveSearchWord = value;
                await prefs.setBool("autoRemoveSearchWord", value);
                if (mounted) ref.read(homeModelProvider).update();
                setState(() {});
              }
            },
            title: Text(AppLocalizations.of(context)!.autoRemoveSearchWord),
          ),
        ),
        SimpleDialogOption(
          child: CheckboxListTile(
            value: settings.autoFocusSearch,
            onChanged: (value) async {
              if (value != null) {
                settings.autoFocusSearch = value;
                await prefs.setBool("autoFocusSearch", value);
                if (mounted) ref.read(homeModelProvider).update();
                setState(() {});
              }
            },
            title: Text(AppLocalizations.of(context)!.autoFocusSearch),
          ),
        ),
      ],
    );
  }
}
