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

  test("e-ink mode is off by default", () {
    expect(Settings().eInkMode, isFalse);
  });

  test("e-ink mode is written to the preferences and read back", () async {
    final settings = Settings();
    await settings.setEInkMode(true);

    expect(settings.eInkMode, isTrue);
    expect(prefs.getBool("eInkMode"), isTrue);
    expect(Settings().eInkMode, isTrue);

    await settings.setEInkMode(false);
    expect(prefs.getBool("eInkMode"), isFalse);
  });

  test("setting the mode notifies the listeners", () async {
    final settings = Settings();
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setEInkMode(true);
    expect(notified, 1);
  });
}
