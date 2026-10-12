import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";

class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ActionChip(
                  avatar: Icon(
                    Icons.spellcheck_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(l10n.writingCheck),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLow,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () => context.push("/writing_check"),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(
                    Icons.style_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  label: const Text("Flashcards"),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLow,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () => context.push("/flashcards/review"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
