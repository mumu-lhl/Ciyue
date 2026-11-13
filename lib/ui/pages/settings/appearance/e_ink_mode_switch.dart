import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

/// Turns the app into an e-ink reader: motion is switched off everywhere and
/// the entry pages can be paged a screen at a time.
///
/// Colour is deliberately left alone here. Modern e-ink panels are colour
/// panels, so the mode must not force a black-and-white palette; it only
/// removes the repaints an e-ink panel cannot show cleanly.
class EInkModeSwitch extends ConsumerWidget {
  const EInkModeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final isEnabled = ref.watch(
      settingsProvider.select((settings) => settings.eInkMode),
    );

    return SwitchListTile(
      secondary: const Icon(Icons.menu_book_outlined),
      title: Text(locale.eInkMode),
      subtitle: Text(locale.eInkModeDescription),
      value: isEnabled,
      onChanged: (value) async {
        await ref.read(settingsProvider).setEInkMode(value);
        refreshAll();
      },
    );
  }
}
