import "package:ciyue/services/flashcard_scheduler.dart";
import "package:flutter/material.dart";

SnackBar buildRatingSavedSnackBar({required VoidCallback onUndo}) {
  return SnackBar(
    content: const Text("Rating saved"),
    duration: const Duration(seconds: 4),
    persist: false,
    action: SnackBarAction(label: "Undo", onPressed: onUndo),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final rating in FlashcardRating.values)
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
                    Text(_label(rating)),
                    Text(
                      _interval(previews[rating]!.due.difference(now)),
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

  String _label(FlashcardRating rating) => switch (rating) {
        FlashcardRating.again => "Again",
        FlashcardRating.hard => "Hard",
        FlashcardRating.good => "Good",
        FlashcardRating.easy => "Easy",
      };

  String _interval(Duration duration) {
    if (duration.inDays >= 1) return "${duration.inDays}d";
    if (duration.inHours >= 1) return "${duration.inHours}h";
    return "${duration.inMinutes.clamp(1, 59)}m";
  }
}
