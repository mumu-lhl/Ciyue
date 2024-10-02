import "dart:convert";
import "dart:io";

import "package:file_selector/file_selector.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";
import "package:path/path.dart";
import "package:url_launcher/url_launcher.dart";

import "../database/dictionary.dart";
import "../main.dart";

const feedbackUri = "https://github.com/mumu-lhl/Ciyue/issues";
const githubUri = "https://github.com/mumu-lhl/Ciyue";

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
      applicationLegalese: "\u{a9} 2024 Mumulhl and contributors",
    );
  }
}

class Export extends StatelessWidget {
  const Export({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.file_upload),
      title: Text("导出"),
      onTap: () async {
        final directoryPath = await getDirectoryPath();
        if (directoryPath == null || dictionary == null) {
          return;
        }

        final words = await dictionary!.getAllWords();
        if (words.isNotEmpty) {
          final dictionaryName = basename(currentDictionaryPath!),
              filename = setExtension(dictionaryName, ".json"),
              saveLocation = join(directoryPath, filename),
              output = jsonEncode(words);

          final file = File(saveLocation);
          await file.writeAsString(output);
        }
      },
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
  const Import({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.file_download),
      title: Text("导入"),
      onTap: () async {
        if (dictionary == null) {
          return;
        }

        const XTypeGroup typeGroup = XTypeGroup(
          label: "json",
          extensions: <String>["json"],
        );
        final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
        if (xFile == null) {
          return;
        }

        final file = File(xFile.path),
            input = await file.readAsString(),
            json = jsonDecode(input),
            data = WordbookData.fromJson(json[0]);
        await dictionary!.addAllWords(data);
      },
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
        Export(),
        Import(),
        Divider(),
        Feedback(),
        GithubUrl(),
        About(),
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
      ),
    );
  }
}

class _ThemeChoiceState extends State<ThemeChoice> {
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
      ),
    );
  }
}
