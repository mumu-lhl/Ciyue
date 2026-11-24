import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/models/translation_result.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/open_records.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/lookup_mode.dart";
import "package:ciyue/services/translation_sources.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:ciyue/ui/core/word_display/word_display.dart";
import "package:ciyue/ui/pages/lookup_popup/lookup_popup_page.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

class _FakeOpenRecordsRepository implements OpenRecordsRepository {
  @override
  Future<void> add(String word) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    return _FakeInAppWebViewWidget(params);
  }
}

class _FakeInAppWebViewWidget extends PlatformInAppWebViewWidget {
  // ignore: use_super_parameters
  _FakeInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams params)
    : super.implementation(params);

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) {
    throw UnimplementedError();
  }

  @override
  void dispose() {}
}

class _FakeTranslationSource extends TranslationSource {
  final String? resultText;
  final bool shouldThrow;

  const _FakeTranslationSource({this.resultText, this.shouldThrow = false});

  @override
  String get id => "fake";

  @override
  String get name => "Fake";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (shouldThrow) throw Exception("boom");
    return TranslationResult(text: resultText ?? "translated:$text");
  }
}

class _CountingFakeTranslationSource extends TranslationSource {
  static int calls = 0;

  @override
  String get id => "counting";

  @override
  String get name => "Counting";

  @override
  bool get requiresConfig => false;

  @override
  bool get isConfigured => true;

  @override
  Future<TranslationResult> translate(
    BuildContext context, {
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    calls++;
    return TranslationResult(text: "translated:$text");
  }
}

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
    InAppWebViewPlatform.instance = _FakeInAppWebViewPlatform();
  });

  const dictIds = [10, 20, 30];

  setUp(() {
    for (final id in dictIds) {
      dictManager.dicts[id] = Mdict(path: "unused_$id")
        ..id = id
        ..title = "dict $id"
        ..port = 1;
    }
    settings.dictionarySwitchStyle = DictionarySwitchStyle.tag;
    settings.aiExplainWord = false;
  });

  tearDown(() {
    for (final id in dictIds) {
      dictManager.dicts.remove(id);
    }
    lookupPopupResolveSources = TranslationSourcesConfig.resolve;
  });

  Future<void> pumpPopup(
    WidgetTester tester, {
    String text = "apple",
    LookupMode mode = LookupMode.lookup,
    VoidCallback? onClose,
  }) async {
    tester.view.physicalSize = const Size(440, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validDictIdsProvider.overrideWith((ref, word) async => dictIds),
          dictionaryLookupProvider.overrideWith(
            (ref, word) async =>
                const DictionaryLookupResult(entriesByDictionary: {}),
          ),
          wordContentProvider.overrideWith(
            (ref, params) async => "<div>content</div>",
          ),
          openRecordsRepositoryProvider.overrideWithValue(
            _FakeOpenRecordsRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LookupPopupPage(
            text: text,
            initialMode: mode,
            onClose: onClose ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets("lookup mode renders WordDisplay for the given word", (
    tester,
  ) async {
    await pumpPopup(tester, text: "apple");

    expect(tester.takeException(), isNull);
    final display = tester.widget<WordDisplay>(find.byType(WordDisplay));
    expect(display.word, "apple");
    expect(display.showBackButton, isFalse);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey("lookup_popup_search_field")),
    );
    expect(field.controller!.text, "apple");
    // The top bar's focus behaviour: the field must not grab focus.
    expect(field.autofocus, isFalse);
  });

  testWidgets("mode switch flips lookup to translate and back", (tester) async {
    await pumpPopup(tester, text: "apple");

    await tester.tap(find.text("Translate"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(WordDisplay), findsNothing);
    // No source is configured under the default test prefs.
    expect(find.textContaining("No translation source"), findsOneWidget);

    await tester.tap(find.text("Lookup"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(WordDisplay), findsOneWidget);
    expect(tester.widget<WordDisplay>(find.byType(WordDisplay)).word, "apple");
  });

  testWidgets("close button calls onClose", (tester) async {
    var closed = false;
    await pumpPopup(tester, onClose: () => closed = true);

    await tester.tap(find.byKey(const ValueKey("lookup_popup_close_button")));
    expect(closed, isTrue);
  });

  testWidgets("submitting a new word swaps the WordDisplay word", (
    tester,
  ) async {
    await pumpPopup(tester, text: "apple");

    final field = find.byKey(const ValueKey("lookup_popup_search_field"));
    await tester.enterText(field, "banana");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(tester.widget<WordDisplay>(find.byType(WordDisplay)).word, "banana");
  });

  testWidgets("empty search submit does nothing", (tester) async {
    await pumpPopup(tester, text: "apple");

    final field = find.byKey(const ValueKey("lookup_popup_search_field"));
    await tester.enterText(field, "   ");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(tester.widget<WordDisplay>(find.byType(WordDisplay)).word, "apple");
  });

  testWidgets("translate mode shows the top source result", (tester) async {
    lookupPopupResolveSources = () => (
      active: const [_FakeTranslationSource(resultText: "苹果")],
      skipped: const <TranslationSource>[],
    );
    await pumpPopup(tester, text: "apple", mode: LookupMode.translate);
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text("苹果"), findsOneWidget);
    expect(find.text("apple"), findsWidgets);
  });

  testWidgets("a second lookup while open updates the word in place", (
    tester,
  ) async {
    await pumpPopup(tester, text: "apple");
    expect(tester.widget<WordDisplay>(find.byType(WordDisplay)).word, "apple");

    // The host reuses the page element for the next request, so the new
    // text arrives as an updated widget, not a new state.
    await pumpPopup(tester, text: "banana");

    expect(tester.takeException(), isNull);
    expect(tester.widget<WordDisplay>(find.byType(WordDisplay)).word, "banana");
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey("lookup_popup_search_field")),
    );
    expect(field.controller!.text, "banana");
  });

  testWidgets("translate error state shows retry and retries", (tester) async {
    lookupPopupResolveSources = () => (
      active: const [_FakeTranslationSource(shouldThrow: true)],
      skipped: const <TranslationSource>[],
    );
    await pumpPopup(tester, text: "apple", mode: LookupMode.translate);
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text("Translation failed."), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);

    await tester.tap(find.text("Retry"));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Translation failed."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("popup WordDisplay has no title search box or chat button", (
    tester,
  ) async {
    await pumpPopup(tester, text: "apple");

    expect(tester.takeException(), isNull);
    final display = tester.widget<WordDisplay>(find.byType(WordDisplay));
    expect(display.inLookupPopup, isTrue);
    // The popup already has its own search field above the display, and
    // the title box's picks would move the main window's selection.
    expect(find.byType(WordSearchBarWithSuggestions), findsNothing);
    // The chat button pushes a route the popup does not have.
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
  });

  testWidgets("popup WordDisplay does not take over shared globals", (
    tester,
  ) async {
    expect(dictTabController, isNull);
    expect(activeEntryDictId, isNull);

    await pumpPopup(tester, text: "apple");

    expect(tester.takeException(), isNull);
    expect(dictTabController, isNull);
    expect(activeEntryDictId, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(dictTabController, isNull);
    expect(activeEntryDictId, isNull);
  });

  testWidgets("dictionary links navigate inside the popup", (tester) async {
    await pumpPopup(tester, text: "apple");
    final context = tester.element(find.byType(WordDisplay));
    final homeModel = ProviderScope.containerOf(context)
        .read(homeModelProvider);
    final selectedBefore = homeModel.selectedWord;

    handleOpenWordNavigation(context, "banana", newTab: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(homeModel.selectedWord, selectedBefore);
    expect(tester.widget<WordDisplay>(find.byType(WordDisplay)).word, "banana");
  });

  testWidgets("submitting a sentence re-decides the mode to translate", (
    tester,
  ) async {
    await pumpPopup(tester, text: "apple");

    final field = find.byKey(const ValueKey("lookup_popup_search_field"));
    await tester.enterText(field, "Hello! How are you");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(WordDisplay), findsNothing);
    expect(find.textContaining("No translation source"), findsOneWidget);
  });

  testWidgets("submitting a word from translate mode flips back to lookup", (
    tester,
  ) async {
    await pumpPopup(
      tester,
      text: "Hello! How are you",
      mode: LookupMode.translate,
    );

    final field = find.byKey(const ValueKey("lookup_popup_search_field"));
    await tester.enterText(field, "banana");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(tester.widget<WordDisplay>(find.byType(WordDisplay)).word, "banana");
  });

  testWidgets("switching modes reuses the cached translate result", (
    tester,
  ) async {
    _CountingFakeTranslationSource.calls = 0;
    lookupPopupResolveSources = () => (
      active: [_CountingFakeTranslationSource()],
      skipped: const <TranslationSource>[],
    );
    await pumpPopup(tester, text: "apple", mode: LookupMode.translate);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text("translated:apple"), findsOneWidget);
    expect(_CountingFakeTranslationSource.calls, 1);

    await tester.tap(find.text("Lookup"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WordDisplay), findsOneWidget);

    await tester.tap(find.text("Translate"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text("translated:apple"), findsOneWidget);
    expect(_CountingFakeTranslationSource.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
