abstract interface class DictionarySource {
  int get id;

  Future<String?> resolveExactKey(String word);

  Future<List<String>> search(String query);

  Future<List<DictionaryEntryData>> readExactEntries(Iterable<String> words);
}

class DictionaryEntryData {
  final String headword;
  final String content;

  const DictionaryEntryData({required this.headword, required this.content});
}
