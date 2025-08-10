import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter/material.dart";

class WordbookModel extends ChangeNotifier {
  late Future<List<WordbookData>> allWords;
  late Future<List<WordbookTag>> tags;
  int totalWordCount = 0;
  DateTime? selectedDate;
  int? selectedTag;
  bool isMultiSelectMode = false;
  List<WordbookData> selectedWords = [];

  WordbookModel() {
    loadTotalWordCount();
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

  void updateWordList() {
    if (selectedDate != null) {
      allWords = wordbookDao.getWordsByYearMonth(
        selectedDate!.year,
        selectedDate!.month,
        tag: selectedTag,
      );
    } else {
      allWords = wordbookDao.getAllWordsWithTag(
        tag: selectedTag,
        skipTagged: selectedTag == null && settings.skipTaggedWord,
      );
    }
    loadTotalWordCount();
  }
}
