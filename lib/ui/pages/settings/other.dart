import "dart:async";
import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/desktop_selection_atspi.dart";
import "package:ciyue/services/global_hotkey.dart";
import "package:ciyue/services/lookup_hotkey.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/startup.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/services/floating_window_preferences.dart";
import "package:ciyue/ui/core/app_dropdown.dart";
import "package:ciyue/ui/core/badges.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:ciyue/ui/pages/settings/mouse_gesture_selectors.dart";
import "package:ciyue/utils.dart";
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:hotkey_manager/hotkey_manager.dart";

/// Whether the selection watcher the lookup bubble needs is available in
/// this session.
///
/// The bubble can only appear when something watches text selections in
/// other apps. The watcher exists on X11 (XFixes) and wherever AT-SPI2 is
/// available — and nowhere else, so on Windows/macOS the switch stays
/// disabled even though the hotkey above works there. On Wayland the switch
/// is only on when AT-SPI2 was actually probed available at startup.
/// (Wayland still has no focused-app resolver, so the exclusion list and
/// the own-app check cannot be enforced there; that gap belongs to the
/// bubble, not to this switch.)
@visibleForTesting
bool Function() isLookupBubbleWatcherAvailable = () =>
    AtSpiSelectionProvider.isAvailable ||
    (Platform.isLinux && !isWaylandSession());

/// Whether the bubble's "modifier key held" trigger can ever fire: only on
/// X11, where the modifier state comes from Lane A's helper. On Wayland and
/// every other platform the trigger never fires, so the option is hidden
/// from the trigger menu instead of offered and silently dead.
@visibleForTesting
bool Function() isLookupBubbleModifierTriggerAvailable = () =>
    Platform.isLinux && !isWaylandSession();

class FloatingWindow extends StatefulWidget {
  const FloatingWindow({super.key});

  @override
  State<FloatingWindow> createState() => _FloatingWindowState();
}

class _FloatingWindowState extends State<FloatingWindow> {
  final FloatingWindowPreferences _preferences = FloatingWindowPreferences();
  bool _enabled = true;
  FloatingWindowPanelFraction _fraction =
      FloatingWindowPanelFraction.defaultFraction;
  FloatingWindowPosition _position = FloatingWindowPosition.center;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final mode = await _preferences.readMode();
    final fraction = await _preferences.readPanelFraction();
    final position = await _preferences.readPosition();
    if (!mounted) return;
    setState(() {
      _enabled = mode != FloatingWindowMode.off;
      _fraction = fraction;
      _position = position;
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    await _preferences.writeMode(
      enabled ? FloatingWindowMode.transparent : FloatingWindowMode.off,
    );
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _setFraction(FloatingWindowPanelFraction fraction) async {
    floatingWindowPanelFraction.value = fraction;
    setState(() => _fraction = fraction);
    await _preferences.writePanelFraction(fraction);
  }

  Future<void> _setPosition(FloatingWindowPosition position) async {
    floatingWindowPosition.value = position;
    setState(() => _position = position);
    await _preferences.writePosition(position);
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.window),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(locale.floatingWindow),
              const SizedBox(width: 8),
              const BaseBadge(text: "Beta"),
            ],
          ),
          subtitle: Text(locale.floatingWindowSwitchDescription),
          value: _enabled,
          onChanged: _setEnabled,
        ),
        if (_enabled) ...[
          _PanelFractionSlider(
            icon: Icons.width_full,
            title: locale.floatingWindowCardWidth,
            value: _fraction.width,
            min: 0.4,
            max: 1.0,
            onChanged: (value) =>
                setState(() => _fraction = _fraction.copyWith(width: value)),
            onChangeEnd: (value) =>
                _setFraction(_fraction.copyWith(width: value)),
          ),
          _PanelFractionSlider(
            icon: Icons.height,
            title: locale.floatingWindowCardHeight,
            value: _fraction.height,
            min: 0.4,
            max: 1.0,
            onChanged: (value) =>
                setState(() => _fraction = _fraction.copyWith(height: value)),
            onChangeEnd: (value) =>
                _setFraction(_fraction.copyWith(height: value)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              locale.floatingWindowCardSizeHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          _PopupPositionTile(position: _position, onSelected: _setPosition),
        ],
      ],
    );
  }
}

/// Popup position row: shows the current direction and opens a nine-way menu.
///
/// The whole row is the tap target, so the menu is anchored to the row instead
/// of to a trailing [PopupMenuButton], which would only respond on its own
/// icon.
class _PopupPositionTile extends StatelessWidget {
  const _PopupPositionTile({required this.position, required this.onSelected});

  final FloatingWindowPosition position;
  final ValueChanged<FloatingWindowPosition> onSelected;

  static String label(
    AppLocalizations locale,
    FloatingWindowPosition position,
  ) => switch (position) {
    FloatingWindowPosition.topLeft => locale.floatingWindowPositionTopLeft,
    FloatingWindowPosition.topCenter => locale.floatingWindowPositionTopCenter,
    FloatingWindowPosition.topRight => locale.floatingWindowPositionTopRight,
    FloatingWindowPosition.centerLeft =>
      locale.floatingWindowPositionCenterLeft,
    FloatingWindowPosition.center => locale.floatingWindowPositionCenter,
    FloatingWindowPosition.centerRight =>
      locale.floatingWindowPositionCenterRight,
    FloatingWindowPosition.bottomLeft =>
      locale.floatingWindowPositionBottomLeft,
    FloatingWindowPosition.bottomCenter =>
      locale.floatingWindowPositionBottomCenter,
    FloatingWindowPosition.bottomRight =>
      locale.floatingWindowPositionBottomRight,
  };

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.open_with),
      title: Text(locale.floatingWindowPosition),
      subtitle: Text(locale.floatingWindowPositionHint),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label(locale, position)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
      onTap: () => _showMenu(context, locale),
    );
  }

  Future<void> _showMenu(BuildContext context, AppLocalizations locale) async {
    final row = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (row == null || overlay == null) return;

    final selected = await showMenu<FloatingWindowPosition>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          row.localToGlobal(Offset.zero, ancestor: overlay),
          row.localToGlobal(
            row.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final option in FloatingWindowPosition.values)
          CheckedPopupMenuItem(
            value: option,
            checked: option == position,
            child: Text(label(locale, option)),
          ),
      ],
    );
    if (selected != null) onSelected(selected);
  }
}

/// One percentage slider for the centred card. The value is previewed while
/// dragging and written to disk when the drag ends.
class _PanelFractionSlider extends StatelessWidget {
  const _PanelFractionSlider({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final percent = "${(value * 100).round()}%";
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: ((max - min) / 0.05).round(),
        label: percent,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
      trailing: Text(percent),
    );
  }
}

class NotificationSwitch extends StatefulWidget {
  const NotificationSwitch({super.key});

  @override
  State<NotificationSwitch> createState() => _NotificationSwitchState();
}

class OtherSettingsPage extends StatelessWidget {
  const OtherSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(locale.other)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              // See the Hunspell page: keep the last row clear of the navigation bar.
              bottom: 12 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              SettingsGroupCard(
                children: [
                  if (isDesktop()) ...[
                    const LaunchAtStartupSwitch(),
                    const EnableGlobalHotkeySwitch(),
                  ],
                  if (Platform.isAndroid) ...[
                    const SecureScreenSwitch(),
                    const NotificationSwitch(),
                    const FloatingWindow(),
                  ],
                ],
              ),
              if (isDesktop()) ...[
                const SizedBox(height: 16),
                SettingsSectionLabel(locale.lookupPopupSection),
                const SettingsGroupCard(children: [LookupPopupSettings()]),
              ],
              if (isDesktop() || Platform.isAndroid) ...[
                const SizedBox(height: 16),
                const SettingsGroupCard(children: [MouseGestureSelectors()]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SecureScreenSwitch extends StatefulWidget {
  const SecureScreenSwitch({super.key});

  @override
  State<SecureScreenSwitch> createState() => _SecureScreenSwitchState();
}

class _NotificationSwitchState extends State<NotificationSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.notification),
      value: settings.notification,
      onChanged: (value) async {
        await prefs.setBool("notification", value);
        setState(() {
          settings.notification = value;
        });
        await PlatformMethod.flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        await PlatformMethod.createPersistentNotification(value);
      },
      secondary: const Icon(Icons.notifications),
    );
  }
}

class _SecureScreenSwitchState extends State<SecureScreenSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.secureScreen),
      value: settings.secureScreen,
      onChanged: (value) async {
        await PlatformMethod.setSecureFlag(value);
        await prefs.setBool("secureScreen", value);
        setState(() {
          settings.secureScreen = value;
        });
      },
      secondary: const Icon(Icons.security),
    );
  }
}

class LaunchAtStartupSwitch extends StatefulWidget {
  const LaunchAtStartupSwitch({super.key});

  @override
  State<LaunchAtStartupSwitch> createState() => _LaunchAtStartupSwitchState();
}

class _LaunchAtStartupSwitchState extends State<LaunchAtStartupSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.launchAtStartup),
      value: settings.launchAtStartup,
      onChanged: (value) async {
        await settings.setLaunchAtStartup(value);
        await StartupService.setLaunchAtStartup(value);
        setState(() {});
      },
      secondary: const Icon(Icons.computer),
    );
  }
}

class EnableGlobalHotkeySwitch extends StatefulWidget {
  const EnableGlobalHotkeySwitch({super.key});

  @override
  State<EnableGlobalHotkeySwitch> createState() =>
      _EnableGlobalHotkeySwitchState();
}

class _EnableGlobalHotkeySwitchState extends State<EnableGlobalHotkeySwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final supported = GlobalHotkeyService.isSupported;

    return SwitchListTile(
      title: Text(locale.enableGlobalHotkey),
      subtitle: Text(
        supported
            ? locale.enableGlobalHotkeyDescription
            : locale.enableGlobalHotkeyWaylandUnsupported,
      ),
      value: supported && settings.enableGlobalHotkey,
      onChanged: supported
          ? (value) async {
              final applied = await GlobalHotkeyService.apply(value);
              if (!applied) {
                // Another program already owns the key: leave the saved value
                // alone so the switch stays where it was, and say why.
                if (context.mounted) {
                  await ToastService.show(
                    locale.globalHotkeyRegisterFailed,
                    context,
                    type: ToastType.error,
                  );
                }
                return;
              }
              await settings.setEnableGlobalHotkey(value);
              if (mounted) setState(() {});
            }
          : null,
      secondary: const Icon(Icons.keyboard),
    );
  }
}

class EnableLookupHotkeySwitch extends StatefulWidget {
  const EnableLookupHotkeySwitch({super.key});

  @override
  State<EnableLookupHotkeySwitch> createState() =>
      _EnableLookupHotkeySwitchState();
}

class _EnableLookupHotkeySwitchState extends State<EnableLookupHotkeySwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final supported = LookupHotkeyService.isSupported;

    return SwitchListTile(
      title: Text(locale.enableLookupHotkey),
      subtitle: Text(
        supported
            ? locale.enableLookupHotkeyDescription
            : locale.enableLookupHotkeyWaylandUnsupported,
      ),
      value: supported && settings.enableLookupHotkey,
      onChanged: supported
          ? (value) async {
              final applied = await LookupHotkeyService.apply(value);
              if (!applied) {
                // Another program already owns the key: leave the saved value
                // alone so the switch stays where it was, and say why.
                if (context.mounted) {
                  await ToastService.show(
                    locale.lookupHotkeyRegisterFailed,
                    context,
                    type: ToastType.error,
                  );
                }
                return;
              }
              await settings.setEnableLookupHotkey(value);
              if (mounted) setState(() {});
            }
          : null,
      secondary: const Icon(Icons.search),
    );
  }
}

/// The desktop "Lookup popup" section: the lookup shortcut and its chord,
/// the selection bubble, and the apps the popup stays silent for.
class LookupPopupSettings extends StatefulWidget {
  const LookupPopupSettings({super.key});

  @override
  State<LookupPopupSettings> createState() => _LookupPopupSettingsState();
}

class _LookupPopupSettingsState extends State<LookupPopupSettings> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final watcherAvailable = isLookupBubbleWatcherAvailable();
    final modifierTriggerAvailable = isLookupBubbleModifierTriggerAvailable();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const EnableLookupHotkeySwitch(),
        ListTile(
          key: const Key("lookupChangeShortcut"),
          leading: const Icon(Icons.keyboard),
          title: Text(locale.lookupHotkeyChangeShortcut),
          trailing: Text(
            LookupHotkeyService.formatChord(
              LookupHotkeyService.parseChord(settings.lookupHotkeyChord),
            ),
          ),
          onTap: LookupHotkeyService.isSupported
              ? () async {
                  await showDialog<HotKey>(
                    context: context,
                    builder: (context) => _LookupHotkeyCaptureDialog(
                      currentChord: LookupHotkeyService.parseChord(
                        settings.lookupHotkeyChord,
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                }
              : null,
        ),
        SwitchListTile(
          key: const Key("lookupBubbleSwitch"),
          secondary: const Icon(Icons.chat_bubble_outline),
          title: Text(locale.enableLookupBubble),
          subtitle: Text(
            watcherAvailable
                ? locale.enableLookupBubbleDescription
                : locale.enableLookupBubbleWaylandUnsupported,
          ),
          value: watcherAvailable && settings.enableLookupBubble,
          onChanged: watcherAvailable
              ? (value) async {
                  await settings.setEnableLookupBubble(value);
                  unawaited(restartLookupBubble());
                  if (mounted) setState(() {});
                }
              : null,
        ),
        if (watcherAvailable && settings.enableLookupBubble) ...[
          ListTile(
            leading: const Icon(Icons.touch_app),
            title: Text(locale.lookupBubbleTrigger),
            // The modifier trigger never fires off X11, so it is not
            // offered there: AppDropdown ignores DropdownMenuItem.enabled,
            // and a listed-but-dead option would only mislead.
            subtitle: modifierTriggerAvailable
                ? null
                : Text(locale.lookupBubbleTriggerModifierUnavailable),
            trailing: AppDropdown<String>(
              key: const Key("lookupBubbleTriggerDropdown"),
              value: settings.lookupBubbleTrigger,
              dense: true,
              items: [
                DropdownMenuItem(
                  value: "selection",
                  child: Text(locale.lookupBubbleTriggerSelection),
                ),
                if (modifierTriggerAvailable)
                  DropdownMenuItem(
                    value: "modifier",
                    child: Text(locale.lookupBubbleTriggerModifier),
                  ),
                DropdownMenuItem(
                  value: "doubleClick",
                  child: Text(locale.lookupBubbleTriggerDoubleClick),
                ),
              ],
              onChanged: (value) async {
                if (value == null) return;
                await settings.setLookupBubbleTrigger(value);
                unawaited(restartLookupBubble());
                if (mounted) setState(() {});
              },
            ),
          ),
          if (modifierTriggerAvailable &&
              settings.lookupBubbleTrigger == "modifier")
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: Text(locale.lookupBubbleModifier),
              trailing: AppDropdown<String>(
                key: const Key("lookupBubbleModifierDropdown"),
                value: settings.lookupBubbleModifier,
                dense: true,
                items: [
                  DropdownMenuItem(
                    value: "control",
                    child: Text(locale.lookupBubbleModifierControl),
                  ),
                  DropdownMenuItem(
                    value: "alt",
                    child: Text(locale.lookupBubbleModifierAlt),
                  ),
                  DropdownMenuItem(
                    value: "shift",
                    child: Text(locale.lookupBubbleModifierShift),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  await settings.setLookupBubbleModifier(value);
                  unawaited(restartLookupBubble());
                  if (mounted) setState(() {});
                },
              ),
            ),
        ],
        const _LookupExcludedAppsEditor(),
      ],
    );
  }
}

/// Edits the list of apps the lookup popup never triggers for.
class _LookupExcludedAppsEditor extends StatefulWidget {
  const _LookupExcludedAppsEditor();

  @override
  State<_LookupExcludedAppsEditor> createState() =>
      _LookupExcludedAppsEditorState();
}

class _LookupExcludedAppsEditorState extends State<_LookupExcludedAppsEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final entry = _controller.text.trim();
    if (entry.isEmpty) return;
    final apps = settings.lookupExcludedApps;
    if (apps.any((app) => app.toLowerCase() == entry.toLowerCase())) {
      _controller.clear();
      return;
    }
    await settings.setLookupExcludedApps([...apps, entry]);
    unawaited(restartLookupBubble());
    _controller.clear();
    if (mounted) setState(() {});
  }

  Future<void> _remove(String entry) async {
    await settings.setLookupExcludedApps(
      settings.lookupExcludedApps.where((app) => app != entry).toList(),
    );
    unawaited(restartLookupBubble());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final apps = settings.lookupExcludedApps;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.block),
          title: Text(locale.lookupExcludedApps),
          subtitle: Text(locale.lookupExcludedAppsDescription),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key("lookupExcludedAppField"),
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: locale.lookupExcludedAppsHint,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key("lookupExcludedAppAdd"),
                onPressed: _add,
                child: Text(locale.lookupExcludedAppsAdd),
              ),
            ],
          ),
        ),
        if (apps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final app in apps)
                  InputChip(
                    key: ValueKey("lookupExcludedApp-$app"),
                    label: Text(app),
                    onDeleted: () => _remove(app),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lets the user press a new lookup shortcut and save it.
///
/// Records the modifiers held plus the first non-modifier key pressed;
/// pure-modifier presses only update the live display. Escape cancels.
class _LookupHotkeyCaptureDialog extends StatefulWidget {
  const _LookupHotkeyCaptureDialog({required this.currentChord});

  final HotKey currentChord;

  @override
  State<_LookupHotkeyCaptureDialog> createState() =>
      _LookupHotkeyCaptureDialogState();
}

class _LookupHotkeyCaptureDialogState
    extends State<_LookupHotkeyCaptureDialog> {
  late HotKey _captured = widget.currentChord;
  bool _hasCapture = false;
  LookupHotkeyChordError? _error;

  static final _modifierPhysicalKeys = <PhysicalKeyboardKey>{
    for (final modifier in HotKeyModifier.values) ...modifier.physicalKeys,
  };

  // Fn and Caps Lock are not counted here: the platform layer drops them
  // when registering (see LookupHotkeyChordValidation), so showing them as
  // held would promise a chord that never takes effect.
  static const _modifierOrder = <HotKeyModifier>[
    HotKeyModifier.control,
    HotKeyModifier.meta,
    HotKeyModifier.alt,
    HotKeyModifier.shift,
  ];

  List<HotKeyModifier> _pressedModifiers() {
    final pressed = HardwareKeyboard.instance.physicalKeysPressed;
    return [
      for (final modifier in _modifierOrder)
        if (modifier.physicalKeys.any(pressed.contains)) modifier,
    ];
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Key repeats arrive as KeyRepeatEvent, so KeyDownEvent here is always
    // the first press.
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (_modifierPhysicalKeys.contains(event.physicalKey)) {
      // A modifier on its own is not a chord yet: wait for a real key, but
      // refresh the live display so the held modifiers show.
      setState(() {});
      return KeyEventResult.handled;
    }
    setState(() {
      _captured = HotKey(
        key: event.physicalKey,
        modifiers: _pressedModifiers(),
        scope: HotKeyScope.system,
      );
      _hasCapture = true;
      _error = null;
    });
    return KeyEventResult.handled;
  }

  String get _chordLine {
    if (_hasCapture) {
      return LookupHotkeyService.formatChord(_captured);
    }
    final held = _pressedModifiers();
    if (held.isEmpty) {
      return LookupHotkeyService.formatChord(widget.currentChord);
    }
    return "${LookupHotkeyService.formatModifiers(held)} + …";
  }

  String _errorText(AppLocalizations locale) => switch (_error!) {
    LookupHotkeyChordError.noModifier => locale.lookupHotkeyChordNoModifier,
    LookupHotkeyChordError.copyChord => locale.lookupHotkeyChordCopy,
    LookupHotkeyChordError.mainHotkeyConflict =>
      locale.lookupHotkeyChordConflict,
    LookupHotkeyChordError.unusableKey => locale.lookupHotkeyChordUnusableKey,
    LookupHotkeyChordError.droppedModifier =>
      locale.lookupHotkeyChordDroppedModifier,
    LookupHotkeyChordError.shiftOnlyLetter => locale.lookupHotkeyChordShiftOnly,
  };

  Future<void> _save() async {
    if (!_hasCapture) {
      // Nothing new pressed: keep the current chord.
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final locale = AppLocalizations.of(context)!;
    final error = LookupHotkeyChordValidation.validate(_captured);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final applied = await LookupHotkeyService.applyChord(
      _captured,
      settings.enableLookupHotkey,
    );
    if (!applied) {
      // The old chord stays registered; say why the new one did not take.
      if (mounted) {
        await ToastService.show(
          locale.lookupHotkeyRegisterFailed,
          context,
          type: ToastType.error,
        );
      }
      return;
    }
    await settings.setLookupHotkeyChord(jsonEncode(_captured.toJson()));
    if (mounted) Navigator.of(context).pop(_captured);
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(locale.lookupHotkeyCaptureTitle),
      content: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chordLine,
              key: const Key("lookupHotkeyCaptureChord"),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              locale.lookupHotkeyCaptureHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText(locale),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
