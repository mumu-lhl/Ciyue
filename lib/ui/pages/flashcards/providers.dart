import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/flashcard_scheduler.dart";
import "package:ciyue/services/flashcard_study_service.dart";
import "package:riverpod/riverpod.dart";

class FlashcardOverview {
  final int due;
  final int newCards;
  final int done;

  const FlashcardOverview({
    required this.due,
    required this.newCards,
    required this.done,
  });
}

typedef FlashcardOverviewLoader = Future<FlashcardOverview> Function(int? tag);

final flashcardOverviewLoaderProvider = Provider<FlashcardOverviewLoader>(
  (ref) => _loadFlashcardOverview,
);

final flashcardOverviewProvider =
    FutureProvider.family<FlashcardOverview, int?>((ref, tag) {
  return ref.watch(flashcardOverviewLoaderProvider)(tag);
});

final flashcardStudyServiceProvider = Provider<FlashcardStudyService>((ref) {
  return FlashcardStudyService(
    dao: flashcardDao,
    scheduler: FlashcardScheduler(),
  );
});

int normalizeFlashcardDailyLimit(int value) => value.clamp(0, 9999);

class FlashcardDailyLimitNotifier extends Notifier<int> {
  @override
  int build() => settings.flashcardDailyNewLimit;

  Future<void> setLimit(int value) async {
    final normalized = normalizeFlashcardDailyLimit(value);
    await settings.setFlashcardDailyNewLimit(normalized);
    state = normalized;
    ref.invalidate(flashcardOverviewProvider);
  }
}

final flashcardDailyNewLimitProvider =
    NotifierProvider<FlashcardDailyLimitNotifier, int>(
  FlashcardDailyLimitNotifier.new,
);

class FlashcardSessionState {
  final List<FlashcardSessionItem> items;
  final int index;
  final bool answerVisible;
  final DateTime shownAt;
  final DateTime startedAt;
  final Map<FlashcardRating, int> ratings;

  const FlashcardSessionState({
    required this.items,
    required this.index,
    required this.answerVisible,
    required this.shownAt,
    required this.startedAt,
    required this.ratings,
  });

  bool get complete => index >= items.length;
  FlashcardSessionItem get current => items[index];

  FlashcardSessionState copyWith({
    int? index,
    bool? answerVisible,
    DateTime? shownAt,
    Map<FlashcardRating, int>? ratings,
  }) {
    return FlashcardSessionState(
      items: items,
      index: index ?? this.index,
      answerVisible: answerVisible ?? this.answerVisible,
      shownAt: shownAt ?? this.shownAt,
      startedAt: startedAt,
      ratings: ratings ?? this.ratings,
    );
  }
}

class FlashcardSessionNotifier extends AsyncNotifier<FlashcardSessionState> {
  final int? tag;

  FlashcardSessionNotifier(this.tag);

  FlashcardStudyService get _service => ref.read(flashcardStudyServiceProvider);

  @override
  Future<FlashcardSessionState> build() async {
    final localNow = DateTime.now();
    final items = await _service.loadSession(
      now: localNow.toUtc(),
      localDayStartUtc:
          DateTime(localNow.year, localNow.month, localNow.day).toUtc(),
      dailyNewLimit: ref.watch(flashcardDailyNewLimitProvider),
      tag: tag,
    );
    return FlashcardSessionState(
      items: items,
      index: 0,
      answerVisible: false,
      shownAt: localNow,
      startedAt: localNow,
      ratings: {
        for (final rating in FlashcardRating.values) rating: 0,
      },
    );
  }

  void showAnswer() {
    final value = state.requireValue;
    state = AsyncData(value.copyWith(answerVisible: true));
  }

  Map<FlashcardRating, Flashcard> preview({required DateTime now}) {
    final value = state.requireValue;
    return _service.preview(value.current, now: now);
  }

  Future<FlashcardUndoToken> rate(
    FlashcardRating rating, {
    required DateTime now,
  }) async {
    final value = state.requireValue;
    final undo = await _service.rate(
      value.current,
      rating,
      now: now,
      durationMs: now.difference(value.shownAt).inMilliseconds,
    );
    final ratings = Map<FlashcardRating, int>.from(value.ratings);
    ratings[rating] = ratings[rating]! + 1;
    state = AsyncData(value.copyWith(
      index: value.index + 1,
      answerVisible: false,
      shownAt: DateTime.now(),
      ratings: ratings,
    ));
    ref.invalidate(flashcardOverviewProvider);
    return undo;
  }

  Future<void> undo(
    FlashcardUndoToken token,
    FlashcardRating rating,
  ) async {
    await _service.undo(token);
    final value = state.requireValue;
    final ratings = Map<FlashcardRating, int>.from(value.ratings);
    ratings[rating] = ratings[rating]! - 1;
    state = AsyncData(value.copyWith(
      index: value.index - 1,
      answerVisible: true,
      ratings: ratings,
    ));
    ref.invalidate(flashcardOverviewProvider);
  }
}

final flashcardSessionProvider = AsyncNotifierProvider.autoDispose
    .family<FlashcardSessionNotifier, FlashcardSessionState, int?>(
  FlashcardSessionNotifier.new,
);

Future<FlashcardOverview> _loadFlashcardOverview(int? tag) async {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).toUtc();
  final introduced = await flashcardDao.countIntroduced(
    start: start,
    end: start.add(const Duration(days: 1)),
  );
  final remaining =
      (settings.flashcardDailyNewLimit - introduced).clamp(0, 9999);
  final due = await flashcardDao.getDueCards(now: now.toUtc(), tag: tag);
  final newWords = await flashcardDao.getNewWords(limit: remaining, tag: tag);
  final completed = await flashcardDao.countReviews(
    start: start,
    end: start.add(const Duration(days: 1)),
  );
  return FlashcardOverview(
    due: due.length,
    newCards: newWords.length,
    done: completed,
  );
}
