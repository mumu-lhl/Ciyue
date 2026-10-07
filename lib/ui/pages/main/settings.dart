import "dart:io";

import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/flashcards/settings.dart";
import "package:ciyue/ui/pages/settings/about.dart";
import "package:ciyue/ui/pages/settings/ai_settings.dart";
import "package:ciyue/ui/pages/settings/appearance.dart";
import "package:ciyue/ui/pages/settings/audio.dart";
import "package:ciyue/ui/pages/settings/backup.dart";
import "package:ciyue/ui/pages/settings/cloud_sync.dart";
import "package:ciyue/ui/pages/settings/history.dart";
import "package:ciyue/ui/pages/settings/hunspell.dart";
import "package:ciyue/ui/pages/settings/logs.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/ui/pages/settings/other.dart";
import "package:ciyue/ui/pages/settings/storage_management.dart";
import "package:ciyue/ui/pages/settings/update.dart";
import "package:ciyue/ui/pages/settings/wordbook_stats.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/storage_management.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

class AboutPageListTile extends StatelessWidget {
  const AboutPageListTile({super.key});

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
  const AppearanceSettingsPageListTile({super.key});

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

class CloudSyncPageListTile extends StatelessWidget {
  const CloudSyncPageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.cloud_sync),
      title: Text(AppLocalizations.of(context)!.cloudSync),
      onTap: () => context.push("/settings/cloud_sync"),
    );
  }
}

class BackupPageListTile extends StatelessWidget {
  const BackupPageListTile({super.key});

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
      },
    );
  }
}

class OtherPageListTile extends StatelessWidget {
  const OtherPageListTile({super.key});

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
    final totalWordCount = context.select(
      (WordbookModel vm) => vm.totalWordCount,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
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

enum _SettingsSection {
  wordbookStats,
  dictionaries,
  aiSettings,
  audio,
  manageStorage,
  appearance,
  history,
  flashcards,
  hunspell,
  backup,
  cloudSync,
  update,
  other,
  logs,
  about,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _SettingsSection _selectedSection = _SettingsSection.dictionaries;

  List<_SettingsItem> _getAvailableItems(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return [
      _SettingsItem(
        section: _SettingsSection.dictionaries,
        icon: Icons.book,
        title: locale?.manageDictionaries ?? "Dictionaries",
      ),
      _SettingsItem(
        section: _SettingsSection.aiSettings,
        icon: Icons.settings,
        title: locale?.aiSettings ?? "AI Settings",
      ),
      _SettingsItem(
        section: _SettingsSection.audio,
        icon: Icons.volume_up,
        title: locale?.audioSettings ?? "Audio",
      ),
      _SettingsItem(
        section: _SettingsSection.appearance,
        icon: Icons.palette,
        title: locale?.appearance ?? "Appearance",
      ),
      _SettingsItem(
        section: _SettingsSection.history,
        icon: Icons.update,
        title: locale?.history ?? "History",
      ),
      _SettingsItem(
        section: _SettingsSection.flashcards,
        icon: Icons.style,
        title: "Flashcards",
      ),
      _SettingsItem(
        section: _SettingsSection.hunspell,
        icon: Icons.spellcheck,
        title: "Hunspell",
      ),
      _SettingsItem(
        section: _SettingsSection.backup,
        icon: Icons.import_export,
        title: locale?.backup ?? "Backup",
      ),
      _SettingsItem(
        section: _SettingsSection.cloudSync,
        icon: Icons.cloud_sync,
        title: locale?.cloudSync ?? "Cloud Sync",
      ),
      _SettingsItem(
        section: _SettingsSection.wordbookStats,
        icon: Icons.bar_chart,
        title: locale?.wordbookStats ?? "Stats",
      ),
      if (Platform.isAndroid && !isFullFlavor())
        _SettingsItem(
          section: _SettingsSection.manageStorage,
          icon: Icons.sd_storage,
          title: locale?.manageStorage ?? "Manage Storage",
        ),
      _SettingsItem(
        section: _SettingsSection.update,
        icon: Icons.system_update,
        title: locale?.update ?? "Update",
      ),
      _SettingsItem(
        section: _SettingsSection.other,
        icon: Icons.more_horiz,
        title: locale?.other ?? "Other",
      ),
      _SettingsItem(
        section: _SettingsSection.logs,
        icon: Icons.receipt_long,
        title: locale?.logs ?? "Logs",
      ),
      _SettingsItem(
        section: _SettingsSection.about,
        icon: Icons.info,
        title: locale?.about ?? "About",
      ),
    ];
  }

  Widget _buildDetailWidget(_SettingsSection section) {
    switch (section) {
      case _SettingsSection.wordbookStats:
        return const WordbookStatsPage();
      case _SettingsSection.dictionaries:
        return const ManageDictionariesPage();
      case _SettingsSection.aiSettings:
        return const AiSettingsPage();
      case _SettingsSection.audio:
        return const AudioSettingsPage();
      case _SettingsSection.manageStorage:
        return ChangeNotifierProvider(
          create: (context) => StorageManagementViewModel(),
          child: const StorageManagementPage(),
        );
      case _SettingsSection.appearance:
        return const AppearanceSettingsPage();
      case _SettingsSection.history:
        return const HistorySettingsPage();
      case _SettingsSection.flashcards:
        return const FlashcardSettingsPage();
      case _SettingsSection.hunspell:
        return const HunspellSettingsPage();
      case _SettingsSection.backup:
        return const BackupSettingsPage();
      case _SettingsSection.cloudSync:
        return const CloudSyncSettingsPage();
      case _SettingsSection.update:
        return const UpdateSettingsPage();
      case _SettingsSection.other:
        return const OtherSettingsPage();
      case _SettingsSection.logs:
        return const LogsPage();
      case _SettingsSection.about:
        return const AboutSettingsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isLargeScreen(context)) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              const _WordbookStats(),
              const ManageDictionariesPageListTile(),
              const AiSettingsPageListTile(),
              const AudioSettingsPageListTile(),
              if (Platform.isAndroid && !isFullFlavor())
                const ManageStorageListTile(),
              const AppearanceSettingsPageListTile(),
              const HistoryPageListTile(),
              ListTile(
                leading: const Icon(Icons.style),
                title: const Text("Flashcards"),
                onTap: () => context.push("/settings/flashcards"),
              ),
              const HunspellPageListTile(),
              const BackupPageListTile(),
              const CloudSyncPageListTile(),
              const UpdatePageListTile(),
              const OtherPageListTile(),
              const LoggerPageListTile(),
              const AboutPageListTile(),
            ],
          ),
        ),
      );
    }

    final items = _getAvailableItems(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                child: Text(
                  AppLocalizations.of(context)!.settings,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: _WordbookStats(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = item.section == _selectedSection;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        selected: isSelected,
                        selectedTileColor: colorScheme.secondaryContainer,
                        selectedColor: colorScheme.onSecondaryContainer,
                        leading: Icon(
                          item.icon,
                          color: isSelected
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedSection = item.section;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(_selectedSection),
            child: _buildDetailWidget(_selectedSection),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final _SettingsSection section;
  final IconData icon;
  final String title;

  const _SettingsItem({
    required this.section,
    required this.icon,
    required this.title,
  });
}

class HunspellPageListTile extends StatelessWidget {
  const HunspellPageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.spellcheck),
      title: const Text("Hunspell"),
      onTap: () => context.push("/settings/hunspell"),
    );
  }
}

class ManageStorageListTile extends StatelessWidget {
  const ManageStorageListTile({super.key});

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
  const UpdatePageListTile({super.key});

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
