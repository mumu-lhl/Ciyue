import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:go_router/go_router.dart";

class TextCloseButton extends StatelessWidget {
  const TextCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: Text(AppLocalizations.of(context)!.close),
      onPressed: () {
        context.pop();
      },
    );
  }
}
