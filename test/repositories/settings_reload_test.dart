import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // No allow list: Settings reads the whole preference set.
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
  });

  setUp(() async {
    // Start every case from an empty store. `prefs` keeps its own cache, so it
    // has to be refreshed after the store is cleared.
    await SharedPreferencesAsync().clear();
    await prefs.reloadCache();
  });

  // One more instance of the same store: this is what the settings page, in
  // the main engine, writes through.
  SharedPreferencesAsync otherIsolate() => SharedPreferencesAsync();

  test("picks up a value written by another isolate", () async {
    final settings = Settings();
    expect(settings.contentScale, 1.0);

    await otherIsolate().setDouble("contentScale", 1.5);
    await settings.reloadFromPrefs();

    expect(settings.contentScale, 1.5);
  });

  test("clamps a reloaded value the way the initial read does", () async {
    final settings = Settings();

    await otherIsolate().setDouble("contentScale", 9.0);
    await settings.reloadFromPrefs();

    expect(settings.contentScale, maxContentScale);
  });

  test("reloads fields other than the entry zoom", () async {
    final settings = Settings();
    expect(settings.eInkMode, isFalse);

    await otherIsolate().setBool("eInkMode", true);
    await settings.reloadFromPrefs();

    expect(settings.eInkMode, isTrue);
  });

  test("notifies the listeners once", () async {
    final settings = Settings();
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.reloadFromPrefs();

    expect(notified, 1);
  });

  test("does not undo a value this isolate just wrote", () async {
    final settings = Settings();
    await settings.setContentScale(1.2);

    await settings.reloadFromPrefs();

    expect(settings.contentScale, 1.2);
  });
}
