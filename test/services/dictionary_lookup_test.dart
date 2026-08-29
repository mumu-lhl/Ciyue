import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/hunspell.dart";
import "package:test/test.dart";

void main() {
  test("disabled morphology keeps exact lookup only", () async {
    final morphology = FakeMorphology(stemsResult: ["rim"]);
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"rims": "rims content", "rim": "rim content"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: false,
    );

    final result = await lookup.lookup("rims");

    expect(result.entriesFor(1).map((entry) => entry.headword), ["rims"]);
    expect(morphology.stemCalls, 0);
  });

  test("fallback mode uses stems when the original is absent", () async {
    final morphology = FakeMorphology(stemsResult: ["rim", "unlisted"]);
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"rim": "rim content"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: true,
      mode: HunspellLookupMode.fallback,
    );

    final result = await lookup.lookup("rims");

    expect(result.entriesFor(1).map((entry) => entry.headword), ["rim"]);
    expect(morphology.stemCalls, 1);
  });

  test("fallback mode does not add stems when the original exists", () async {
    final morphology = FakeMorphology(stemsResult: ["rim"]);
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {"rims": "rims content", "rim": "rim content"},
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: true,
      mode: HunspellLookupMode.fallback,
    );

    final result = await lookup.lookup("rims");

    expect(result.entriesFor(1).map((entry) => entry.headword), ["rims"]);
  });

  test("supplement mode returns all matching stems in order", () async {
    final morphology = FakeMorphology(
      stemsResult: ["rim", "rim", "rims", "edge"],
    );
    final dictionary = FakeDictionarySource(
      id: 1,
      entries: {
        "rims": "rims content",
        "rim": "rim content",
        "edge": "edge content",
      },
    );
    final lookup = makeLookup(
      dictionary: dictionary,
      morphology: morphology,
      enabled: true,
      mode: HunspellLookupMode.supplement,
    );

    final result = await lookup.lookup("rims");

    expect(result.entriesFor(1).map((entry) => entry.headword), [
      "rims",
      "rim",
      "edge",
    ]);
  });

  test(
    "search suggestions append matching stems after prefix results",
    () async {
      final morphology = FakeMorphology(stemsResult: ["rim"]);
      final dictionary = FakeDictionarySource(
        id: 1,
        entries: {"rims": "rims content", "rim": "rim content"},
      );
      final lookup = makeLookup(
        dictionary: dictionary,
        morphology: morphology,
        enabled: true,
        mode: HunspellLookupMode.supplement,
      );

      expect(await lookup.searchSuggestions("rims"), ["rims", "rim"]);
    },
  );
}

DictionaryLookup makeLookup({
  required FakeDictionarySource dictionary,
  required FakeMorphology morphology,
  required bool enabled,
  HunspellLookupMode mode = HunspellLookupMode.fallback,
}) {
  return DictionaryLookup(
    dictionaries: () => [dictionary],
    morphology: morphology,
    morphologyEnabled: () => enabled,
    lookupMode: () => mode,
  );
}

class FakeMorphology implements MorphologyProvider {
  final List<String> stemsResult;
  int stemCalls = 0;

  FakeMorphology({required this.stemsResult});

  @override
  Future<List<String>> stems(String word) async {
    stemCalls++;
    return stemsResult;
  }

  @override
  Future<List<String>> suggestions(String word) async => const [];
}

class FakeDictionarySource implements DictionarySource {
  @override
  final int id;
  final Map<String, String> entries;

  FakeDictionarySource({required this.id, required this.entries});

  @override
  Future<String?> resolveExactKey(String word) async {
    if (entries.containsKey(word)) {
      return word;
    }
    final lowerCaseWord = word.toLowerCase();
    return entries.containsKey(lowerCaseWord) ? lowerCaseWord : null;
  }

  @override
  Future<List<String>> search(String query) async {
    return entries.keys.where((key) => key.startsWith(query)).toList();
  }

  @override
  Future<List<DictionaryEntryData>> readExactEntries(
    Iterable<String> words,
  ) async {
    final result = <DictionaryEntryData>[];
    final seen = <String>{};
    for (final word in words) {
      final key = await resolveExactKey(word);
      if (key != null && seen.add(key)) {
        result.add(DictionaryEntryData(headword: key, content: entries[key]!));
      }
    }
    return result;
  }
}
