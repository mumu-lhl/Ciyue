import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";

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
        return "বাংলা";
      case "ca":
        return "Català";
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
        return "Sardu";
      case "ta":
        return "தமிழ்";
      case "fa":
        return "فارسی";
      case "got":
        return "Gutisk";
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

  static const _supportedLanguages = [
    "system",
    "zh",
    "zh_HK",
    "zh_TW",
    "en",
    "de",
    "es",
    "ru",
    "bn",
    "ca",
    "nb",
    "sc",
    "ta",
    "fa",
    "got",
  ];

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final currentLanguage = settings.language ?? "system";

    return ListTile(
      leading: const Icon(Icons.language_rounded),
      title: Text(locale.language),
      subtitle: Text(_getLanguageName(settings.language, locale)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () async {
        final languageSelected = await showDialog<String>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.language_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(locale.language),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _supportedLanguages.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final code = _supportedLanguages[index];
                    final isSelected = code == currentLanguage;
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: isSelected,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4),
                      title: Text(
                        _getLanguageName(code, locale),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, code),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(locale.cancel),
                ),
              ],
            );
          },
        );

        if (languageSelected != null && languageSelected != settings.language) {
          settings.language = languageSelected;
          await prefs.setString("language", languageSelected);

          setState(() {});
          refreshAll();
        }
      },
    );
  }
}
