import "dart:convert";
import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/main.dart";
import "package:ciyue/services/backup.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/ui/pages/core/alpha_text.dart";
import "package:ciyue/ui/pages/core/update_available.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";
import "package:url_launcher/url_launcher.dart";

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
  static const discordUri = "https://discord.gg/BazBZuvKZG";

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
  static const feedbackUri = "https://github.com/mumu-lhl/Ciyue/issues";

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
  static const githubUri = "https://github.com/mumu-lhl/Ciyue";

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
        AppearanceSettings(),
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

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette),
      trailing: const Icon(Icons.arrow_forward),
      title: Text(AppLocalizations.of(context)!.appearance),
      onTap: () => context.push("/settings/appearance"),
    );
  }
}

class SponsorUrl extends StatelessWidget {
  static const sponsorUri = "https://afdian.com/a/mumulhl";

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
