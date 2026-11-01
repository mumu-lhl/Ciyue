import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:talker_flutter/talker_flutter.dart";

late final Color? accentColor;
final AppDatabase mainDatabase = appDatabase();
late final PackageInfo packageInfo;
late final SharedPreferencesWithCache prefs;
late final VoidCallback refreshAll;
late final FlutterTts flutterTts;
String searchWordFromProcessText = "";

/// Set by the desktop `--no-tts` option. Only affects the current process,
/// so the user's saved pronunciation settings are left untouched.
bool ttsDisabledByCommandLine = false;

// Each FlutterEngine has its own isolate, so this flag identifies the current
// engine rather than the whole Android process.
bool runningInFloatingWindow = false;

// The controller of the dictionary tab bar.
//
// The shortcut that switches dictionaries lives in the home page, outside
// the entry, so it needs a way to reach the tab bar's controller. The entry
// sets it while the tab layout is on screen and clears it when it leaves.
TabController? dictTabController;

// Pages the entry in the expansion layout.
//
// The expansion layout's scroll controller lives in the entry page, while
// the shortcut that pages it sits in the home page, so the entry hands the
// action over.
void Function(String key)? expansionPageHandler;

// The search box the reader last put the cursor in.
FocusNode? activeSearchFocusNode;
SearchController? activeSearchController;

// The search box the page on screen owns. The key bridge has no page context
// of its own, so Esc from an entry has to reach the right box through this.
FocusNode? pageSearchFocusNode;

// The entry WebViews that can take the focus back, keyed by the state object
// that owns them: two entries showing the same dictionary must not collide.
final Map<
  Object,
  ({int Function() dictId, bool Function() isCurrent, void Function() focus})
>
entryFocusTargets = {};

// The dictionary the reader is looking at.
int? activeEntryDictId;

// Gives the focus back to the entry the reader is looking at.
//
// The TabBarView keeps the neighbouring dictionary pages alive, so simply
// asking the last created WebView would hand the focus to an off-screen tab.
// The tab controller records which dictionary is on screen, and this picks its
// WebView.
void focusActiveEntry() {
  final dictId = activeEntryDictId;
  talker.info(
    "focusActiveEntry: dict=$dictId targets=${entryFocusTargets.length}",
  );
  if (dictId == null) return;
  final current = entryFocusTargets.values.where(
    (target) => target.dictId() == dictId && target.isCurrent(),
  );
  if (current.isNotEmpty) {
    talker.info("focusActiveEntry: current=${current.length}");
    current.last.focus();
    return;
  }
  final matches = entryFocusTargets.values.where(
    (target) => target.dictId() == dictId,
  );
  if (matches.isNotEmpty) {
    talker.info("focusActiveEntry: off-route=${matches.length}");
    matches.last.focus();
  }
}

/// Gives the focus back to the entry after the current focus change settles.
///
/// The unfocus and the WebView focus request can land in the same frame, so
/// the request is repeated once after the frame. Frames are used rather than a
/// timer so widget tests do not leave a pending timer behind.
void focusActiveEntrySoon() {
  focusActiveEntry();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    focusActiveEntry();
  });
}

List<dynamic> ttsEngines = [];
final List<dynamic> ttsLanguages = [];
String? windowsWebview2Directory;

// Daos
final dictGroupDao = DictGroupDao(mainDatabase);
final dictionaryListDao = DictionaryListDao(mainDatabase);
final hunspellSourceDao = HunspellSourceDao(mainDatabase);
final historyDao = HistoryDao(mainDatabase);
final mddAudioListDao = MddAudioListDao(mainDatabase);
final mddAudioResourceDao = MddAudioResourceDao(mainDatabase);
final wordbookDao = WordbookDao(mainDatabase);
final wordbookTagsDao = WordbookTagsDao(mainDatabase);
final flashcardDao = FlashcardDao(mainDatabase);
final writingCheckHistoryDao = WritingCheckHistoryDao(mainDatabase);
final translateHistoryDao = TranslateHistoryDao(mainDatabase);

final talker = TalkerFlutter.init();
