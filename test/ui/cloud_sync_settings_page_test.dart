import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:ciyue/services/cloud_sync/coordinator.dart";
import "package:ciyue/services/cloud_sync/dictionary_sync.dart";
import "package:ciyue/services/cloud_sync/preview_service.dart";
import "package:ciyue/services/cloud_sync/session_service.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/cloud_sync.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SharedPreferencesWithCache preferences;
  late _FakeCloudSyncSessionService session;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: CloudSyncConfigurationStore.preferenceKeys,
      ),
    );
    session = _FakeCloudSyncSessionService(
      database: database,
      configurationStore: CloudSyncConfigurationStore(
        preferences: preferences,
        secretStorage: _MemoryCloudSecretStorage(),
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets("requires user confirmation after preview", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CloudSyncSettingsPage(sessionService: session),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, "https://dav.test/");
    await tester.tap(find.text("Preview changes"));
    await tester.pumpAndSettle();

    expect(session.previewCalls, 1);
    expect(session.connectCalls, 0);
    expect(find.text("Sync preview"), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text("Confirm and sync"), findsOneWidget);

    await tester.tap(find.text("Confirm and sync"));
    await tester.pumpAndSettle();

    expect(session.connectCalls, 1);
    expect(find.text("Sync complete."), findsOneWidget);
  });

  testWidgets("OAuth provider must be authorized before previewing", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CloudSyncSettingsPage(sessionService: session),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<CloudSyncProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Google Drive").last);
    await tester.pumpAndSettle();
    expect(find.text("Connect Google Drive"), findsOneWidget);

    await tester.tap(find.text("Connect Google Drive"));
    await tester.pumpAndSettle();
    expect(session.authorizationCalls, 1);
    expect(find.text("Preview changes"), findsOneWidget);

    await tester.tap(find.text("Preview changes"));
    await tester.pumpAndSettle();
    expect(session.previewCalls, 1);
    expect(session.lastPreviewProvider, CloudSyncProvider.googleDrive);
  });

  testWidgets("sends only checked dictionaries after confirmation", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CloudSyncSettingsPage(sessionService: session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, "https://dav.test/");
    await tester.tap(find.text("Preview changes"));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    final dictionaryTile = find.byKey(
      const ValueKey("dictionary-sync-local-package"),
    );
    await tester.ensureVisible(dictionaryTile);
    expect(tester.widget<CheckboxListTile>(dictionaryTile).value, isFalse);
    await tester.tap(dictionaryTile);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text("Confirm and sync"));
    await tester.tap(find.text("Confirm and sync"));
    await tester.pumpAndSettle();

    expect(session.selectedDictionaryPackageIds, {"local-package"});
  });
}

class _FakeCloudSyncSessionService extends CloudSyncSessionService {
  int previewCalls = 0;
  int connectCalls = 0;
  int authorizationCalls = 0;
  bool authorized = false;
  CloudSyncProvider? lastPreviewProvider;
  Set<String> selectedDictionaryPackageIds = const {};
  CloudSyncConfiguration configuration = const CloudSyncConfiguration(
    endpoint: "",
    remoteRoot: "Ciyue",
    username: "",
    password: null,
    deviceId: "device-test",
    spaceId: null,
  );

  _FakeCloudSyncSessionService({
    required super.database,
    required super.configurationStore,
  });

  @override
  Future<CloudSyncConfiguration> loadConfiguration() async => configuration;

  @override
  Future<void> authorize(CloudSyncProvider provider) async {
    authorizationCalls++;
    authorized = true;
  }

  @override
  Future<bool> isAuthorized(CloudSyncProvider provider) async => authorized;

  @override
  Future<CloudSyncPreview> preview({
    CloudSyncProvider provider = CloudSyncProvider.webDav,
    String? googleDriveParentFolderId,
    required String endpoint,
    required String remoteRoot,
    required String username,
    required String? password,
  }) async {
    previewCalls++;
    lastPreviewProvider = provider;
    return CloudSyncPreview(
      remoteFolderExists: false,
      spaceId: "space-preview",
      remoteDeviceCount: 0,
      local: const CloudSyncDataSummary(
        wordbookEntries: 1,
        wordbookTags: 0,
        flashcards: 0,
        reviewLogs: 0,
      ),
      remote: const CloudSyncDataSummary(
        wordbookEntries: 0,
        wordbookTags: 0,
        flashcards: 0,
        reviewLogs: 0,
      ),
      merged: const CloudSyncDataSummary(
        wordbookEntries: 1,
        wordbookTags: 0,
        flashcards: 0,
        reviewLogs: 0,
      ),
      conflicts: const [],
      dictionaryPreview: DictionarySyncPreview.forDisplay(const [
        DictionarySyncItem(
          packageId: "local-package",
          title: "My lexicon",
          fileName: "lexicon.mdx",
          fileCount: 2,
          totalSizeBytes: 2048,
          availableLocally: true,
          availableRemotely: false,
        ),
      ]),
    );
  }

  @override
  Future<CloudSyncOutcome> connectAndSync({
    CloudSyncProvider provider = CloudSyncProvider.webDav,
    String? googleDriveParentFolderId,
    String? googleDriveParentFolderName,
    required String endpoint,
    required String remoteRoot,
    required String username,
    required String? password,
    required String previewedSpaceId,
    Set<String> selectedDictionaryPackageIds = const {},
    DictionarySyncPreview? dictionaryPreview,
  }) async {
    connectCalls++;
    this.selectedDictionaryPackageIds = selectedDictionaryPackageIds;
    configuration = CloudSyncConfiguration(
      endpoint: endpoint,
      remoteRoot: remoteRoot,
      username: username,
      password: password,
      deviceId: configuration.deviceId,
      spaceId: previewedSpaceId,
    );
    return CloudSyncOutcome(
      snapshot: SyncSnapshot(
        spaceId: previewedSpaceId,
        deviceId: configuration.deviceId,
        records: const [],
      ),
      conflicts: const [],
      remoteDeviceCount: 0,
      uploaded: true,
    );
  }

  @override
  Future<void> disconnect({CloudSyncProvider? provider}) async {
    configuration = const CloudSyncConfiguration(
      endpoint: "",
      remoteRoot: "Ciyue",
      username: "",
      password: null,
      deviceId: "device-test",
      spaceId: null,
    );
  }
}

class _MemoryCloudSecretStorage implements CloudSecretStorage {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}
