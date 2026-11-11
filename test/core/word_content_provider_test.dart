import "package:ciyue/core/providers.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

class _FakeDict extends Mdict {
  _FakeDict(this.label) : super(path: "unused");

  final String label;

  @override
  bool get isReady => true;

  @override
  String wrapContentWithResources(String content) => "$label|$content";
}

void main() {
  const params = (word: "Home", dictId: 1);

  setUp(() {
    dictManager.dicts.clear();
    dictManager.dictIds = [];
    dictManager.markLoaded();
  });

  tearDown(() {
    dictManager.dicts.clear();
    dictManager.dictIds = [];
  });

  test(
    "re-enabling a dictionary does not reuse the blank entry cached while it "
    "was closed",
    () async {
      dictManager.dictIds = [1];
      dictManager.dicts[1] = _FakeDict("first");

      final container = ProviderContainer(
        overrides: [
          // The content provider only needs the lookup to echo the mounted
          // dictionary, so the test does not have to wait for real indexes.
          dictionaryLookupProvider.overrideWith((ref, word) async {
            ref.watch(dictSetVersionProvider);
            final dict = dictManager.dicts[1];
            if (dict == null) {
              return const DictionaryLookupResult(entriesByDictionary: {});
            }
            final label = (dict as _FakeDict).label;
            return DictionaryLookupResult(
              entriesByDictionary: {
                1: [
                  DictionaryEntryData(headword: word, content: "<p>$label</p>"),
                ],
              },
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      // Keep a listener alive: the provider keeps a five minute keep-alive, and
      // the bug only shows when the blank entry survives in its cache.
      final subscription = container.listen(
        wordContentProvider(params),
        (_, _) {},
      );
      addTearDown(subscription.close);

      expect(
        await container.read(wordContentProvider(params).future),
        "first|<p>first</p>",
      );

      // The dictionary leaves the group and is disabled.
      dictManager.dicts.remove(1);
      dictManager.dictIds = [];
      container.read(dictSetVersionProvider.notifier).bump();
      expect(await container.read(wordContentProvider(params).future), "");

      // The same id is enabled again with a new instance.
      dictManager.dictIds = [1];
      dictManager.dicts[1] = _FakeDict("second");
      container.read(dictSetVersionProvider.notifier).bump();

      expect(
        await container.read(wordContentProvider(params).future),
        "second|<p>second</p>",
      );
    },
  );
}
