import "package:ciyue/services/flashcard_scheduler.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:material_ui/material_ui.dart";

SnackBar buildRatingSavedSnackBar({
  required AppLocalizations l10n,
  required VoidCallback onUndo,
}) {
  return SnackBar(
    content: Text(l10n.flashcardsRatingSaved),
    duration: const Duration(seconds: 4),
    persist: false,
    action: SnackBarAction(label: l10n.flashcardsUndo, onPressed: onUndo),
  );
}

class FlashcardRatingButtons extends StatelessWidget {
  final DateTime now;
  final Map<FlashcardRating, Flashcard> previews;
  final ValueChanged<FlashcardRating> onSelected;

  const FlashcardRatingButtons({
    super.key,
    required this.now,
    required this.previews,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, rating) in FlashcardRating.values.indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FilledButton.tonal(
                onPressed: () => onSelected(rating),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLargeScreen(context)
                          ? "${_label(l10n, rating)} (${index + 1})"
                          : _label(l10n, rating),
                    ),
                    Text(
                      _interval(l10n, previews[rating]!.due.difference(now)),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _label(AppLocalizations l10n, FlashcardRating rating) =>
      switch (rating) {
        FlashcardRating.again => l10n.flashcardsRatingAgain,
        FlashcardRating.hard => l10n.flashcardsRatingHard,
        FlashcardRating.good => l10n.flashcardsRatingGood,
        FlashcardRating.easy => l10n.flashcardsRatingEasy,
      };

  String _interval(AppLocalizations l10n, Duration duration) {
    if (duration.inDays >= 1) return l10n.flashcardsDaysShort(duration.inDays);
    if (duration.inHours >= 1) {
      return l10n.flashcardsHoursShort(duration.inHours);
    }
    return l10n.flashcardsMinutesShort(duration.inMinutes.clamp(1, 59));
  }
}
