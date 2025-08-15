import "dart:collection";

import "package:flutter/material.dart";
import "package:table_calendar/table_calendar.dart";

abstract class StatsViewModel<T> with ChangeNotifier {
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  final Map<DateTime, int> _counts = LinkedHashMap(
    equals: isSameDay,
    hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
  );

  UnmodifiableMapView<DateTime, int> get counts => UnmodifiableMapView(_counts);

  DateTime _focusedDay = DateTime.now();
  DateTime get focusedDay => _focusedDay;

  int get itemsInFocusedMonth {
    int count = 0;
    for (final entry in _counts.entries) {
      if (entry.key.year == _focusedDay.year &&
          entry.key.month == _focusedDay.month) {
        count += entry.value;
      }
    }
    return count;
  }

  int get maxItemsInFocusedMonth {
    int maxCount = 0;
    for (final entry in _counts.entries) {
      if (entry.key.year == _focusedDay.year &&
          entry.key.month == _focusedDay.month) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
        }
      }
    }
    return maxCount > 0 ? maxCount : 1;
  }

  StatsViewModel() {
    _fetchStats();
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

  Future<List<T>> fetchData();
  DateTime getCreatedAt(T item);

  void _fetchStats() async {
    final items = await fetchData();
    for (final item in items) {
      final createdAt = getCreatedAt(item);
      final day = DateTime.utc(createdAt.year, createdAt.month, createdAt.day);
      _counts[day] = (_counts[day] ?? 0) + 1;
    }
    _isLoading = false;
    notifyListeners();
  }

  List<int> getEventsForDay(DateTime day) {
    return [_counts[day] ?? 0];
  }
}
