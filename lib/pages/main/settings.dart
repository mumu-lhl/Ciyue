import "dart:convert";
import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/main.dart";
import "package:ciyue/services/backup.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/widget/alpha_text.dart";
import "package:ciyue/widget/update_available.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

const discordUri = "https://discord.gg/BazBZuvKZG";
const feedbackUri = "https://github.com/mumu-lhl/Ciyue/issues";
const githubUri = "https://github.com/mumu-lhl/Ciyue";
const sponsorUri = "https://afdian.com/a/mumulhl";

void _copy(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(AppLocalizations.of(context)!.copied),
    duration: const Duration(seconds: 1),
  ));
}

class About extends StatelessWidget {
  const About({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AboutListTile(
      icon: const Icon(Icons.info),
      applicationName: packageInfo.appName,
      applicationVersion: "${packageInfo.version} (${packageInfo.buildNumber})",
      applicationLegalese: "\u{a9} 2024-2025 Mumulhl and contributors",
    );
  }
}

class AiSettingsWidget extends StatelessWidget {
  const AiSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.settings),
      trailing: const Icon(Icons.arrow_forward),
      title: Text(AppLocalizations.of(context)!.aiSettings),
      onTap: () => context.push("/settings/ai_settings"),
    );
  }
}

class AudioSettingsWidget extends StatefulWidget {
  const AudioSettingsWidget({super.key});

  @override
  State<AudioSettingsWidget> createState() => _AudioSettingsWidgetState();
}

class AutoExport extends StatelessWidget {
  const AutoExport({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: Icon(Icons.backup),
        title: Text(AppLocalizations.of(context)!.autoExport),
        trailing: Icon(Icons.arrow_forward),
        onTap: () => context.push("/settings/autoExport"));
  }
}

class AutoUpdateSwitch extends StatefulWidget {
  const AutoUpdateSwitch({super.key});

  @override
  State<AutoUpdateSwitch> createState() => _AutoUpdateSwitchState();
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

class ClearHistory extends StatelessWidget {
  const ClearHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.delete),
      title: Text(locale!.clearHistory),
      onTap: () => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(locale.clearHistory),
          content: Text(locale.clearHistoryConfirm),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(locale.close),
            ),
            TextButton(
              onPressed: () async {
                if (context.mounted) {
                  context.read<HistoryModel>().clearHistory();
                  context.pop(context);
                }
              },
              child: Text(locale.confirm),
            ),
          ],
        ),
      ),
    );
  }
}

class DiscordUrl extends StatelessWidget {
  const DiscordUrl({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: const Text("Discord"),
        subtitle: const Text(discordUri),
        leading: const Icon(Icons.discord),
        onTap: () => launchUrl(Uri.parse(discordUri)),
        onLongPress: () => _copy(context, discordUri));
  }
}

class DrawerIconSwitch extends StatefulWidget {
  const DrawerIconSwitch({super.key});

  @override
  State<DrawerIconSwitch> createState() => _DrawerIconSwitchState();
}

class Export extends StatelessWidget {
  const Export({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.file_upload),
      title: Text(AppLocalizations.of(context)!.export),
      onTap: () => Backup.export(false),
    );
  }
}

class Feedback extends StatelessWidget {
  const Feedback({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(AppLocalizations.of(context)!.feedback),
        subtitle: const Text(feedbackUri),
        leading: const Icon(Icons.feedback),
        onTap: () => launchUrl(Uri.parse(feedbackUri)),
        onLongPress: () => _copy(context, feedbackUri));
  }
}

class FloatingWindow extends StatefulWidget {
  const FloatingWindow({super.key});

  @override
  State<FloatingWindow> createState() => _FloatingWindowState();
}

class GithubUrl extends StatelessWidget {
  const GithubUrl({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: const Text("Github"),
        subtitle: const Text(githubUri),
        leading: const Icon(Icons.public),
        onTap: () => launchUrl(Uri.parse(githubUri)),
        onLongPress: () => _copy(context, githubUri));
  }
}

class Import extends StatelessWidget {
  const Import({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.file_download),
      title: Text(AppLocalizations.of(context)!.import),
      onTap: () => Backup.import(),
    );
  }
}

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class LegacyImport extends StatelessWidget {
  const LegacyImport({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.file_download),
      title: Text(AppLocalizations.of(context)!.legacyImport),
      onTap: () async {
        const XTypeGroup typeGroup = XTypeGroup(
          label: "json",
          extensions: <String>["json"],
        );
        final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
        if (xFile == null) {
          return;
        }

        final content = (await xFile.readAsString()).split("\n"),
            wordsJson = jsonDecode(content[0]),
            tagsJson = jsonDecode(content[1]);

        final wordsData = <WordbookData>[];
        for (final i in wordsJson) {
          final json = Map<String, dynamic>.from(i);
          if (!json.containsKey("createdAt")) {
            json["createdAt"] = DateTime.now().toIso8601String();
          }
          wordsData.add(WordbookData.fromJson(json));
        }

        final tagsData = <WordbookTag>[];
        for (final i in tagsJson) {
          tagsData.add(WordbookTag.fromJson(i));
        }

        await wordbookDao.addAllWords(wordsData);
        await wordbookTagsDao.addAllTags(tagsData);
      },
    );
  }
}

class ManageDictionariesWidget extends StatelessWidget {
  const ManageDictionariesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return ListTile(
        leading: const Icon(Icons.book),
        trailing: const Icon(Icons.arrow_forward),
        title: Text(locale!.manageDictionaries),
        onTap: () async {
          await context.push("/settings/dictionaries");
        });
  }
}

class MoreOptionsButtonSwitch extends StatefulWidget {
  const MoreOptionsButtonSwitch({super.key});

  @override
  State<MoreOptionsButtonSwitch> createState() =>
      _MoreOptionsButtonSwitchState();
}

class NotificationSwitch extends StatefulWidget {
  const NotificationSwitch({super.key});

  @override
  State<NotificationSwitch> createState() => _NotificationSwitchState();
}

class PrereleaseUpdatesSwitch extends StatefulWidget {
  const PrereleaseUpdatesSwitch({super.key});

  @override
  State<PrereleaseUpdatesSwitch> createState() =>
      _PrereleaseUpdatesSwitchState();
}

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.security),
      title: Text(AppLocalizations.of(context)!.privacyPolicy),
      onTap: () => context.push("/settings/privacy_policy"),
    );
  }
}

class SearchbarInWordDisplaySwitch extends StatefulWidget {
  const SearchbarInWordDisplaySwitch({super.key});

  @override
  State<SearchbarInWordDisplaySwitch> createState() =>
      _SearchbarInWordDisplaySwitchState();
}

class SearchbarLocationSelector extends StatefulWidget {
  const SearchbarLocationSelector({super.key});

  @override
  State<SearchbarLocationSelector> createState() =>
      _SearchbarLocationSelectorState();
}

class SecureScreenSwitch extends StatefulWidget {
  const SecureScreenSwitch({super.key});

  @override
  State<SecureScreenSwitch> createState() => _SecureScreenSwitchState();
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ManageDictionariesWidget(),
        const AiSettingsWidget(),
        const AudioSettingsWidget(),
        TitleDivider(title: AppLocalizations.of(context)!.appearance),
        const ThemeSelector(),
        const LanguageSelector(),
        const SearchbarLocationSelector(),
        const TabBarPositionSelector(),
        const SearchbarInWordDisplaySwitch(),
        const DrawerIconSwitch(),
        const MoreOptionsButtonSwitch(),
        if (Platform.isAndroid) ...[
          TitleDivider(title: AppLocalizations.of(context)!.privacy),
          const SecureScreenSwitch(),
          const Divider(indent: 16, endIndent: 16),
          const NotificationSwitch(),
          const FloatingWindow(),
        ],
        TitleDivider(title: AppLocalizations.of(context)!.export),
        const AutoExport(),
        const Export(),
        const Import(),
        const LegacyImport(),
        TitleDivider(title: AppLocalizations.of(context)!.history),
        const ClearHistory(),
        TitleDivider(title: AppLocalizations.of(context)!.update),
        const AutoUpdateSwitch(),
        const PrereleaseUpdatesSwitch(),
        const CheckForUpdates(),
        const Divider(indent: 16, endIndent: 16),
        const Feedback(),
        const GithubUrl(),
        const DiscordUrl(),
        const SponsorUrl(),
        const TermsOfService(),
        const PrivacyPolicy(),
        const About(),
      ],
    );
  }
}

class SponsorUrl extends StatelessWidget {
  const SponsorUrl({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(AppLocalizations.of(context)!.sponsor),
        subtitle: const Text(sponsorUri),
        leading: const Icon(Icons.favorite),
        onTap: () => launchUrl(Uri.parse(sponsorUri)),
        onLongPress: () => _copy(context, sponsorUri));
  }
}

class TabBarPositionSelector extends StatefulWidget {
  const TabBarPositionSelector({super.key});

  @override
  State<TabBarPositionSelector> createState() => _TabBarPositionSelectorState();
}

class TermsOfService extends StatelessWidget {
  const TermsOfService({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.article),
      title: Text(AppLocalizations.of(context)!.termsOfService),
      onTap: () => context.push("/settings/terms_of_service"),
    );
  }
}

class ThemeSelector extends StatefulWidget {
  const ThemeSelector({super.key});

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class TitleDivider extends StatelessWidget {
  final String title;

  const TitleDivider({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(child: Divider(endIndent: 16)),
      ],
    );
  }
}

class _AudioSettingsWidgetState extends State<AudioSettingsWidget> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.volume_up),
      trailing: const Icon(Icons.arrow_forward),
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

class _DrawerIconSwitchState extends State<DrawerIconSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.sidebarIcon),
      value: settings.showSidebarIcon,
      onChanged: (value) async {
        await prefs.setBool("showSidebarIcon", value);
        if (context.mounted) context.read<HomeModel>().update();
        setState(() {
          settings.showSidebarIcon = value;
        });
      },
      secondary: const Icon(Icons.menu),
    );
  }
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
        await PlatformMethod.requestFloatingWindowPermission();
      },
    );
  }
}

class _LanguageSelectorState extends State<LanguageSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final languageSelected = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.language,
          items: [
            PopupMenuItem(
                value: "system",
                child: Text(AppLocalizations.of(context)!.system)),
            const PopupMenuItem(value: "bn", child: Text("Bengali")),
            const PopupMenuItem(value: "ca", child: Text("Catalan")),
            const PopupMenuItem(value: "de", child: Text("Deutsch")),
            const PopupMenuItem(value: "es", child: Text("Español")),
            const PopupMenuItem(value: "en", child: Text("English")),
            const PopupMenuItem(value: "ru", child: Text("Русский")),
            const PopupMenuItem(value: "nb", child: Text("Bokmål")),
            const PopupMenuItem(value: "sc", child: Text("Sardinian")),
            const PopupMenuItem(value: "ta", child: Text("Tamil")),
            const PopupMenuItem(value: "fa", child: Text("فارسی")),
            const PopupMenuItem(value: "zh", child: Text("简体中文")),
            const PopupMenuItem(value: "zh_HK", child: Text("繁體中文（香港）")),
            const PopupMenuItem(value: "zh_TW", child: Text("正體中文（臺灣）")),
          ],
        );

        if (languageSelected != null) {
          settings.language = languageSelected;

          prefs.setString("language", languageSelected);

          setState(() {});
          refreshAll();
        }
      },
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(locale!.language),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}

class _MoreOptionsButtonSwitchState extends State<MoreOptionsButtonSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.moreOptionsButton),
      value: settings.showMoreOptionsButton,
      onChanged: (value) async {
        await prefs.setBool("showMoreOptionsButton", value);
        if (context.mounted) context.read<HomeModel>().update();
        setState(() {
          settings.showMoreOptionsButton = value;
        });
      },
      secondary: const Icon(Icons.more_vert),
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

class _SearchbarInWordDisplaySwitchState
    extends State<SearchbarInWordDisplaySwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.showSearchBarInWordDisplayPage),
      value: settings.showSearchBarInWordDisplay,
      onChanged: (value) async {
        await prefs.setBool("showSearchBarInWordDisplay", value);
        setState(() {
          settings.showSearchBarInWordDisplay = value;
        });
      },
      secondary: const Icon(Icons.search),
    );
  }
}

class _SearchbarLocationSelectorState extends State<SearchbarLocationSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final searchBarLocationSelected = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.searchBarInAppBar,
          items: [
            PopupMenuItem(value: true, child: Text(locale.top)),
            PopupMenuItem(value: false, child: Text(locale.bottom)),
          ],
        );

        if (searchBarLocationSelected != null) {
          settings.searchBarInAppBar = searchBarLocationSelected;
          await prefs.setBool("searchBarInAppBar", searchBarLocationSelected);

          if (context.mounted) context.read<HomeModel>().update();
          setState(() {});
        }
      },
      child: ListTile(
        leading: const Icon(Icons.search),
        title: Text(locale!.searchBarLocation),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
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

class _TabBarPositionSelectorState extends State<TabBarPositionSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final selected = await showMenu<TabBarPosition>(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.tabBarPosition,
          items: [
            PopupMenuItem(
              value: TabBarPosition.top,
              child: Text(locale.top),
            ),
            PopupMenuItem(
              value: TabBarPosition.bottom,
              child: Text(locale.bottom),
            ),
          ],
        );

        if (selected != null && selected != settings.tabBarPosition) {
          await settings.setTabBarPosition(selected);
          setState(() {});
        }
      },
      child: ListTile(
        leading: const Icon(Icons.tab),
        title: Text(locale.tabBarPosition),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}

class _ThemeSelectorState extends State<ThemeSelector> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final themeModeSelected = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.themeMode,
          items: [
            PopupMenuItem(value: ThemeMode.light, child: Text(locale.light)),
            PopupMenuItem(value: ThemeMode.dark, child: Text(locale.dark)),
            PopupMenuItem(value: ThemeMode.system, child: Text(locale.system)),
          ],
        );

        if (themeModeSelected != null) {
          settings.themeMode = themeModeSelected;

          String themeModeString;
          switch (themeModeSelected) {
            case ThemeMode.light:
              themeModeString = "light";
            case ThemeMode.dark:
              themeModeString = "dark";
            case ThemeMode.system:
              themeModeString = "system";
          }

          prefs.setString("themeMode", themeModeString);

          setState(() {});
          refreshAll();
        }
      },
      child: ListTile(
        leading: const Icon(Icons.light_mode),
        title: Text(locale!.theme),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}
