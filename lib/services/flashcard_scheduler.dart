import "package:fsrs/fsrs.dart" as fsrs;

enum FlashcardState { learning, review, relearning }

enum FlashcardRating { again, hard, good, easy }

class Flashcard {
  final int id;
  final FlashcardState state;
  final int? step;
  final double? stability;
  final double? difficulty;
  final DateTime due;
  final DateTime? lastReview;

  const Flashcard({
    required this.id,
    required this.state,
    required this.step,
    required this.stability,
    required this.difficulty,
    required this.due,
    required this.lastReview,
  });
}

class FlashcardReviewResult {
  final Flashcard card;
  final FlashcardRating rating;
  final DateTime reviewedAt;
  final int? durationMs;

  const FlashcardReviewResult({
    required this.card,
    required this.rating,
    required this.reviewedAt,
    required this.durationMs,
  });
}

class FlashcardScheduler {
  final fsrs.Scheduler _scheduler;

  FlashcardScheduler({bool enableFuzzing = true})
      : _scheduler = fsrs.Scheduler(enableFuzzing: enableFuzzing);

  Flashcard createCard({required int id, required DateTime now}) {
    _requireUtc(now);
    return Flashcard(
      id: id,
      state: FlashcardState.learning,
      step: 0,
      stability: null,
      difficulty: null,
      due: now,
      lastReview: null,
    );
  }

  Map<FlashcardRating, Flashcard> preview(
    Flashcard card, {
    required DateTime now,
  }) {
    return {
      for (final rating in FlashcardRating.values)
        rating: review(card, rating, now: now).card,
    };
  }

  FlashcardReviewResult review(
    Flashcard card,
    FlashcardRating rating, {
    required DateTime now,
    int? durationMs,
  }) {
    _requireUtc(now);
    final result = _scheduler.reviewCard(
      _toFsrs(card),
      _toFsrsRating(rating),
      reviewDateTime: now,
      reviewDuration: durationMs,
    );
    return FlashcardReviewResult(
      card: _fromFsrs(result.card),
      rating: rating,
      reviewedAt: result.reviewLog.reviewDateTime,
      durationMs: result.reviewLog.reviewDuration,
    );
  }

  fsrs.Card _toFsrs(Flashcard card) => fsrs.Card(
        cardId: card.id,
        state: fsrs.State.values[card.state.index],
        step: card.step,
        stability: card.stability,
        difficulty: card.difficulty,
        due: card.due,
        lastReview: card.lastReview,
      );

  Flashcard _fromFsrs(fsrs.Card card) => Flashcard(
        id: card.cardId,
        state: FlashcardState.values[card.state.index],
        step: card.step,
        stability: card.stability,
        difficulty: card.difficulty,
        due: card.due,
        lastReview: card.lastReview,
      );

  fsrs.Rating _toFsrsRating(FlashcardRating rating) =>
      fsrs.Rating.values[rating.index];

  void _requireUtc(DateTime value) {
    if (!value.isUtc) throw ArgumentError.value(value, "now", "must be UTC");
  }
}
