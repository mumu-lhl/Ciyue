import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

/// Lets the user zoom the dictionary entry content without a keyboard.
///
/// The same setting is reachable with `Ctrl`+=, `Ctrl`+- and `Ctrl`+0.
class ContentScaleSlider extends ConsumerWidget {
  const ContentScaleSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final scale = settings.contentScale;
    final percent = "${(scale * 100).round()}%";

    return ListTile(
      leading: const Icon(Icons.zoom_in),
      title: Text(locale.dictionaryContentScale),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(locale.dictionaryContentScaleDescription),
          Slider(
            value: scale,
            min: minContentScale,
            max: maxContentScale,
            divisions: 15,
            label: percent,
            // The value is previewed while the slider is dragged and only
            // written to the disk once the drag is over.
            onChanged: (value) => settings.previewContentScale(value),
            onChangeEnd: (value) async {
              await settings.setContentScale(value);
              refreshAll();
            },
          ),
        ],
      ),
      trailing: Text(percent),
    );
  }
}
