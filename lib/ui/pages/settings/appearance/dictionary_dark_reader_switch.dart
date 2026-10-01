import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/appearance/dictionary_background_color.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class DictionaryDarkReaderSwitch extends ConsumerWidget {
  const DictionaryDarkReaderSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final isEnabled = ref.watch(dictionaryDarkReaderProvider);
    final hasCustomBackground =
        ref.watch(dictionaryBackgroundColorProvider) != null;

    return SwitchListTile(
      secondary: const Icon(Icons.dark_mode_outlined),
      title: Text(locale.dictionaryDarkReaderTitle),
      subtitle: Text(
        hasCustomBackground
            ? locale.dictionaryDarkReaderNeedsDefaultBackground
            : locale.dictionaryDarkReaderDescription,
      ),
      value: isEnabled,
      onChanged: hasCustomBackground
          ? null
          : (value) async {
              await ref
                  .read(dictionaryDarkReaderProvider.notifier)
                  .setEnabled(value);
              refreshAll();
            },
    );
  }
}
