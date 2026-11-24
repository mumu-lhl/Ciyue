import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/desktop_selection_atspi.dart";
import "package:ciyue/services/desktop_selection_native.dart";
import "package:ciyue/services/desktop_selection_x11.dart";
import "package:ciyue/services/focused_app_x11.dart";
import "package:ciyue/services/lookup_bubble.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:ciyue/services/selection_watcher_x11.dart";
import "package:ciyue/utils.dart";
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
    await SharedPreferencesAsync().clear();
    await prefs.reloadCache();
    await settings.setEnableLookupBubble(false);
    await settings.setLookupBubbleTrigger("selection");
    await settings.setLookupBubbleModifier("control");
    await settings.setLookupExcludedApps([]);
  });

  tearDown(() async {
    await LookupBubbleService.instance.stop();
    await settings.setEnableLookupBubble(false);
  });

  group("shouldInitDesktopMainWindow", () {
    test("the floating-window engine never runs the main-window block", () {
      expect(shouldInitDesktopMainWindow(isFloatingWindow: true), isFalse);
    });

    test("the main engine runs it exactly on desktop", () {
      expect(shouldInitDesktopMainWindow(isFloatingWindow: false), isDesktop());
    });
  });

  group("initSelectionProviders", () {
    test("installs each provider exactly when it reports available", () async {
      await initSelectionProviders();
      expect(
        SelectionTextProviders.x11PrimaryProvider == null,
        !X11PrimarySelectionProvider.isAvailable,
      );
      expect(
        SelectionTextProviders.atspiProvider == null,
        !AtSpiSelectionProvider.isAvailable,
      );
      expect(
        SelectionTextProviders.nativeDesktopProvider == null,
        !NativeSelection.isAvailable,
      );
      expect(
        SelectionTextProviders.nativeCopySender == null,
        !NativeSelection.isAvailable,
      );
    });

    test("is idempotent", () async {
      await initSelectionProviders();
      await initSelectionProviders();
      expect(
        SelectionTextProviders.x11PrimaryProvider == null,
        !X11PrimarySelectionProvider.isAvailable,
      );
    });
  });

  group("lookupSelectionWatcher", () {
    test(
      "returns only a watcher this platform can run, and only if usable",
      () {
        final watcher = lookupSelectionWatcher();
        expect(
          watcher == null ||
              watcher is AtSpiSelectionWatcher ||
              watcher is XFixesSelectionWatcher,
          isTrue,
        );
        if (watcher != null) expect(watcher.isAvailable, isTrue);
      },
    );
  });

  group("lookupFocusedAppResolver", () {
    test("returns only a resolver this platform can run", () {
      final resolver = lookupFocusedAppResolver();
      expect(resolver == null || resolver is X11FocusedAppResolver, isTrue);
    });
  });

  group("lookupModifierHeld", () {
    test("exists exactly on X11 Linux, and answers without throwing", () async {
      final held = lookupModifierHeld();
      expect(held == null, !Platform.isLinux || isWaylandSession());
      if (held != null) {
        expect(await held("control"), isA<bool>());
        expect(await held("bogus"), isA<bool>());
      }
    });
  });

  group("restartLookupBubble", () {
    test("disabled leaves the bubble stopped", () async {
      await restartLookupBubble();
      expect(LookupBubbleService.instance.isRunning, isFalse);
      expect(LookupBubbleService.instance.isVisible, isFalse);
    });

    test("enabled starts it exactly when a usable watcher exists", () async {
      await settings.setEnableLookupBubble(true);
      await restartLookupBubble();
      final watcher = lookupSelectionWatcher();
      expect(
        LookupBubbleService.instance.isRunning,
        watcher != null && watcher.isAvailable,
      );
      expect(LookupBubbleService.instance.isVisible, isFalse);
    });

    test("accepts an explicit focused-app resolver", () async {
      await settings.setEnableLookupBubble(true);
      await restartLookupBubble(
        focusedAppResolver: const X11FocusedAppResolver(),
      );
      expect(LookupBubbleService.instance.isVisible, isFalse);
    });

    test("is idempotent", () async {
      await settings.setEnableLookupBubble(true);
      await restartLookupBubble();
      await restartLookupBubble();
      expect(LookupBubbleService.instance.isVisible, isFalse);
    });
  });
}
