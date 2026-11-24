import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/models/search_mode.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/viewModels/headword_pane.dart";
import "package:test/test.dart";

class _FakeSource implements DictionarySource {
  _FakeSource(this.entries);

  final List<String> entries;

  @override
  int get id => 1;

  @override
  Future<String?> resolveExactKey(String word) async =>
      entries.contains(word) ? word : null;

  @override
  Future<Map<String, String>> resolveKeys(Iterable<String> words) async => {
    for (final word in words)
      if (entries.contains(word)) word: word,
  };

  @override
  Future<List<String>> search(
    String query, {
    int limit = defaultHeadwordSearchLimit,
  }) async =>
      entries.where((word) => word.startsWith(query)).take(limit).toList();

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words, {
    Map<String, String>? resolvedKeys,
  }) async => const [];
}

class _NoMorphology implements MorphologyProvider {
  @override
  Future<List<String>> stems(String word) async => const [];

  @override
  Future<List<String>> suggestions(String word) async => const [];
}

HeadwordPaneModel _model() => HeadwordPaneModel(
  lookup: DictionaryLookup(
    dictionaries: () => [
      _FakeSource(["app", "apple", "apply", "banana"]),
    ],
    morphology: _NoMorphology(),
    morphologyEnabled: () => false,
    lookupMode: () => HunspellLookupMode.fallback,
  ),
);

/// Waits out the model's debounce and the (already synchronous) search.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 400));

void main() {
  test("arrow keys walk the list and stop at both ends", () async {
    final model = _model();
    addTearDown(model.dispose);
    model.update("app", mode: SearchMode.prefix);
    await _settle();

    expect(model.rows.map((row) => row.headword), ["app", "apple", "apply"]);
    expect(model.selectedIndex, -1);

    expect(model.moveSelection(1)?.headword, "app");
    expect(model.moveSelection(1)?.headword, "apple");
    expect(model.moveSelection(1)?.headword, "apply");
    // The last row is the end of the list, not a wrap-around.
    expect(model.moveSelection(1)?.headword, "apply");
    expect(model.selectedIndex, 2);
    expect(model.moveSelection(-1)?.headword, "apple");
  });

  test("a backward move with nothing selected starts at the bottom", () async {
    final model = _model();
    addTearDown(model.dispose);
    model.update("app", mode: SearchMode.prefix);
    await _settle();

    expect(model.moveSelection(-1)?.headword, "apply");
  });

  test(
    "new text clears the selection and empty text clears the rows",
    () async {
      final model = _model();
      addTearDown(model.dispose);
      model.update("app", mode: SearchMode.prefix);
      await _settle();
      model.moveSelection(1);
      expect(model.selectedIndex, 0);

      model.update("appl", mode: SearchMode.prefix);
      expect(model.selectedIndex, -1);

      model.update("", mode: SearchMode.prefix);
      expect(model.isEmpty, isTrue);
      expect(model.rows, isEmpty);
      expect(model.moveSelection(1), isNull);
    },
  );
}
