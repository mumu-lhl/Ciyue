import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/settings.dart";
import "package:material_ui/material_ui.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/main/wordbook/dialogs.dart";
import "package:ciyue/ui/core/text_buttons.dart";
import "package:fuzzy/fuzzy.dart";

class WordbookModel extends ChangeNotifier {
  // These used to be `late` fields filled in by the word list widget's
  // initState. The word book page now reads `allWords` while building its
  // split view, which happens before any child is mounted, so the lists have
  // to be loadable on their own.
  Future<List<WordbookData>>? _allWords;
  Future<List<WordbookData>> get allWords => _allWords ??= _loadWords();
  set allWords(Future<List<WordbookData>> value) => _allWords = value;

  Future<List<WordbookTag>>? _tags;
  Future<List<WordbookTag>> get tags => _tags ??= wordbookTagsDao.getAllTags();
  set tags(Future<List<WordbookTag>> value) => _tags = value;

  int totalWordCount = 0;
  DateTime? selectedDate;
  int? selectedTag;
  bool isMultiSelectMode = false;
  List<WordbookData> selectedWords = [];
  List<String> searchResults = [];
  bool fuzzySearch = false;
  String? _selectedWord;

  String? get selectedWord => _selectedWord;

  set selectedWord(String? word) {
    if (_selectedWord != word) {
      _selectedWord = word;
      notifyListeners();
    }
  }

  WordbookModel() {
    loadTotalWordCount();
  }

  void toggleFuzzySearch() {
    fuzzySearch = !fuzzySearch;
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      searchResults.clear();
    } else {
      if (fuzzySearch) {
        // SQL pre-filter limits candidates instead of full table scan.
        final candidates = await wordbookDao.searchWordsForFuzzy(query);
        final fuse = Fuzzy(
          candidates.map((e) => e.word).toList(),
          options: FuzzyOptions(threshold: 0.2),
        );
        final results = fuse.search(query, 40);
        searchResults = results.map((r) => r.item as String).toList();
      } else {
        final words = await wordbookDao.searchWords(query);
        searchResults = words.map((e) => e.word).toList();
      }
    }

    Future.microtask(() => notifyListeners());
  }

  Future<void> add(String word, {int? tag}) async {
    await wordbookDao.addWord(word, tag: tag);
    updateWordList();
  }

  Future<void> addAllWords(List<WordbookData> data) async {
    await wordbookDao.addAllWords(data);
    updateWordList();
  }

  Future<void> delete(String word, {int? tag}) async {
    await wordbookDao.removeWord(word, tag: tag);
    updateWordList();
  }

  Future<void> removeWordWithAllTags(String word) async {
    await wordbookDao.removeWordWithAllTags(word);
    updateWordList();
  }

  Future<void> removeWords(List<WordbookData> words) async {
    await wordbookDao.removeWords(words);
    updateWordList();
  }

  Future<void> loadTotalWordCount() async {
    totalWordCount = await wordbookDao.countTotalWords();
    notifyListeners();
  }

  Future<void> deleteSelectedWords() async {
    await wordbookDao.removeWords(selectedWords);
    selectedWords.clear();
    isMultiSelectMode = false;
    updateWordList();
  }

  void selectWord(WordbookData word) {
    if (selectedWords.contains(word)) {
      selectedWords.remove(word);
    } else {
      selectedWords.add(word);
    }

    if (selectedWords.isEmpty) {
      isMultiSelectMode = false;
    }

    notifyListeners();
  }

  void toggleMultiSelectMode() {
    isMultiSelectMode = !isMultiSelectMode;
    if (!isMultiSelectMode) {
      selectedWords.clear();
    }
    notifyListeners();
  }

  void updateSelectedDate(DateTime? date) {
    selectedDate = date;
    notifyListeners();
  }

  void updateSelectedTag(int? tag) {
    selectedTag = tag;
    notifyListeners();
  }

  void updateTags() {
    tags = wordbookTagsDao.getAllTags();
    notifyListeners();
  }

  Future<List<WordbookData>> _loadWords() {
    if (selectedDate != null) {
      return wordbookDao.getWordsByYearMonth(
        selectedDate!.year,
        selectedDate!.month,
        tag: selectedTag,
      );
    }
    return wordbookDao.getAllWordsWithTag(
      tag: selectedTag,
      skipTagged: selectedTag == null && settings.skipTaggedWord,
    );
  }

  /// Reloads both lists without notifying listeners.
  ///
  /// Called from a page's initState, where notifying would rebuild the tree
  /// while it is still being built. Later refreshes go through
  /// [updateWordList], which notifies via [loadTotalWordCount].
  void refreshLists() {
    allWords = _loadWords();
    tags = wordbookTagsDao.getAllTags();
  }

  void updateWordList() {
    allWords = _loadWords();
    loadTotalWordCount();
  }

  Future<void> showDeleteConfirmationDialog(BuildContext context) async {
    final count = selectedWords.length;
    final locale = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale.confirmDelete),
        content: Text(locale.confirmDeleteWords(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(locale.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(locale.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await deleteSelectedWords();
    }
  }

  Future<void> addTag(String tagName) async {
    if (tagName.isEmpty) return;
    await wordbookTagsDao.addTag(tagName);
    await wordbookTagsDao.existTag();
    updateTags();
  }

  Future<void> showAddTagDialog(BuildContext context) async {
    final locale = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final textController = TextEditingController();

        return AlertDialog(
          title: Text(locale.addTag),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(labelText: locale.tagName),
            controller: textController,
            onSubmitted: (String tagName) async {
              await addTag(tagName);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            TextCloseButton(),
            TextButton(
              child: Text(locale.add),
              onPressed: () async {
                await addTag(textController.text);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showTagsListDialog(BuildContext context) async {
    final tagsList = await tags;
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final tagsMap = <int, WordbookTag>{};
        for (final tag in tagsList) {
          tagsMap[tag.id] = tag;
        }

        final tagsDisplay = wordbookTagsDao.tagsOrder.isEmpty
            ? tagsList
            : wordbookTagsDao.tagsOrder
                  .map((e) => tagsMap[e])
                  .whereType<WordbookTag>()
                  .toList();

        return TagListDialog(
          tagsDisplay: tagsDisplay,
          buildAddTag: (context) => showAddTagDialog(context),
        );
      },
    );
  }

  Future<void> reorderTags(
    int oldIndex,
    int newIndex,
    List<WordbookTag> tagsDisplay,
  ) async {
    final tag = tagsDisplay.removeAt(oldIndex);
    tagsDisplay.insert(newIndex, tag);

    wordbookTagsDao.tagsOrder = tagsDisplay.map((e) => e.id).toList();
    await wordbookTagsDao.updateTagsOrder();
    updateTags();
  }

  Future<void> removeTag(int tagId) async {
    await wordbookTagsDao.removeTag(tagId);
    await wordbookTagsDao.existTag();
    updateTags();
  }
}
