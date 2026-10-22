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
import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";

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

class _WordbookStats extends ConsumerWidget {
  const _WordbookStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalWordCount = ref.watch(
      wordbookModelProvider.select((vm) => vm.totalWordCount),
    );
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push("/settings/wordbook_stats"),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.totalWordsInWordbook,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalWordCount.toString(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ],
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
        return const StorageManagementPage();
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
      final theme = Theme.of(context);
      final l10n = AppLocalizations.of(context);

      Widget buildGroup({
        required String title,
        required List<Widget> children,
      }) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12.0, bottom: 6.0),
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < children.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 52,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      children[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: _WordbookStats(),
                ),
                buildGroup(
                  title: l10n?.manageDictionaries ?? "Dictionaries & AI",
                  children: [
                    const ManageDictionariesPageListTile(),
                    const AiSettingsPageListTile(),
                    const AudioSettingsPageListTile(),
                    if (Platform.isAndroid && !isFullFlavor())
                      const ManageStorageListTile(),
                  ],
                ),
                buildGroup(
                  title: l10n?.appearance ?? "Appearance & History",
                  children: [
                    const AppearanceSettingsPageListTile(),
                    const HistoryPageListTile(),
                    ListTile(
                      leading: const Icon(Icons.style),
                      title: const Text("Flashcards"),
                      onTap: () => context.push("/settings/flashcards"),
                    ),
                    const HunspellPageListTile(),
                  ],
                ),
                buildGroup(
                  title: l10n?.backup ?? "Data & Sync",
                  children: [
                    const BackupPageListTile(),
                    const CloudSyncPageListTile(),
                  ],
                ),
                buildGroup(
                  title: l10n?.about ?? "System & About",
                  children: [
                    const UpdatePageListTile(),
                    const OtherPageListTile(),
                    const LoggerPageListTile(),
                    const AboutPageListTile(),
                  ],
                ),
              ],
            ),
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
