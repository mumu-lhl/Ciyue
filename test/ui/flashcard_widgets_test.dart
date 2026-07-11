import "package:ciyue/services/flashcard_scheduler.dart";
import "package:ciyue/ui/pages/flashcards/rating_buttons.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("rating snackbar expires even with undo action", () {
    final snackBar = buildRatingSavedSnackBar(onUndo: () {});

    expect(snackBar.persist, isFalse);
    expect(snackBar.duration, const Duration(seconds: 4));
  });

  testWidgets("rating controls show four FSRS choices and intervals",
      (tester) async {
    final due = DateTime.utc(2026, 7, 11, 8);
    final previews = {
      for (final rating in FlashcardRating.values)
        rating: Flashcard(
          id: 1,
          state: FlashcardState.review,
          step: null,
          stability: 1,
          difficulty: 1,
          due: due.add(Duration(days: rating.index + 1)),
          lastReview: due,
        ),
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FlashcardRatingButtons(
          now: due,
          previews: previews,
          onSelected: (_) {},
        ),
      ),
    ));

    expect(find.text("Again"), findsOneWidget);
    expect(find.text("Hard"), findsOneWidget);
    expect(find.text("Good"), findsOneWidget);
    expect(find.text("Easy"), findsOneWidget);
    expect(find.text("1d"), findsOneWidget);
    expect(find.text("4d"), findsOneWidget);
  });
}
