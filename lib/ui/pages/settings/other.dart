import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/startup.dart";
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
  FloatingWindowMode _mode = FloatingWindowMode.transparent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await _preferences.readMode();
    if (!mounted) return;
    setState(() => _mode = mode);
  }

  Future<void> _selectMode() async {
    final locale = AppLocalizations.of(context)!;
    final selected = await showDialog<FloatingWindowMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale.floatingWindowMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in FloatingWindowMode.values)
              ListTile(
                leading: Icon(
                  mode == _mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_modeLabel(locale, mode)),
                subtitle: Text(_modeDescription(locale, mode)),
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == _mode) return;
    await _preferences.writeMode(selected);
    if (!mounted) return;
    setState(() => _mode = selected);
  }

  String _modeLabel(AppLocalizations locale, FloatingWindowMode mode) =>
      switch (mode) {
        FloatingWindowMode.transparent => locale.floatingWindowModeTransparent,
        FloatingWindowMode.halfScreen => locale.floatingWindowModeHalfScreen,
        FloatingWindowMode.off => locale.floatingWindowModeOff,
      };

  String _modeDescription(AppLocalizations locale, FloatingWindowMode mode) =>
      switch (mode) {
        FloatingWindowMode.transparent =>
          locale.floatingWindowModeTransparentDescription,
        FloatingWindowMode.halfScreen =>
          locale.floatingWindowModeHalfScreenDescription,
        FloatingWindowMode.off => locale.floatingWindowModeOffDescription,
      };

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.window),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(locale.floatingWindow),
              const SizedBox(width: 8),
              const BaseBadge(text: "Beta"),
            ],
          ),
          subtitle: Text(_modeLabel(locale, _mode)),
          onTap: _selectMode,
        ),
      ],
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
                  if (isDesktop()) const LaunchAtStartupSwitch(),
                  if (Platform.isAndroid) ...[
                    const SecureScreenSwitch(),
                    const NotificationSwitch(),
                    const FloatingWindow(),
                  ],
                  const AdvanceSwitch(),
                ],
              ),
              if (isDesktop()) ...[
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
