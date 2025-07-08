import "dart:io";

import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/core/alpha_text.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

class AboutPageListTile extends StatelessWidget {
  const AboutPageListTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info),
      title: Text(AppLocalizations.of(context)!.about),
      onTap: () => context.push("/settings/about"),
    );
  }
}

class AiSettingsPageListTile extends StatelessWidget {
  const AiSettingsPageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.settings),
      title: Text(AppLocalizations.of(context)!.aiSettings),
      onTap: () => context.push("/settings/ai_settings"),
    );
  }
}

class AppearanceSettingsPageListTile extends StatelessWidget {
  const AppearanceSettingsPageListTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette),
      title: Text(AppLocalizations.of(context)!.appearance),
      onTap: () => context.push("/settings/appearance"),
    );
  }
}

class AudioSettingsPageListTile extends StatefulWidget {
  const AudioSettingsPageListTile({super.key});

  @override
  State<AudioSettingsPageListTile> createState() =>
      _AudioSettingsPageListTileState();
}

class BackupPageListTile extends StatelessWidget {
  const BackupPageListTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.import_export),
      title: Text(AppLocalizations.of(context)!.backup),
      onTap: () => context.push("/settings/backup"),
    );
  }
}

class HistoryPageListTile extends StatelessWidget {
  const HistoryPageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.update),
      title: Text(AppLocalizations.of(context)!.history),
      onTap: () => context.push("/settings/history"),
    );
  }
}

class ManageDictionariesPageListTile extends StatelessWidget {
  const ManageDictionariesPageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return ListTile(
        leading: const Icon(Icons.book),
        title: Text(locale!.manageDictionaries),
        onTap: () async {
          await context.push("/settings/dictionaries");
        });
  }
}

class OtherPageListTile extends StatelessWidget {
  const OtherPageListTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.more_horiz),
      title: Text(AppLocalizations.of(context)!.other),
      onTap: () => context.push("/settings/other"),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ManageDictionariesPageListTile(),
        const AiSettingsPageListTile(),
        const AudioSettingsPageListTile(),
        if (Platform.isAndroid) const ManageStorageListTile(),
        const AppearanceSettingsPageListTile(),
        const HistoryPageListTile(),
        const BackupPageListTile(),
        const UpdatePageListTile(),
        const OtherPageListTile(),
        const AboutPageListTile(),
      ],
    );
  }
}

class ManageStorageListTile extends StatelessWidget {
  const ManageStorageListTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.sd_storage),
      title: Text(AppLocalizations.of(context)!.manageStorage),
      onTap: () => context.push("/settings/storage_management"),
    );
  }
}

class UpdatePageListTile extends StatelessWidget {
  const UpdatePageListTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.update),
      title: Text(AppLocalizations.of(context)!.update),
      onTap: () => context.push("/settings/update"),
    );
  }
}

class _AudioSettingsPageListTileState extends State<AudioSettingsPageListTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.volume_up),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.audioSettings),
          const SizedBox(width: 8),
          AlphaText(),
        ],
      ),
      onTap: () => context.push("/settings/audio"),
    );
  }
}
