import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/update_available.dart";
import "package:flutter/material.dart";

class UpdateSettingsPage extends StatelessWidget {
  const UpdateSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.update),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            children: const [
              AutoUpdateSwitch(),
              PrereleaseUpdatesSwitch(),
              CheckForUpdates(),
            ],
          ),
        ),
      ),
    );
  }
}

class AutoUpdateSwitch extends StatefulWidget {
  const AutoUpdateSwitch({super.key});

  @override
  State<AutoUpdateSwitch> createState() => _AutoUpdateSwitchState();
}

class _AutoUpdateSwitchState extends State<AutoUpdateSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.autoUpdate),
      value: settings.autoUpdate,
      onChanged: (value) {
        settings.setAutoUpdate(value);
        setState(() {});
      },
      secondary: const Icon(Icons.autorenew),
    );
  }
}

class PrereleaseUpdatesSwitch extends StatefulWidget {
  const PrereleaseUpdatesSwitch({super.key});

  @override
  State<PrereleaseUpdatesSwitch> createState() =>
      _PrereleaseUpdatesSwitchState();
}

class _PrereleaseUpdatesSwitchState extends State<PrereleaseUpdatesSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.includePrerelease),
      value: settings.includePrereleaseUpdates,
      onChanged: (value) async {
        await prefs.setBool("includePrereleaseUpdates", value);
        setState(() {
          settings.includePrereleaseUpdates = value;
        });
      },
      secondary: const Icon(Icons.settings_suggest_outlined),
    );
  }
}

class CheckForUpdates extends StatelessWidget {
  const CheckForUpdates({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: const Icon(Icons.update),
        title: Text(AppLocalizations.of(context)!.checkForUpdates),
        onTap: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.checkingForUpdates),
            ),
          );

          final update = await Updater.check();
          if (!update.success) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(AppLocalizations.of(context)!.updateCheckFailed),
                ),
              );
            }
          }
          if (update.isUpdateAvailable) {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (context) => UpdateAvailable(update: update),
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(AppLocalizations.of(context)!.noUpdateAvailable),
                ),
              );
            }
          }
        });
  }
}
