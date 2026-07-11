import "package:ciyue/ui/pages/flashcards/providers.dart";
import "package:flutter_test/flutter_test.dart";
import "package:riverpod/riverpod.dart";

void main() {
  test("overview reloads after provider invalidation", () async {
    var loads = 0;
    final container = ProviderContainer(overrides: [
      flashcardOverviewLoaderProvider.overrideWithValue((tag) async {
        loads++;
        return FlashcardOverview(due: loads, newCards: 2, done: 3);
      }),
    ]);
    addTearDown(container.dispose);

    expect((await container.read(flashcardOverviewProvider(7).future)).due, 1);
    container.invalidate(flashcardOverviewProvider);
    expect((await container.read(flashcardOverviewProvider(7).future)).due, 2);
  });

  test("daily new-card limit supports large values safely", () {
    expect(normalizeFlashcardDailyLimit(5000), 5000);
    expect(normalizeFlashcardDailyLimit(10000), 9999);
    expect(normalizeFlashcardDailyLimit(-1), 0);
  });
}
