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

  testWidgets("shows configuration fields for each provider", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CloudSyncSettingsPage(sessionService: session),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<CloudSyncProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("S3-compatible storage").last);
    await tester.pumpAndSettle();

    expect(find.text("S3 endpoint URL"), findsOneWidget);
    expect(find.text("Bucket"), findsOneWidget);
    expect(find.text("Access key ID"), findsOneWidget);
    expect(find.text("Secret access key"), findsOneWidget);
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
  Future<CloudSyncPreview> preview({
    required CloudSyncConnectionSettings settings,
  }) async {
    previewCalls++;
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
    required CloudSyncConnectionSettings settings,
    required String previewedSpaceId,
    Set<String> selectedDictionaryPackageIds = const {},
    DictionarySyncPreview? dictionaryPreview,
  }) async {
    connectCalls++;
    this.selectedDictionaryPackageIds = selectedDictionaryPackageIds;
    configuration = CloudSyncConfiguration(
      provider: settings.provider,
      endpoint: settings.endpoint,
      remoteRoot: settings.remoteRoot,
      username: settings.username,
      password: settings.password,
      sftpHostKeyFingerprint: settings.sftpHostKeyFingerprint,
      sftpPrivateKey: settings.sftpPrivateKey,
      sftpKeyPassphrase: settings.sftpKeyPassphrase,
      s3Bucket: settings.s3Bucket,
      s3Region: settings.s3Region,
      s3AccessKeyId: settings.s3AccessKeyId,
      s3SecretAccessKey: settings.s3SecretAccessKey,
      s3UsePathStyle: settings.s3UsePathStyle,
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
  Future<void> disconnect() async {
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
