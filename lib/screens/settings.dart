import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

import "../main.dart";

class LanguageChoice extends StatefulWidget {
  const LanguageChoice({super.key});

  @override
  State<LanguageChoice> createState() => _LanguageChoiceState();
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return ListView(
      children: [
        ListTile(
            leading: const Icon(Icons.book),
            trailing: const Icon(Icons.arrow_forward),
            title: Text(locale!.manageDictionaries),
            onTap: () async {
              await context.push("/settings/dictionaries");
            }),
        const Divider(),
        const ThemeChoice(),
        const LanguageChoice()
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

    return ListTile(
        leading: const Icon(Icons.language),
        title: Text(locale!.language),
        trailing: PopupMenuButton(
          initialValue: language,
          onSelected: (String languageSelected) {
            language = languageSelected;

            prefs.setString("language", languageSelected);

            setState(() {});
            refreshAll();
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(value: "en", child: Text("English")),
            const PopupMenuItem(value: "nb", child: Text("Bokmål")),
            const PopupMenuItem(value: "zh_CN", child: Text("简体中文")),
            const PopupMenuItem(value: "zh_HK", child: Text("繁體中文（香港）")),
            const PopupMenuItem(value: "zh_TW", child: Text("正體中文（臺灣）")),
          ],
          child: const Icon(Icons.keyboard_arrow_down),
        ));
  }
}

class _ThemeChoiceState extends State<ThemeChoice> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return ListTile(
        leading: const Icon(Icons.light_mode),
        title: Text(locale!.theme),
        trailing: PopupMenuButton(
          initialValue: themeMode,
          onSelected: (ThemeMode themeModeSelected) {
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
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(value: ThemeMode.light, child: Text(locale.light)),
            PopupMenuItem(value: ThemeMode.dark, child: Text(locale.dark)),
            PopupMenuItem(value: ThemeMode.system, child: Text(locale.system)),
          ],
          child: const Icon(Icons.keyboard_arrow_down),
        ));
  }
}
