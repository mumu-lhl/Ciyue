import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";

const _useDefaultColor = _UseDefaultColor();

class _UseDefaultColor {
  const _UseDefaultColor();
}

class DictionaryBackgroundColor extends StatelessWidget {
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
    AppLocalizations locale,
  ) async {
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
                      selected:
                          settings.dictionaryBackgroundColor?.toARGB32() ==
                          color.toARGB32(),
                      onTap: () => Navigator.pop(sheetContext, color),
                    ),
                  IconButton.filledTonal(
                    tooltip: locale.customColor,
                    onPressed: () async {
                      final color = await showDialog<Color>(
                        context: sheetContext,
                        builder: (dialogContext) =>
                            _HexColorDialog(locale: locale),
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
    await settings.setDictionaryBackgroundColor(
      selection == _useDefaultColor ? null : selection as Color,
    );
    refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final color = settings.dictionaryBackgroundColor;
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
      onTap: () => _chooseColor(context, locale),
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

class _HexColorDialog extends StatefulWidget {
  final AppLocalizations locale;

  const _HexColorDialog({required this.locale});

  @override
  State<_HexColorDialog> createState() => _HexColorDialogState();
}

class _HexColorDialogState extends State<_HexColorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final current = settings.dictionaryBackgroundColor;
    _controller = TextEditingController(
      text: current == null
          ? "#F5F0E6"
          : "#${(current.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, "0").toUpperCase()}",
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.locale.customColor),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Hex",
            hintText: "#F5F0E6",
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final hex = value?.replaceFirst("#", "") ?? "";
            return RegExp(r"^[0-9a-fA-F]{6}$").hasMatch(hex)
                ? null
                : widget.locale.invalidHexColor;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.locale.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final hex = _controller.text.replaceFirst("#", "");
            Navigator.pop(
              context,
              Color(0xFF000000 | int.parse(hex, radix: 16)),
            );
          },
          child: Text(widget.locale.save),
        ),
      ],
    );
  }
}
