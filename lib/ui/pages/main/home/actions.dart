import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              OneActionButton(
                  title: AppLocalizations.of(context)!.writingCheck,
                  path: "/writing_check",
                  icon: Icons.spellcheck_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class OneActionButton extends StatelessWidget {
  final String title;
  final String path;
  final IconData icon;

  const OneActionButton({
    super.key,
    required this.title,
    required this.path,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: AppLocalizations.of(context)!.writingCheck,
      icon: Icon(Icons.spellcheck_outlined,
          color: Theme.of(context).colorScheme.primary),
      onPressed: () {
        context.push("/writing_check");
      },
    );
  }
}
