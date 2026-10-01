import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/appearance/theme_color_settings_section.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const _useDefaultColor = _UseDefaultColor();

class _UseDefaultColor {
  const _UseDefaultColor();
}

class DictionaryBackgroundColorNotifier extends Notifier<Color?> {
  @override
  Color? build() => settings.dictionaryBackgroundColor;

  Future<void> setColor(Color? color) async {
    await settings.setDictionaryBackgroundColor(color);
    state = color;
  }
}

final dictionaryBackgroundColorProvider =
    NotifierProvider<DictionaryBackgroundColorNotifier, Color?>(
      DictionaryBackgroundColorNotifier.new,
    );

class DictionaryBackgroundColor extends ConsumerWidget {
  const DictionaryBackgroundColor({super.key});

  static const _presetColors = <Color>[
    Color(0xFFFFFFFF), // Clean white
    Color(0xFFFAF7F0), // Soft ivory
    Color(0xFFF3EBDD), // Book paper
    Color(0xFFF1F5EE), // Pale sage
    Color(0xFFF0F4F8), // Mist blue
    Color(0xFFF5F1F7), // Soft lilac
    Color(0xFFF7F1EF), // Warm blush
    Color(0xFF292A2D), // Charcoal
  ];

  Future<void> _chooseColor(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations locale,
  ) async {
    final currentColor = ref.read(dictionaryBackgroundColorProvider);
    final selection = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locale.chooseDictionaryBackgroundColor,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in _presetColors)
                    _ColorSwatch(
                      color: color,
                      selected: currentColor?.toARGB32() == color.toARGB32(),
                      onTap: () => Navigator.pop(sheetContext, color),
                    ),
                  IconButton.filledTonal(
                    tooltip: locale.customColor,
                    onPressed: () async {
                      final color = await showAppearanceColorPicker(
                        context: sheetContext,
                        locale: locale,
                        initialColor: currentColor ?? const Color(0xFFFAF7F0),
                        title: locale.customColor,
                      );
                      if (sheetContext.mounted && color != null) {
                        Navigator.pop(sheetContext, color);
                      }
                    },
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, _useDefaultColor),
                  child: Text(locale.dictionaryBackgroundUseDefault),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selection == null) return;
    final color = selection == _useDefaultColor ? null : selection as Color;
    await ref.read(dictionaryBackgroundColorProvider.notifier).setColor(color);
    refreshAll();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final color = ref.watch(dictionaryBackgroundColorProvider);
    return ListTile(
      leading: const Icon(Icons.format_color_fill),
      title: Text(locale.dictionaryBackgroundColorTitle),
      subtitle: Text(locale.dictionaryBackgroundColorDescription),
      trailing: color == null
          ? null
          : Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
            ),
      onTap: () => _chooseColor(context, ref, locale),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
