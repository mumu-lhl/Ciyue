import "package:ciyue/models/updater/updater.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

class UpdateAvailable extends StatelessWidget {
  const UpdateAvailable({
    super.key,
    required this.update,
  });

  final Update update;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.updateAvailable),
      content: Text(
        AppLocalizations.of(context)!
            .updateAvailableContent
            .replaceFirst("%s", update.version),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(AppLocalizations.of(context)!.close),
        ),
        TextButton(
          onPressed: () async {
            final url = "https://github.com/mumu-lhl/Ciyue/releases/latest";
            if (await canLaunchUrl(Uri.parse(url))) {
              launchUrl(Uri.parse(url));
            }
            if (context.mounted) context.pop();
          },
          child: Text(AppLocalizations.of(context)!.update),
        ),
      ],
    );
  }
}
