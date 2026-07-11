import "package:ciyue/services/flashcard_scheduler.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("FlashcardScheduler", () {
    final now = DateTime.utc(2026, 7, 11, 8);
    final scheduler = FlashcardScheduler(enableFuzzing: false);

    test("creates a UTC learning card due immediately", () {
      final card = scheduler.createCard(id: 7, now: now);

      expect(card.id, 7);
      expect(card.state, FlashcardState.learning);
      expect(card.step, 0);
      expect(card.due, now);
      expect(card.due.isUtc, isTrue);
    });

    test("previews all ratings without mutating the card", () {
      final card = scheduler.createCard(id: 7, now: now);

      final previews = scheduler.preview(card, now: now);

      expect(previews.keys, FlashcardRating.values);
      expect(card.lastReview, isNull);
      expect(previews[FlashcardRating.again]!.due,
          now.add(const Duration(minutes: 1)));
      expect(previews[FlashcardRating.good]!.due,
          now.add(const Duration(minutes: 10)));
    });

    test("review returns updated card and duration", () {
      final card = scheduler.createCard(id: 7, now: now);

      final result = scheduler.review(
        card,
        FlashcardRating.easy,
        now: now,
        durationMs: 1500,
      );

      expect(result.card.lastReview, now);
      expect(result.rating, FlashcardRating.easy);
      expect(result.reviewedAt, now);
      expect(result.durationMs, 1500);
      expect(result.card.due.isAfter(now), isTrue);
    });
  });
}
