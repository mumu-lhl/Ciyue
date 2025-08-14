import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/startup.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/badges.dart";
import "package:ciyue/utils.dart";
import "package:flutter/material.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:path_provider/path_provider.dart";

class FloatingWindow extends StatefulWidget {
  const FloatingWindow({super.key});

  @override
  State<FloatingWindow> createState() => _FloatingWindowState();
}

class _FloatingWindowState extends State<FloatingWindow> {
  bool _isFloatingWindowEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkFloatingWindowStatus();
  }

  Future<File> _getDisableFloatingWindowFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File("${directory.path}/disable_floating_window");
  }

  Future<void> _checkFloatingWindowStatus() async {
    final file = await _getDisableFloatingWindowFile();
    final exists = await file.exists();
    setState(() {
      _isFloatingWindowEnabled = !exists;
    });
  }

  Future<void> _toggleFloatingWindow(bool value) async {
    final file = await _getDisableFloatingWindowFile();
    if (value) {
      if (await file.exists()) {
        await file.delete();
      }
    } else {
      if (!await file.exists()) {
        await file.create();
      }
    }
    setState(() {
      _isFloatingWindowEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.window),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.floatingWindow),
          const SizedBox(width: 8),
          const BaseBadge(
            text: "Beta",
          ),
        ],
      ),
      value: _isFloatingWindowEnabled,
      onChanged: _toggleFloatingWindow,
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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.other),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
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
                AndroidFlutterLocalNotificationsPlugin>()
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
