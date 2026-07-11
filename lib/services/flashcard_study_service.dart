import "package:ciyue/database/app/app.dart" as db;
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/services/flashcard_scheduler.dart" as domain;

class FlashcardSessionItem {
  final String word;
  final domain.Flashcard card;

  const FlashcardSessionItem({required this.word, required this.card});
}

class FlashcardUndoToken {
  final db.Flashcard previousCard;
  final int logId;

  const FlashcardUndoToken({required this.previousCard, required this.logId});
}

class FlashcardStudyService {
  final FlashcardDao dao;
  final domain.FlashcardScheduler scheduler;

  const FlashcardStudyService({required this.dao, required this.scheduler});

  Future<List<FlashcardSessionItem>> loadSession({
    required DateTime now,
    required DateTime localDayStartUtc,
    required int dailyNewLimit,
    int? tag,
  }) async {
    final due = await dao.getDueCards(now: now, tag: tag);
    final introduced = await dao.countIntroduced(
      start: localDayStartUtc,
      end: localDayStartUtc.add(const Duration(days: 1)),
    );
    final remaining = (dailyNewLimit - introduced).clamp(0, dailyNewLimit);
    final newWords = await dao.getNewWords(limit: remaining, tag: tag);
    final items = due
        .map((card) => FlashcardSessionItem(
              word: card.word,
              card: _toDomain(card),
            ))
        .toList();
    for (final word in newWords) {
      final card = scheduler.createCard(id: _stableId(word), now: now);
      await dao.putCard(
        word: word,
        state: card.state.index,
        step: card.step,
        stability: card.stability,
        difficulty: card.difficulty,
        due: card.due.toUtc(),
        lastReview: card.lastReview?.toUtc(),
        introducedAt: now,
      );
      items.add(FlashcardSessionItem(word: word, card: card));
    }
    return items;
  }

  Map<domain.FlashcardRating, domain.Flashcard> preview(
    FlashcardSessionItem item, {
    required DateTime now,
  }) =>
      scheduler.preview(item.card, now: now);

  Future<FlashcardUndoToken> rate(
    FlashcardSessionItem item,
    domain.FlashcardRating rating, {
    required DateTime now,
    int? durationMs,
  }) async {
    final previous = await dao.getCard(item.word);
    if (previous == null) throw StateError("Flashcard no longer exists");
    final result = scheduler.review(
      item.card,
      rating,
      now: now,
      durationMs: durationMs,
    );
    final next = db.Flashcard(
      word: item.word,
      state: result.card.state.index,
      step: result.card.step,
      stability: result.card.stability,
      difficulty: result.card.difficulty,
      due: result.card.due,
      lastReview: result.card.lastReview,
      introducedAt: previous.introducedAt,
    );
    final logId = await dao.saveReview(
      card: next,
      rating: rating.index,
      reviewedAt: result.reviewedAt,
      durationMs: result.durationMs,
    );
    return FlashcardUndoToken(previousCard: previous, logId: logId);
  }

  Future<void> undo(FlashcardUndoToken token) => dao.undoReview(
        previousCard: token.previousCard,
        logId: token.logId,
      );

  domain.Flashcard _toDomain(db.Flashcard card) => domain.Flashcard(
        id: _stableId(card.word),
        state: domain.FlashcardState.values[card.state],
        step: card.step,
        stability: card.stability,
        difficulty: card.difficulty,
        due: card.due,
        lastReview: card.lastReview,
      );

  int _stableId(String word) {
    var hash = 0xcbf29ce484222325;
    for (final unit in word.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash;
  }
}
