import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/global_hotkey.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/startup.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/services/floating_window_preferences.dart";
import "package:ciyue/ui/core/badges.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:ciyue/ui/pages/settings/mouse_gesture_selectors.dart";
import "package:ciyue/utils.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await _preferences.readMode();
    final fraction = await _preferences.readPanelFraction();
    if (!mounted) return;
    setState(() {
      _enabled = mode != FloatingWindowMode.off;
      _fraction = fraction;
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
            min: 0.5,
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
        ],
      ],
    );
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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.other)),
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
                  const AdvanceSwitch(),
                ],
              ),
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
        PlatformMethod.createPersistentNotification(value);
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
        PlatformMethod.setSecureFlag(value);
        await prefs.setBool("secureScreen", value);
        setState(() {
          settings.secureScreen = value;
        });
      },
      secondary: const Icon(Icons.security),
    );
  }
}

class AdvanceSwitch extends StatefulWidget {
  const AdvanceSwitch({super.key});

  @override
  State<AdvanceSwitch> createState() => _AdvanceSwitchState();
}

class _AdvanceSwitchState extends State<AdvanceSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.advance),
      subtitle: Text(locale.advanceSwitchDescription),
      value: settings.advance,
      onChanged: (value) async {
        await settings.setAdvance(value);
        setState(() {});
      },
      secondary: const Icon(Icons.settings),
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
