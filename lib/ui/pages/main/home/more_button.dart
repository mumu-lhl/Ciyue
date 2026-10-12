import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class MoreButton extends ConsumerWidget {
  const MoreButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(homeModelProvider.select((m) => m.state));

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: PopupMenuButton<String>(
        tooltip: l10n.more,
        icon: const Icon(Icons.more_vert_rounded),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (value) async {
          if (value == "autoRemoveSearchWord") {
            settings.autoRemoveSearchWord = !settings.autoRemoveSearchWord;
            await prefs.setBool(
              "autoRemoveSearchWord",
              settings.autoRemoveSearchWord,
            );
            ref.read(homeModelProvider).update();
          } else if (value == "autoFocusSearch") {
            settings.autoFocusSearch = !settings.autoFocusSearch;
            await prefs.setBool("autoFocusSearch", settings.autoFocusSearch);
            ref.read(homeModelProvider).update();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: "autoRemoveSearchWord",
            child: Row(
              children: [
                Icon(
                  settings.autoRemoveSearchWord
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: settings.autoRemoveSearchWord
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.autoRemoveSearchWord)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: "autoFocusSearch",
            child: Row(
              children: [
                Icon(
                  settings.autoFocusSearch
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: settings.autoFocusSearch
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.autoFocusSearch)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
