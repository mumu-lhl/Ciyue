import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";

class DictionaryCustomCss extends StatelessWidget {
  const DictionaryCustomCss({super.key});

  Future<void> _editCss(BuildContext context, AppLocalizations locale) async {
    final controller = TextEditingController(
      text: settings.dictionaryCustomCss,
    );
    try {
      final css = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(locale.dictionaryCustomCss),
          content: SizedBox(
            width: 600,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 10,
              maxLines: 20,
              style: const TextStyle(fontFamily: "monospace"),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: locale.dictionaryCustomCssHint,
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(locale.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(locale.save),
            ),
          ],
        ),
      );
      if (css == null) return;
      await settings.setDictionaryCustomCss(css);
      refreshAll();
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.code),
      title: Text(locale.dictionaryCustomCss),
      subtitle: Text(locale.dictionaryCustomCssDescription),
      onTap: () => _editCss(context, locale),
    );
  }
}
