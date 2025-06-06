import "dart:io";

import "package:ciyue/main.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/core/alpha_text.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

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

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
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
        const ThemeSelector(),
        const LanguageSelector(),
        const AppearanceSettingsPageListTile(),
        const ClearHistory(),
        const BackupPageListTile(),
        const UpdatePageListTile(),
        if (Platform.isAndroid) const OtherPageListTile(),
        const AboutPageListTile(),
      ],
    );
  }
}

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

class ThemeSelector extends StatefulWidget {
  const ThemeSelector({super.key});

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
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
