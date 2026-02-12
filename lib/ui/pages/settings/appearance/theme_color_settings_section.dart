import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class ThemeColorSettingsState {
  final bool dynamicColorEnabled;
  final Color seedColor;

  const ThemeColorSettingsState({
    required this.dynamicColorEnabled,
    required this.seedColor,
  });

  ThemeColorSettingsState copyWith({
    bool? dynamicColorEnabled,
    Color? seedColor,
  }) {
    return ThemeColorSettingsState(
      dynamicColorEnabled: dynamicColorEnabled ?? this.dynamicColorEnabled,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

class ThemeColorSettingsNotifier extends Notifier<ThemeColorSettingsState> {
  @override
  ThemeColorSettingsState build() {
    return ThemeColorSettingsState(
      dynamicColorEnabled: settings.enableDynamicColor,
      seedColor: settings.themeSeedColor,
    );
  }

  void setDynamicColorEnabled(bool value) {
    state = state.copyWith(dynamicColorEnabled: value);
  }

  void setSeedColor(Color color) {
    state = state.copyWith(seedColor: color);
  }
}

final themeColorSettingsProvider =
    NotifierProvider<ThemeColorSettingsNotifier, ThemeColorSettingsState>(
  ThemeColorSettingsNotifier.new,
);

enum _ColorMode { hsv, rgb }

class ThemeColorSettingsSection extends ConsumerWidget {
  const ThemeColorSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final themeSettings = ref.watch(themeColorSettingsProvider);
    final dynamicColorEnabled = themeSettings.dynamicColorEnabled;
    final themeSeedColor = themeSettings.seedColor;

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.dynamic_form_outlined),
          title: Text(locale.dynamicColor),
          subtitle: Text(locale.dynamicColorDescription),
          value: dynamicColorEnabled,
          onChanged: (value) async {
            ref
                .read(themeColorSettingsProvider.notifier)
                .setDynamicColorEnabled(value);
            await settings.setEnableDynamicColor(value);
            refreshAll();
          },
        ),
        if (!dynamicColorEnabled)
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(locale.appThemeColor),
            subtitle: Text(_toHex(themeSeedColor)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: themeSeedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
            onTap: () async {
              final Color? selectedColor = await _showThemeColorPicker(
                context,
                locale,
                themeSeedColor,
              );
              if (selectedColor == null) {
                return;
              }

              ref
                  .read(themeColorSettingsProvider.notifier)
                  .setSeedColor(selectedColor);
              await settings.setThemeSeedColor(selectedColor);
              refreshAll();
            },
          ),
      ],
    );
  }

  String _toHex(Color color) {
    final value = color.toARGB32().toRadixString(16).padLeft(8, "0");
    return "#${value.substring(2).toUpperCase()}";
  }

  Future<Color?> _showThemeColorPicker(
    BuildContext context,
    AppLocalizations locale,
    Color currentColor,
  ) {
    const presetColors = <Color>[
      Color(0xFF2196F3),
      Color(0xFF1E88E5),
      Color(0xFF0D47A1),
      Color(0xFF26A69A),
      Color(0xFF00ACC1),
      Color(0xFF43A047),
      Color(0xFF7CB342),
      Color(0xFFC0CA33),
      Color(0xFFFFC107),
      Color(0xFFF4511E),
      Color(0xFFFF7043),
      Color(0xFFE53935),
      Color(0xFFD81B60),
      Color(0xFF8E24AA),
      Color(0xFF5E35B1),
      Color(0xFF00897B),
      Color(0xFF6D4C41),
      Color(0xFF546E7A),
      Color(0xFF3949AB),
      Color(0xFF111827),
    ];

    return showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale.chooseThemeColor,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: presetColors
                      .map(
                        (color) => _ColorDot(
                          color: color,
                          selected: color.toARGB32() == currentColor.toARGB32(),
                          onTap: () => Navigator.of(sheetContext).pop(color),
                        ),
                      )
                      .toList(growable: false),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final Color? customColor = await showDialog<Color>(
                        context: sheetContext,
                        builder: (dialogContext) => _CustomColorDialog(
                          locale: locale,
                          initialColor: currentColor,
                        ),
                      );
                      if (!sheetContext.mounted || customColor == null) {
                        return;
                      }

                      Navigator.of(sheetContext).pop(customColor);
                    },
                    icon: const Icon(Icons.tune),
                    label: Text(locale.customColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

class _CustomColorDialog extends StatefulWidget {
  final AppLocalizations locale;
  final Color initialColor;

  const _CustomColorDialog({
    required this.locale,
    required this.initialColor,
  });

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late HSVColor hsvColor;
  _ColorMode colorMode = _ColorMode.hsv;

  @override
  void initState() {
    super.initState();
    hsvColor = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final Color currentColor = hsvColor.toColor();

    return AlertDialog(
      title: Text(widget.locale.customThemeColor),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(_toHex(currentColor)),
              ],
            ),
            const SizedBox(height: 12),
            _SaturationValuePalette(
              hsvColor: hsvColor,
              onChanged: (color) => setState(() => hsvColor = color),
            ),
            const SizedBox(height: 10),
            _HueStrip(
              hue: hsvColor.hue,
              onChanged: (hue) =>
                  setState(() => hsvColor = hsvColor.withHue(hue)),
            ),
            const SizedBox(height: 10),
            SegmentedButton<_ColorMode>(
              segments: const [
                ButtonSegment<_ColorMode>(
                  value: _ColorMode.hsv,
                  label: Text("HSV"),
                ),
                ButtonSegment<_ColorMode>(
                  value: _ColorMode.rgb,
                  label: Text("RGB"),
                ),
              ],
              selected: {colorMode},
              onSelectionChanged: (modes) {
                if (modes.isEmpty) {
                  return;
                }
                setState(() => colorMode = modes.first);
              },
            ),
            const SizedBox(height: 8),
            if (colorMode == _ColorMode.hsv) ...[
              _ColorSlider(
                label: "H",
                value: hsvColor.hue,
                max: 360,
                onChanged: (value) =>
                    setState(() => hsvColor = hsvColor.withHue(value)),
              ),
              _ColorSlider(
                label: "S",
                value: hsvColor.saturation * 100,
                max: 100,
                onChanged: (value) => setState(
                    () => hsvColor = hsvColor.withSaturation(value / 100)),
              ),
              _ColorSlider(
                label: "V",
                value: hsvColor.value * 100,
                max: 100,
                onChanged: (value) =>
                    setState(() => hsvColor = hsvColor.withValue(value / 100)),
              ),
            ] else ...[
              _ColorSlider(
                label: "R",
                value: _channelValue(currentColor.r).toDouble(),
                max: 255,
                onChanged: (value) => setState(() {
                  final Color rgb = Color.fromARGB(
                    255,
                    value.round(),
                    _channelValue(currentColor.g),
                    _channelValue(currentColor.b),
                  );
                  hsvColor = HSVColor.fromColor(rgb);
                }),
              ),
              _ColorSlider(
                label: "G",
                value: _channelValue(currentColor.g).toDouble(),
                max: 255,
                onChanged: (value) => setState(() {
                  final Color rgb = Color.fromARGB(
                    255,
                    _channelValue(currentColor.r),
                    value.round(),
                    _channelValue(currentColor.b),
                  );
                  hsvColor = HSVColor.fromColor(rgb);
                }),
              ),
              _ColorSlider(
                label: "B",
                value: _channelValue(currentColor.b).toDouble(),
                max: 255,
                onChanged: (value) => setState(() {
                  final Color rgb = Color.fromARGB(
                    255,
                    _channelValue(currentColor.r),
                    _channelValue(currentColor.g),
                    value.round(),
                  );
                  hsvColor = HSVColor.fromColor(rgb);
                }),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.locale.close),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(currentColor),
          child: Text(widget.locale.confirm),
        ),
      ],
    );
  }

  String _toHex(Color color) {
    final String value = color.toARGB32().toRadixString(16).padLeft(8, "0");
    return "#${value.substring(2).toUpperCase()}";
  }

  int _channelValue(double channel) {
    return (channel * 255).round().clamp(0, 255);
  }
}

class _SaturationValuePalette extends StatelessWidget {
  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onChanged;

  const _SaturationValuePalette({
    required this.hsvColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final markerLeft = hsvColor.saturation * width;
          final markerTop = (1 - hsvColor.value) * height;

          return GestureDetector(
            onPanDown: (details) =>
                _updateFromPosition(details.localPosition, width, height),
            onPanUpdate: (details) =>
                _updateFromPosition(details.localPosition, width, height),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: HSVColor.fromAHSV(1, hsvColor.hue, 1, 1).toColor(),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.transparent],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (markerLeft - 8).clamp(0.0, width - 16),
                    top: (markerTop - 8).clamp(0.0, height - 16),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateFromPosition(Offset localPosition, double width, double height) {
    final saturation = (localPosition.dx / width).clamp(0.0, 1.0);
    final value = (1 - localPosition.dy / height).clamp(0.0, 1.0);
    onChanged(hsvColor.withSaturation(saturation).withValue(value));
  }
}

class _HueStrip extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueStrip({
    required this.hue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final markerLeft = hue / 360 * width;

          return GestureDetector(
            onPanDown: (details) =>
                _updateFromPosition(details.localPosition, width),
            onPanUpdate: (details) =>
                _updateFromPosition(details.localPosition, width),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (markerLeft - 2).clamp(0.0, width - 4),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black54),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateFromPosition(Offset localPosition, double width) {
    final double hueValue = (localPosition.dx / width * 360).clamp(0.0, 360.0);
    onChanged(hueValue);
  }
}

class _ColorSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  const _ColorSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 18, child: Text(label)),
        Expanded(
          child: Slider(
            min: 0,
            max: max,
            value: value.clamp(0, max),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
