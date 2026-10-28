import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:ciyue/ui/core/update_available.dart";
import "package:material_ui/material_ui.dart";

class UpdateSettingsPage extends StatelessWidget {
  const UpdateSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.update)),
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
            children: const [
              SettingsGroupCard(
                children: [
                  AutoUpdateSwitch(),
                  PrereleaseUpdatesSwitch(),
                  CheckForUpdates(),
                ],
              ),
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
    return ListTile(
      title: Text(locale!.updateChannel),
      subtitle: Text(_channelDisplayName(settings.updateChannel, locale)),
      trailing: DropdownButton<UpdateChannel>(
        value: settings.updateChannel,
        underline: const SizedBox.shrink(),
        onChanged: (channel) async {
          if (channel == null) return;
          await settings.setUpdateChannel(channel);
          if (Updater.supportsDesktopUpdates) {
            await Updater.resetDesktopController();
          }
          setState(() {});
        },
        items: UpdateChannel.values.map((channel) {
          return DropdownMenuItem(
            value: channel,
            child: Text(_channelDisplayName(channel, locale)),
          );
        }).toList(),
      ),
      leading: const Icon(Icons.settings_suggest_outlined),
    );
  }

  String _channelDisplayName(UpdateChannel channel, AppLocalizations locale) {
    switch (channel) {
      case UpdateChannel.stable:
        return locale.updateChannelStable;
      case UpdateChannel.preview:
        return locale.updateChannelPreview;
      case UpdateChannel.nightly:
        return locale.updateChannelNightly;
    }
  }
}

class CheckForUpdates extends StatelessWidget {
  const CheckForUpdates({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.update),
      title: Text(AppLocalizations.of(context)!.checkForUpdates),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () async {
        if (Updater.supportsDesktopUpdates) {
          await Updater.checkDesktopForUpdates(context);
          return;
        }

        ToastService.show(
          AppLocalizations.of(context)!.checkingForUpdates,
          context,
          type: ToastType.waiting,
        );

        final update = await Updater.check();
        if (!update.success) {
          if (context.mounted) {
            ToastService.show(
              AppLocalizations.of(context)!.updateCheckFailed,
              context,
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
            ToastService.show(
              AppLocalizations.of(context)!.noUpdateAvailable,
              context,
            );
          }
        }
      },
    );
  }
}
