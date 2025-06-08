import "dart:io";

import "package:ciyue/main.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/core/alpha_text.dart";
import "package:flutter/material.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:permission_handler/permission_handler.dart";

class FloatingWindow extends StatefulWidget {
  const FloatingWindow({super.key});

  @override
  State<FloatingWindow> createState() => _FloatingWindowState();
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
      body: ListView(
        children: [
          if (Platform.isAndroid) ...[
            const SecureScreenSwitch(),
            const NotificationSwitch(),
            const FloatingWindow(),
          ],
          const AdvanceSwitch(),
        ],
      ),
    );
  }
}

class SecureScreenSwitch extends StatefulWidget {
  const SecureScreenSwitch({super.key});

  @override
  State<SecureScreenSwitch> createState() => _SecureScreenSwitchState();
}

class _FloatingWindowState extends State<FloatingWindow> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.window),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.floatingWindow),
          const SizedBox(width: 8),
          AlphaText(),
        ],
      ),
      onTap: () async {
        await Permission.systemAlertWindow.request();
      },
    );
  }
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
