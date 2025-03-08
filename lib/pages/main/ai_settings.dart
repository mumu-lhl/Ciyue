import "package:flutter/material.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";

class AiSettings extends StatelessWidget {
  const AiSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.aiSettings),
      ),
      body: const Center(
        child: Text("AI Settings Page"),
      ),
    );
  }
}
