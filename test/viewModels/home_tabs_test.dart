import "package:ciyue/viewModels/home.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("HomeModel Tab Management", () {
    test("initial state has empty tabs", () {
      final model = HomeModel();
      expect(model.tabs, isEmpty);
      expect(model.activeTabIndex, -1);
      expect(model.selectedWord, isNull);
    });

    test("selectedWord creates and updates tabs", () {
      final model = HomeModel();
      model.selectedWord = "apple";

      expect(model.tabs, ["apple"]);
      expect(model.activeTabIndex, 0);
      expect(model.selectedWord, "apple");

      // Changing selectedWord replaces the active tab when no duplicate exists
      model.selectedWord = "banana";
      expect(model.tabs, ["banana"]);
      expect(model.activeTabIndex, 0);
      expect(model.selectedWord, "banana");
    });

    test("openWordInNewTab adds distinct tabs and switches to them", () {
      final model = HomeModel();
      model.selectedWord = "apple";
      model.openWordInNewTab("banana");

      expect(model.tabs, ["apple", "banana"]);
      expect(model.activeTabIndex, 1);
      expect(model.selectedWord, "banana");

      // Opening existing word switches to it without duplicating
      model.openWordInNewTab("apple");
      expect(model.tabs, ["apple", "banana"]);
      expect(model.activeTabIndex, 0);
      expect(model.selectedWord, "apple");
    });

    test("newTab creates empty tab and overwrites it on word selection", () {
      final model = HomeModel();
      model.selectedWord = "apple";
      model.newTab();

      expect(model.tabs, ["apple", ""]);
      expect(model.activeTabIndex, 1);

      model.selectedWord = "orange";
      expect(model.tabs, ["apple", "orange"]);
      expect(model.activeTabIndex, 1);
      expect(model.selectedWord, "orange");
    });

    test("closeTab adjusts active index correctly", () {
      final model = HomeModel();
      model.openWordInNewTab("first");
      model.openWordInNewTab("second");
      model.openWordInNewTab("third");

      expect(model.tabs, ["first", "second", "third"]);
      expect(model.activeTabIndex, 2);

      // Close the currently active (last) tab
      model.closeTab(2);
      expect(model.tabs, ["first", "second"]);
      expect(model.activeTabIndex, 1);
      expect(model.selectedWord, "second");

      // Close middle tab when last tab is active
      model.openWordInNewTab("third");
      model.switchToTab(0);
      model.closeTab(1);
      expect(model.tabs, ["first", "third"]);
      expect(model.activeTabIndex, 0);
      expect(model.selectedWord, "first");

      // Close all remaining tabs
      model.closeAllTabs();
      expect(model.tabs, isEmpty);
      expect(model.activeTabIndex, -1);
      expect(model.selectedWord, isNull);
    });

    test("nextTab and previousTab cycle through tabs", () {
      final model = HomeModel();
      model.openWordInNewTab("a");
      model.openWordInNewTab("b");
      model.openWordInNewTab("c");

      model.switchToTab(0);
      expect(model.selectedWord, "a");

      model.nextTab();
      expect(model.selectedWord, "b");

      model.nextTab();
      expect(model.selectedWord, "c");

      model.nextTab();
      expect(model.selectedWord, "a");

      model.previousTab();
      expect(model.selectedWord, "c");
    });

    test("reorderTabs moves tabs and keeps active tab synchronized", () {
      final model = HomeModel();
      model.openWordInNewTab("apple");
      model.openWordInNewTab("banana");
      model.openWordInNewTab("cherry");

      model.switchToTab(1); // active: banana
      expect(model.selectedWord, "banana");

      // Move apple from 0 to after cherry (destination index 2)
      model.reorderTabs(0, 2);
      expect(model.tabs, ["banana", "cherry", "apple"]);
      expect(model.activeTabIndex, 0); // banana is now index 0
      expect(model.selectedWord, "banana");

      // Move cherry from 1 to 0
      model.reorderTabs(1, 0);
      expect(model.tabs, ["cherry", "banana", "apple"]);
      expect(model.activeTabIndex, 1); // banana is now index 1
      expect(model.selectedWord, "banana");
    });
  });

  group("HomeModel Tab History & Navigation", () {
    test("navigateInCurrentTab builds history and enables back/forward", () {
      final model = HomeModel();
      expect(model.canGoBack, isFalse);
      expect(model.canGoForward, isFalse);

      model.navigateInCurrentTab("apple");
      expect(model.tabs, ["apple"]);
      expect(model.selectedWord, "apple");
      expect(model.canGoBack, isFalse);
      expect(model.canGoForward, isFalse);

      // Navigate to second word in same tab
      model.navigateInCurrentTab("banana");
      expect(model.tabs, ["banana"]);
      expect(model.selectedWord, "banana");
      expect(model.canGoBack, isTrue);
      expect(model.canGoForward, isFalse);

      // Navigate to third word
      model.navigateInCurrentTab("cherry");
      expect(model.selectedWord, "cherry");
      expect(model.canGoBack, isTrue);
      expect(model.canGoForward, isFalse);

      // Go back to banana
      model.goBack();
      expect(model.selectedWord, "banana");
      expect(model.canGoBack, isTrue);
      expect(model.canGoForward, isTrue);

      // Go back to apple
      model.goBack();
      expect(model.selectedWord, "apple");
      expect(model.canGoBack, isFalse);
      expect(model.canGoForward, isTrue);

      // Go forward to banana
      model.goForward();
      expect(model.selectedWord, "banana");
      expect(model.canGoBack, isTrue);
      expect(model.canGoForward, isTrue);

      // Go forward to cherry
      model.goForward();
      expect(model.selectedWord, "cherry");
      expect(model.canGoBack, isTrue);
      expect(model.canGoForward, isFalse);
    });

    test("navigating after going back truncates forward history", () {
      final model = HomeModel();
      model.navigateInCurrentTab("apple");
      model.navigateInCurrentTab("banana");
      model.navigateInCurrentTab("cherry");

      model.goBack(); // at banana
      expect(model.selectedWord, "banana");
      expect(model.canGoForward, isTrue);

      // Navigate to a new word 'date', truncating 'cherry'
      model.navigateInCurrentTab("date");
      expect(model.selectedWord, "date");
      expect(model.canGoBack, isTrue);
      expect(model.canGoForward, isFalse);

      model.goBack();
      expect(model.selectedWord, "banana");

      model.goBack();
      expect(model.selectedWord, "apple");

      model.goForward();
      expect(model.selectedWord, "banana");

      model.goForward();
      expect(model.selectedWord, "date");
      expect(model.canGoForward, isFalse);
    });

    test("tab overview state toggles and closes on tab selection", () {
      final model = HomeModel();
      expect(model.isTabOverviewOpen, isFalse);

      model.toggleTabOverview();
      expect(model.isTabOverviewOpen, isTrue);

      model.openWordInNewTab("apple");
      model.openWordInNewTab("banana");

      model.setTabOverviewOpen(true);
      expect(model.isTabOverviewOpen, isTrue);

      model.switchToTab(0);
      expect(model.isTabOverviewOpen, isFalse);
      expect(model.selectedWord, "apple");
    });
  });
}
