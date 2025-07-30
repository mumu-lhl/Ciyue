import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter/material.dart";

class WordbookModel extends ChangeNotifier {
  late Future<List<WordbookData>> allWords;
  late Future<List<WordbookTag>> tags;
  DateTime? selectedDate;
  int? selectedTag;
  bool isMultiSelectMode = false;
  List<WordbookData> selectedWords = [];

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
    notifyListeners();
  }
}
