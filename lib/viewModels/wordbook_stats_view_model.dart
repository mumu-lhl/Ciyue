import "dart:collection";

import "package:ciyue/database/app/daos.dart";
import "package:flutter/material.dart";
import "package:table_calendar/table_calendar.dart";

class WordbookStatsViewModel with ChangeNotifier {
  final WordbookDao _wordbookDao;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Using a LinkedHashMap to preserve the order of insertion.
  final Map<DateTime, int> _wordCounts = LinkedHashMap(
    equals: isSameDay,
    hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
  );

  // Public getter for the word counts.
  UnmodifiableMapView<DateTime, int> get wordCounts =>
      UnmodifiableMapView(_wordCounts);

  DateTime _focusedDay = DateTime.now();

  DateTime get focusedDay => _focusedDay;

  int get wordsInFocusedMonth {
    int count = 0;
    for (final entry in _wordCounts.entries) {
      if (entry.key.year == _focusedDay.year &&
          entry.key.month == _focusedDay.month) {
        count += entry.value;
      }
    }
    return count;
  }

  int get maxWordsInFocusedMonth {
    int maxCount = 0;
    for (final entry in _wordCounts.entries) {
      if (entry.key.year == _focusedDay.year &&
          entry.key.month == _focusedDay.month) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
        }
      }
    }
    return maxCount > 0 ? maxCount : 1;
  }

  WordbookStatsViewModel(this._wordbookDao) {
    _fetchWordbookStats();
  }

  void onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    notifyListeners();
  }

  void onDatePicked(DateTime? pickedDate) {
    if (pickedDate != null) {
      _focusedDay = pickedDate;
      notifyListeners();
    }
  }

  void _fetchWordbookStats() async {
    final words = await _wordbookDao.getAllWords();
    for (final word in words) {
      final day = DateTime.utc(
          word.createdAt.year, word.createdAt.month, word.createdAt.day);
      _wordCounts[day] = (_wordCounts[day] ?? 0) + 1;
    }
    _isLoading = false;
    notifyListeners();
  }

  List<int> getEventsForDay(DateTime day) {
    return [_wordCounts[day] ?? 0];
  }
}
