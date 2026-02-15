import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  String _getLanguageName(String? code, AppLocalizations locale) {
    switch (code) {
      case "system":
        return locale.system;
      case "bn":
        return "Bengali";
      case "ca":
        return "Catalan";
      case "de":
        return "Deutsch";
      case "es":
        return "Español";
      case "en":
        return "English";
      case "ru":
        return "Русский";
      case "nb":
        return "Bokmål";
      case "sc":
        return "Sardinian";
      case "ta":
        return "Tamil";
      case "fa":
        return "فارسی";
      case "got":
        return "Gothic";
      case "zh":
        return "简体中文";
      case "zh_HK":
        return "繁體中文（香港）";
      case "zh_TW":
        return "正體中文（臺灣）";
      default:
        return code ?? locale.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return InkWell(
      onTapUp: (tapUpDetails) async {
        final languageSelected = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
            tapUpDetails.globalPosition.dx,
            tapUpDetails.globalPosition.dy,
          ),
          initialValue: settings.language,
          items: [
            PopupMenuItem(value: "system", child: Text(locale.system)),
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
            const PopupMenuItem(value: "got", child: Text("Gothic")),
            const PopupMenuItem(value: "zh", child: Text("简体中文")),
            const PopupMenuItem(value: "zh_HK", child: Text("繁體中文（香港）")),
            const PopupMenuItem(value: "zh_TW", child: Text("正體中文（臺灣）")),
          ],
        );

        if (languageSelected != null && languageSelected != settings.language) {
          settings.language = languageSelected;
          await prefs.setString("language", languageSelected);

          setState(() {});
          refreshAll();
        }
      },
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(locale.language),
        subtitle: Text(_getLanguageName(settings.language, locale)),
        trailing: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}
