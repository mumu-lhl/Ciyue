import "dart:io";

import "package:ciyue/services/storage_usage.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/storage_management.dart";
import "package:ciyue/viewModels/storage_usage.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as p;

/// Mimics the real full-text service: deletes the index files and records
/// the call.
class _RecordingFullTextClear {
  _RecordingFullTextClear(this.cache);

  final Directory cache;
  var calls = 0;

  Future<void> call() async {
    calls++;
    for (final name in [
      "full_text_search.db",
      "full_text_search.db-wal",
      "full_text_search.db-shm",
    ]) {
      final file = File(p.join(cache.path, name));
      if (await file.exists()) await file.delete();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory cache;
  late Directory support;
  late Directory documents;
  late Directory database;
  late Directory dictionaries;

  Future<void> writeSizedFile(String path, int size) async {
    await File(path).writeAsBytes(List.filled(size, 0));
  }

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp("storage_usage_test");
    cache = Directory(p.join(tempRoot.path, "cache"))..createSync();
    support = Directory(p.join(tempRoot.path, "support"))..createSync();
    documents = Directory(p.join(tempRoot.path, "documents"))..createSync();
    database = Directory(p.join(tempRoot.path, "database"))..createSync();
    dictionaries = Directory(p.join(tempRoot.path, "dictionaries"))
      ..createSync();

    // Known sizes, so the formatted sizes are exact.
    await writeSizedFile(p.join(cache.path, "full_text_search.db"), 2048);
    await writeSizedFile(p.join(cache.path, "dict_reader_1.cidx"), 1024);
    final pronunciation = Directory(p.join(cache.path, "online_pronunciation"))
      ..createSync();
    await writeSizedFile(p.join(pronunciation.path, "a.mp3"), 512);
    await writeSizedFile(p.join(cache.path, "foo.tmp"), 256);
    final audios = Directory(p.join(support.path, "audios"))..createSync();
    await writeSizedFile(p.join(audios.path, "pack.zip"), 4096);
    await writeSizedFile(p.join(database.path, "dictionary_list.sqlite"), 100);
    final chatImages = Directory(p.join(documents.path, "chat_images"))
      ..createSync();
    await writeSizedFile(p.join(chatImages.path, "img.png"), 300);
    await writeSizedFile(p.join(dictionaries.path, "dict.mdx"), 500);
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  StorageUsageService buildService() {
    return StorageUsageService(
      cacheDirectory: () async => cache,
      supportDirectory: () async => support,
      documentsDirectory: () async => documents,
      databaseDir: () async => database,
      dictionariesDirectoryPath: () async => dictionaries.path,
    );
  }

  /// The measurement runs in a background isolate: its result is only
  /// delivered on a pump, and the isolate itself needs real time to spawn
  /// and compute. Alternate pumping (delivers pending messages) with a
  /// short real-time wait (lets the isolate run). Only return once a
  /// refresh has actually been observed in flight and finished, so a
  /// not-yet-started refresh after a tap cannot exit the wait early.
  Future<void> waitForMeasured(
    WidgetTester tester,
    StorageUsageViewModel viewModel,
  ) async {
    var sawLoading = false;
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (viewModel.isLoading) {
        sawLoading = true;
      } else if (sawLoading) {
        return;
      }
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );
    }
    expect(viewModel.isLoading, isFalse);
  }

  Future<StorageUsageViewModel> pumpPage(
    WidgetTester tester,
    _RecordingFullTextClear fullTextClear, {
    StorageUsageService? service,
  }) async {
    // A tall viewport: the page is a lazy ListView, and the clear
    // button sits below the fold of the default 800x600 surface.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = StorageUsageViewModel(
      service: service ?? buildService(),
      onClearFullTextIndex: fullTextClear.call,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: FlutterSmartDialog.init(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
          home: StorageManagementPage(viewModel: viewModel),
        ),
      ),
    );
    await waitForMeasured(tester, viewModel);
    return viewModel;
  }

  /// Same page under a real [GoRouter], so row taps can be followed to
  /// the settings pages they open.
  Future<StorageUsageViewModel> pumpRouterPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fullTextClear = _RecordingFullTextClear(cache);
    final viewModel = StorageUsageViewModel(
      service: buildService(),
      onClearFullTextIndex: fullTextClear.call,
    );
    final router = GoRouter(
      initialLocation: "/settings/storage_management",
      routes: [
        GoRoute(
          path: "/settings/storage_management",
          builder: (context, state) =>
              StorageManagementPage(viewModel: viewModel),
        ),
        GoRoute(
          path: "/settings/dictionaries",
          builder: (context, state) => const Scaffold(
            body: Center(child: Text("Dictionaries settings")),
          ),
        ),
        GoRoute(
          path: "/settings/audio",
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text("Audio settings"))),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: FlutterSmartDialog.init(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
        ),
      ),
    );
    await waitForMeasured(tester, viewModel);
    return viewModel;
  }

  Finder tileFor(String title) {
    return find.ancestor(of: find.text(title), matching: find.byType(ListTile));
  }

  /// The bottom clear button: its label carries the selected total
  /// ("Clear cache 3.8 KB"), so match by substring, not exact text.
  Finder clearButton() => find.ancestor(
    of: find.textContaining("Clear cache"),
    matching: find.byType(FilledButton),
  );

  testWidgets("shows the donut total and every category with its share", (
    tester,
  ) async {
    final fullTextClear = _RecordingFullTextClear(cache);
    final viewModel = await pumpPage(tester, fullTextClear);

    // Donut center: the total split into value and unit.
    expect(find.text("Storage usage"), findsOneWidget);
    expect(find.text("8.6"), findsOneWidget);
    expect(find.text("KB"), findsOneWidget);

    expect(find.text("Dictionaries"), findsOneWidget);
    expect(find.text("500 B"), findsOneWidget);
    expect(find.text("Full-text search index"), findsOneWidget);
    expect(find.text("2.0 KB"), findsOneWidget);
    expect(find.text("Dictionary index cache"), findsOneWidget);
    expect(find.text("1.0 KB"), findsOneWidget);
    expect(find.text("Pronunciation cache"), findsOneWidget);
    expect(find.text("512 B"), findsOneWidget);
    expect(find.text("Other cache"), findsOneWidget);
    expect(find.text("256 B"), findsOneWidget);
    expect(find.text("App database"), findsOneWidget);
    expect(find.text("100 B"), findsOneWidget);
    expect(find.text("Audio packs"), findsOneWidget);
    expect(find.text("4.0 KB"), findsOneWidget);
    expect(find.text("Chat images"), findsOneWidget);
    expect(find.text("300 B"), findsOneWidget);

    // Shares of the 8.6 KB total, rounded.
    expect(find.text("23%"), findsOneWidget);
    expect(find.text("12%"), findsOneWidget);
    expect(find.text("46%"), findsOneWidget);
    expect(find.text("6%"), findsNWidgets(2));
    expect(find.text("3%"), findsNWidgets(2));
    expect(find.text("1%"), findsOneWidget);

    expect(find.text("Rebuilds automatically"), findsNWidgets(2));
    expect(find.text("Downloads again when needed"), findsOneWidget);

    // All four clearable rows start selected: four checks, and the
    // button sums exactly the clearable categories.
    expect(find.byIcon(Icons.check), findsNWidgets(4));
    final clear = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, "Clear cache 3.8 KB"),
    );
    expect(clear.onPressed, isNotNull);

    // The file-manager sub-page is Android-only.
    expect(find.text("File manager"), findsNothing);
    expect(viewModel.totalBytes, 8836);
    expect(viewModel.selectedClearableBytes, 3840);
  });

  testWidgets("shows personal dictionary estimates under the database row", (
    tester,
  ) async {
    final fullTextClear = _RecordingFullTextClear(cache);
    final service = StorageUsageService(
      cacheDirectory: () async => cache,
      supportDirectory: () async => support,
      documentsDirectory: () async => documents,
      databaseDir: () async => database,
      dictionariesDirectoryPath: () async => dictionaries.path,
      personalDictionaryEstimates: () async => const [
        PersonalDictionaryStorageEstimate(
          dictionaryId: 7,
          title: "My words",
          entryCount: 3,
          estimatedBytes: 1234,
        ),
        PersonalDictionaryStorageEstimate(
          dictionaryId: 8,
          title: "Empty notes",
          entryCount: 0,
          estimatedBytes: 0,
        ),
      ],
    );
    final viewModel = await pumpPage(tester, fullTextClear, service: service);

    // The breakdown lives under the database row, not as its own
    // category: the totals still count the shared file once.
    expect(find.text("Personal dictionaries"), findsOneWidget);
    expect(find.text("My words"), findsOneWidget);
    expect(find.text("1.2 KB · 3 entries"), findsOneWidget);
    expect(find.text("Empty notes"), findsOneWidget);
    expect(find.text("0 B · 0 entries"), findsOneWidget);
    expect(
      find.text(
        "Estimated from entry text — personal dictionaries share the app "
        "database file.",
      ),
      findsOneWidget,
    );
    expect(viewModel.totalBytes, 8836);
    expect(viewModel.personalDictionaryEstimatedBytes, 1234);
  });

  testWidgets("toggling a clearable row updates the button total", (
    tester,
  ) async {
    final fullTextClear = _RecordingFullTextClear(cache);
    final viewModel = await pumpPage(tester, fullTextClear);

    await tester.tap(find.text("Full-text search index"));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsNWidgets(3));
    expect(find.text("Clear cache 1.8 KB"), findsOneWidget);
    expect(viewModel.selectedClearableBytes, 1792);

    // Tapping again re-selects the row.
    await tester.tap(find.text("Full-text search index"));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsNWidgets(4));
    expect(find.text("Clear cache 3.8 KB"), findsOneWidget);
  });

  testWidgets("clearing with a subset selected only clears those", (
    tester,
  ) async {
    final fullTextClear = _RecordingFullTextClear(cache);
    final viewModel = await pumpPage(tester, fullTextClear);

    // Deselect the two index rows; only the pronunciation cache and
    // the other cache stay selected.
    await tester.tap(find.text("Full-text search index"));
    await tester.tap(find.text("Dictionary index cache"));
    await tester.pumpAndSettle();
    expect(find.text("Clear cache 768 B"), findsOneWidget);

    await tester.tap(clearButton());
    await tester.pumpAndSettle();
    expect(find.text("Clear cache?"), findsOneWidget);
    expect(find.textContaining("Delete 768 B"), findsOneWidget);

    await tester.tap(find.text("Delete"));
    await waitForMeasured(tester, viewModel);

    expect(fullTextClear.calls, 0);
    expect(
      find.descendant(
        of: tileFor("Pronunciation cache"),
        matching: find.text("0 B"),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tileFor("Other cache"), matching: find.text("0 B")),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tileFor("Full-text search index"),
        matching: find.text("2.0 KB"),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tileFor("Dictionary index cache"),
        matching: find.text("1.0 KB"),
      ),
      findsOneWidget,
    );
    final clear = tester.widget<FilledButton>(clearButton());
    expect(clear.onPressed, isNull);
    expect(find.text("Cache cleared"), findsOneWidget);
    // Let the toast's auto-dismiss timer fire; a pending timer fails the
    // test at teardown.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets("clearing with everything selected empties every clearable "
      "row and disables the button", (tester) async {
    final fullTextClear = _RecordingFullTextClear(cache);
    final viewModel = await pumpPage(tester, fullTextClear);

    await tester.tap(find.text("Clear cache 3.8 KB"));
    await tester.pumpAndSettle();
    expect(find.text("Clear cache?"), findsOneWidget);
    expect(find.textContaining("Delete 3.8 KB"), findsOneWidget);

    await tester.tap(find.text("Delete"));
    await waitForMeasured(tester, viewModel);

    expect(fullTextClear.calls, 1);
    for (final title in [
      "Full-text search index",
      "Dictionary index cache",
      "Pronunciation cache",
      "Other cache",
    ]) {
      expect(
        find.descendant(of: tileFor(title), matching: find.text("0 B")),
        findsOneWidget,
      );
    }
    expect(find.text("500 B"), findsOneWidget);
    expect(find.text("4.0 KB"), findsOneWidget);
    final clear = tester.widget<FilledButton>(clearButton());
    expect(clear.onPressed, isNull);
    expect(find.text("Cache cleared"), findsOneWidget);
    // Let the toast's auto-dismiss timer fire; a pending timer fails the
    // test at teardown.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets("shows an error with a retry button when measuring fails", (
    tester,
  ) async {
    var fail = true;
    final failingService = StorageUsageService(
      cacheDirectory: () async {
        if (fail) throw StateError("boom");
        return cache;
      },
      supportDirectory: () async => support,
      documentsDirectory: () async => documents,
      databaseDir: () async => database,
      dictionariesDirectoryPath: () async => dictionaries.path,
    );
    final fullTextClear = _RecordingFullTextClear(cache);
    final viewModel = await pumpPage(
      tester,
      fullTextClear,
      service: failingService,
    );

    expect(find.textContaining("boom"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, "Retry"), findsOneWidget);
    expect(find.text("Dictionaries"), findsNothing);

    fail = false;
    await tester.tap(find.widgetWithText(FilledButton, "Retry"));
    await waitForMeasured(tester, viewModel);
    expect(find.text("Dictionaries"), findsOneWidget);
    expect(find.textContaining("boom"), findsNothing);
  });

  testWidgets("tapping the dictionaries row opens dictionary settings", (
    tester,
  ) async {
    await pumpRouterPage(tester);

    await tester.tap(find.text("Dictionaries"));
    await tester.pumpAndSettle();

    expect(find.text("Dictionaries settings"), findsOneWidget);
  });

  testWidgets("tapping the audio packs row opens audio settings", (
    tester,
  ) async {
    await pumpRouterPage(tester);

    await tester.tap(find.text("Audio packs"));
    await tester.pumpAndSettle();

    expect(find.text("Audio settings"), findsOneWidget);
  });
}
