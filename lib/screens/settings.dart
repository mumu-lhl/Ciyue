import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

import "../main.dart";

class AboutWidget extends StatelessWidget {
  const AboutWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AboutListTile(
      icon: const Icon(Icons.info),
      applicationName: packageInfo.appName,
      applicationVersion: "${packageInfo.version}+${packageInfo.buildNumber}",
      applicationLegalese: "\u{a9} 2024 Mumulhl and contributors",
    );
  }
}

class LanguageChoice extends StatefulWidget {
  const LanguageChoice({super.key});

  @override
  State<LanguageChoice> createState() => _LanguageChoiceState();
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ManageDictionariesWidget(),
        Divider(),
        ThemeChoice(),
        LanguageChoice(),
        Divider(),
        AboutWidget()
      ],
    );
  }
}

class ThemeChoice extends StatefulWidget {
  const ThemeChoice({super.key});

  @override
  State<ThemeChoice> createState() => _ThemeChoiceState();
}

class _LanguageChoiceState extends State<LanguageChoice> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return GestureDetector(
      onTapDown: (tapDownDetails) async {
        final languageSelected = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            tapDownDetails.globalPosition.dx,
            tapDownDetails.globalPosition.dy,
            tapDownDetails.globalPosition.dx,
            tapDownDetails.globalPosition.dy,
          ),
          initialValue: language,
          items: [
            const PopupMenuItem(value: "en", child: Text("English")),
            const PopupMenuItem(value: "nb", child: Text("Bokmål")),
            const PopupMenuItem(value: "zh_CN", child: Text("简体中文")),
            const PopupMenuItem(value: "zh_HK", child: Text("繁體中文（香港）")),
            const PopupMenuItem(value: "zh_TW", child: Text("正體中文（臺灣）")),
          ],
        );

        if (languageSelected != null) {
          language = languageSelected;

          prefs.setString("language", languageSelected);

          setState(() {});
          refreshAll();
        }
      },
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(locale!.language),
        trailing: const Icon(Icons.keyboard_arrow_down),
        onTap: () {},
      ),
    );
  }
}

class _ThemeChoiceState extends State<ThemeChoice> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return GestureDetector(
      onTapDown: (tapDownDetails) async {
        final themeModeSelected = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            tapDownDetails.globalPosition.dx,
            tapDownDetails.globalPosition.dy,
            tapDownDetails.globalPosition.dx,
            tapDownDetails.globalPosition.dy,
          ),
          initialValue: themeMode,
          items: [
            PopupMenuItem(value: ThemeMode.light, child: Text(locale.light)),
            PopupMenuItem(value: ThemeMode.dark, child: Text(locale.dark)),
            PopupMenuItem(value: ThemeMode.system, child: Text(locale.system)),
          ],
        );

        if (themeModeSelected != null) {
          themeMode = themeModeSelected;

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
        onTap: () {},
      ),
    );
  }
}
