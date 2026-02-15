import "dart:io";

import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

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

class LoggerPageListTile extends StatelessWidget {
  const LoggerPageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.receipt_long),
      title: Text(AppLocalizations.of(context)!.logs),
      onTap: () => context.push("/settings/logs"),
    );
  }
}

class _WordbookStats extends StatelessWidget {
  const _WordbookStats();

  @override
  Widget build(BuildContext context) {
    final totalWordCount =
        context.select((WordbookModel vm) => vm.totalWordCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push("/settings/wordbook_stats"),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.totalWordsInWordbook,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  totalWordCount.toString(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _WordbookStats(),
        const ManageDictionariesPageListTile(),
        const AiSettingsPageListTile(),
        const AudioSettingsPageListTile(),
        if (Platform.isAndroid) const ManageStorageListTile(),
        const AppearanceSettingsPageListTile(),
        const HistoryPageListTile(),
        const BackupPageListTile(),
        const UpdatePageListTile(),
        const OtherPageListTile(),
        const LoggerPageListTile(),
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
      title: Text(AppLocalizations.of(context)!.audioSettings),
      onTap: () => context.push("/settings/audio"),
    );
  }
}
