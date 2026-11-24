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

  test("new lookup prefs default to off, selection, control, empty", () {
    final settings = Settings();
    expect(settings.enableLookupBubble, isFalse);
    expect(settings.lookupBubbleTrigger, "selection");
    expect(settings.lookupBubbleModifier, "control");
    expect(settings.lookupExcludedApps, isEmpty);
    expect(settings.lookupHotkeyChord, isEmpty);
  });

  test("setters round-trip through the store", () async {
    final settings = Settings();
    await settings.setEnableLookupBubble(true);
    await settings.setLookupBubbleTrigger("modifier");
    await settings.setLookupBubbleModifier("alt");
    await settings.setLookupExcludedApps(["firefox", "Code"]);
    await settings.setLookupHotkeyChord('{"key": "x"}');

    final reloaded = Settings();
    expect(reloaded.enableLookupBubble, isTrue);
    expect(reloaded.lookupBubbleTrigger, "modifier");
    expect(reloaded.lookupBubbleModifier, "alt");
    expect(reloaded.lookupExcludedApps, ["firefox", "Code"]);
    expect(reloaded.lookupHotkeyChord, '{"key": "x"}');
  });

  test("doubleClick trigger round-trips through the store", () async {
    final settings = Settings();
    await settings.setLookupBubbleTrigger("doubleClick");

    final reloaded = Settings();
    expect(reloaded.lookupBubbleTrigger, "doubleClick");
    expect(prefs.getString("lookupBubbleTrigger"), "doubleClick");
  });

  test(
    "unknown stored trigger and modifier values fall back to defaults",
    () async {
      final settings = Settings();

      await otherIsolate().setString("lookupBubbleTrigger", "whenever");
      await otherIsolate().setString("lookupBubbleModifier", "meta");
      await settings.reloadFromPrefs();

      expect(settings.lookupBubbleTrigger, "selection");
      expect(settings.lookupBubbleModifier, "control");
    },
  );

  test("setters normalise unknown values instead of storing them", () async {
    final settings = Settings();
    await settings.setLookupBubbleTrigger("whenever");
    await settings.setLookupBubbleModifier("meta");

    expect(settings.lookupBubbleTrigger, "selection");
    expect(settings.lookupBubbleModifier, "control");
    expect(prefs.getString("lookupBubbleTrigger"), "selection");
    expect(prefs.getString("lookupBubbleModifier"), "control");
  });
}
