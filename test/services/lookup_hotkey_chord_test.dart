import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/lookup_hotkey.dart";
import "package:ciyue/services/selection_watcher.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hotkey_manager/hotkey_manager.dart";
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

  group("LookupHotkeyChordValidation.validate", () {
    HotKey chord(KeyboardKey key, [List<HotKeyModifier>? modifiers]) =>
        HotKey(key: key, modifiers: modifiers, scope: HotKeyScope.system);

    LookupHotkeyChordError? validate(HotKey hotKey) =>
        LookupHotkeyChordValidation.validate(hotKey);

    test("accepts the default chord", () {
      expect(validate(LookupHotkeyService.defaultHotKey), isNull);
    });

    test("accepts chords with two or more modifiers", () {
      expect(
        validate(
          chord(PhysicalKeyboardKey.keyX, [
            HotKeyModifier.control,
            HotKeyModifier.shift,
          ]),
        ),
        isNull,
      );
      expect(
        validate(
          chord(PhysicalKeyboardKey.keyL, [
            HotKeyModifier.meta,
            HotKeyModifier.alt,
          ]),
        ),
        isNull,
      );
    });

    test("rejects Fn and Caps Lock modifiers the platform drops", () {
      // hotkey_manager's accelerator drops Fn on Linux and both Fn and
      // Caps Lock on Windows: saving Fn+C would register bare C, and
      // Fn+Ctrl+C would register Ctrl+C and steal system copy.
      expect(
        validate(
          chord(PhysicalKeyboardKey.keyC, [
            HotKeyModifier.fn,
            HotKeyModifier.control,
          ]),
        ),
        LookupHotkeyChordError.droppedModifier,
      );
      expect(
        validate(chord(PhysicalKeyboardKey.keyX, [HotKeyModifier.fn])),
        LookupHotkeyChordError.droppedModifier,
      );
      if (!Platform.isMacOS) {
        expect(
          validate(chord(PhysicalKeyboardKey.keyX, [HotKeyModifier.capsLock])),
          LookupHotkeyChordError.droppedModifier,
        );
      }
    });

    test("rejects Shift as the only modifier over a letter or digit", () {
      expect(
        validate(chord(PhysicalKeyboardKey.keyA, [HotKeyModifier.shift])),
        LookupHotkeyChordError.shiftOnlyLetter,
      );
      expect(
        validate(chord(PhysicalKeyboardKey.digit1, [HotKeyModifier.shift])),
        LookupHotkeyChordError.shiftOnlyLetter,
      );
      expect(
        validate(chord(PhysicalKeyboardKey.numpad1, [HotKeyModifier.shift])),
        LookupHotkeyChordError.shiftOnlyLetter,
      );
    });

    test("accepts Shift with another modifier, or over a function key", () {
      expect(
        validate(
          chord(PhysicalKeyboardKey.keyA, [
            HotKeyModifier.control,
            HotKeyModifier.shift,
          ]),
        ),
        isNull,
      );
      expect(
        validate(chord(PhysicalKeyboardKey.f1, [HotKeyModifier.shift])),
        isNull,
      );
    });

    test("rejects a chord with no modifier", () {
      expect(
        validate(chord(PhysicalKeyboardKey.keyX)),
        LookupHotkeyChordError.noModifier,
      );
      expect(
        validate(chord(PhysicalKeyboardKey.keyX, [])),
        LookupHotkeyChordError.noModifier,
      );
    });

    test("rejects bare Ctrl+C and Cmd+C", () {
      expect(
        validate(chord(PhysicalKeyboardKey.keyC, [HotKeyModifier.control])),
        LookupHotkeyChordError.copyChord,
      );
      expect(
        validate(chord(PhysicalKeyboardKey.keyC, [HotKeyModifier.meta])),
        LookupHotkeyChordError.copyChord,
      );
    });

    test("accepts Ctrl+Alt+C and Ctrl+Shift+C", () {
      expect(
        validate(
          chord(PhysicalKeyboardKey.keyC, [
            HotKeyModifier.control,
            HotKeyModifier.alt,
          ]),
        ),
        isNull,
      );
      expect(
        validate(
          chord(PhysicalKeyboardKey.keyC, [
            HotKeyModifier.control,
            HotKeyModifier.shift,
          ]),
        ),
        isNull,
      );
    });

    test("rejects the main global hotkey chord", () {
      expect(
        validate(
          chord(PhysicalKeyboardKey.keyM, [
            HotKeyModifier.control,
            HotKeyModifier.shift,
          ]),
        ),
        LookupHotkeyChordError.mainHotkeyConflict,
      );
    });

    test("accepts other chords on M", () {
      expect(
        validate(
          chord(PhysicalKeyboardKey.keyM, [
            HotKeyModifier.control,
            HotKeyModifier.alt,
          ]),
        ),
        isNull,
      );
      expect(
        validate(
          chord(PhysicalKeyboardKey.keyM, [
            HotKeyModifier.meta,
            HotKeyModifier.shift,
          ]),
        ),
        isNull,
      );
    });

    test("rejects a key with no usable mapping", () {
      expect(
        validate(chord(const PhysicalKeyboardKey(0))),
        LookupHotkeyChordError.unusableKey,
      );
      expect(
        validate(chord(const LogicalKeyboardKey(0))),
        LookupHotkeyChordError.unusableKey,
      );
    });

    test("rejects a modifier key as the trigger key", () {
      expect(
        validate(
          chord(PhysicalKeyboardKey.shiftLeft, [HotKeyModifier.control]),
        ),
        LookupHotkeyChordError.unusableKey,
      );
    });
  });

  group("LookupHotkeyService.parseChord", () {
    test("empty and null mean the default chord", () {
      for (final stored in [null, "", "   "]) {
        final parsed = LookupHotkeyService.parseChord(stored);
        expect(parsed.key, PhysicalKeyboardKey.keyC);
        expect(parsed.scope, HotKeyScope.system);
      }
    });

    test("the default chord survives a round-trip", () {
      final parsed = LookupHotkeyService.parseChord(
        jsonEncode(LookupHotkeyService.defaultHotKey.toJson()),
      );
      expect(parsed.key, PhysicalKeyboardKey.keyC);
      expect(parsed.identifier, LookupHotkeyService.chordIdentifier);
    });

    test("round-trips a custom chord through JSON", () {
      final chord = HotKey(
        key: PhysicalKeyboardKey.keyL,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );
      final parsed = LookupHotkeyService.parseChord(jsonEncode(chord.toJson()));
      expect(parsed.key, PhysicalKeyboardKey.keyL);
      expect(parsed.modifiers, [HotKeyModifier.control, HotKeyModifier.alt]);
      expect(parsed.scope, HotKeyScope.system);
      expect(parsed.identifier, LookupHotkeyService.chordIdentifier);
    });

    test("malformed JSON falls back to the default chord", () {
      for (final stored in [
        "not json",
        "{bad",
        "[1, 2]",
        '{"key": "nope"}',
        '{"key": {"keyId": 123456789}}',
      ]) {
        final parsed = LookupHotkeyService.parseChord(stored);
        expect(parsed.key, PhysicalKeyboardKey.keyC);
        expect(parsed.identifier, LookupHotkeyService.chordIdentifier);
      }
    });

    test("an unusable stored chord falls back to the default chord", () {
      final conflict = HotKey(
        key: PhysicalKeyboardKey.keyM,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      final parsed = LookupHotkeyService.parseChord(
        jsonEncode(conflict.toJson()),
      );
      expect(parsed.key, PhysicalKeyboardKey.keyC);
      expect(parsed.modifiers, [HotKeyModifier.control, HotKeyModifier.alt]);
    });

    test("a stored chord with a dropped modifier falls back to default", () {
      final fnChord = HotKey(
        key: PhysicalKeyboardKey.keyC,
        modifiers: [HotKeyModifier.fn, HotKeyModifier.control],
        scope: HotKeyScope.system,
      );
      final parsed = LookupHotkeyService.parseChord(
        jsonEncode(fnChord.toJson()),
      );
      expect(parsed.key, PhysicalKeyboardKey.keyC);
      expect(parsed.modifiers, [HotKeyModifier.control, HotKeyModifier.alt]);
    });

    test("a stored Shift-only letter chord falls back to default", () {
      final shiftChord = HotKey(
        key: PhysicalKeyboardKey.keyA,
        modifiers: [HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      final parsed = LookupHotkeyService.parseChord(
        jsonEncode(shiftChord.toJson()),
      );
      expect(parsed.key, PhysicalKeyboardKey.keyC);
      expect(parsed.modifiers, [HotKeyModifier.control, HotKeyModifier.alt]);
    });

    test("forces the service identifier and system scope", () {
      final chord = HotKey(
        identifier: "something-else",
        key: PhysicalKeyboardKey.keyL,
        modifiers: [HotKeyModifier.control],
        scope: HotKeyScope.inapp,
      );
      final parsed = LookupHotkeyService.parseChord(jsonEncode(chord.toJson()));
      expect(parsed.identifier, LookupHotkeyService.chordIdentifier);
      expect(parsed.scope, HotKeyScope.system);
    });
  });

  group("LookupHotkeyService.formatChord", () {
    test("formats the default chord", () {
      if (Platform.isMacOS) {
        expect(
          LookupHotkeyService.formatChord(LookupHotkeyService.defaultHotKey),
          "Cmd + Option + C",
        );
      } else {
        expect(
          LookupHotkeyService.formatChord(LookupHotkeyService.defaultHotKey),
          "Ctrl + Alt + C",
        );
      }
    });

    test("orders modifiers canonically", () {
      final chord = HotKey(
        key: PhysicalKeyboardKey.keyX,
        modifiers: [HotKeyModifier.shift, HotKeyModifier.control],
        scope: HotKeyScope.system,
      );
      expect(LookupHotkeyService.formatChord(chord), "Ctrl + Shift + X");
    });

    test("formats a bare key and function and digit keys", () {
      expect(
        LookupHotkeyService.formatChord(
          HotKey(key: PhysicalKeyboardKey.keyX, scope: HotKeyScope.system),
        ),
        "X",
      );
      expect(
        LookupHotkeyService.formatChord(
          HotKey(
            key: PhysicalKeyboardKey.f1,
            modifiers: [HotKeyModifier.control],
            scope: HotKeyScope.system,
          ),
        ),
        "Ctrl + F1",
      );
      expect(
        LookupHotkeyService.formatChord(
          HotKey(
            key: PhysicalKeyboardKey.digit1,
            modifiers: [HotKeyModifier.control],
            scope: HotKeyScope.system,
          ),
        ),
        "Ctrl + 1",
      );
    });

    test("formats a modifier list on its own", () {
      expect(
        LookupHotkeyService.formatModifiers([
          HotKeyModifier.alt,
          HotKeyModifier.control,
        ]),
        "Ctrl + Alt",
      );
      expect(LookupHotkeyService.formatModifiers([]), isEmpty);
    });
  });

  group("LookupHotkeyService.applyChord", () {
    const hotkeyChannel = MethodChannel(
      "dev.leanflutter.plugins/hotkey_manager",
    );
    var failNextRegister = false;

    setUpAll(() {
      // The native backend talks over the method channel; answering it here
      // makes register/unregister succeed in a unit test.
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hotkeyChannel, (MethodCall call) async {
            if (call.method == "register" && failNextRegister) {
              failNextRegister = false;
              throw PlatformException(code: "register_failed");
            }
            return null;
          });
    });

    tearDownAll(() {
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hotkeyChannel, null);
    });

    setUp(() {
      failNextRegister = false;
    });

    tearDown(() async {
      // Leave the service on the default chord, unregistered.
      await LookupHotkeyService.applyChord(
        LookupHotkeyService.defaultHotKey,
        false,
      );
    });

    HotKey newChord(PhysicalKeyboardKey key) => HotKey(
      key: key,
      modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
      scope: HotKeyScope.system,
    );

    test("swaps the chord while disabled", () async {
      expect(
        await LookupHotkeyService.applyChord(
          newChord(PhysicalKeyboardKey.keyL),
          false,
        ),
        isTrue,
      );
      expect(LookupHotkeyService.hotKey.key, PhysicalKeyboardKey.keyL);
      expect(LookupHotkeyService.isApplied, isFalse);
    });

    test("registers the new chord when enabled", () async {
      final chord = newChord(PhysicalKeyboardKey.keyL);
      expect(await LookupHotkeyService.applyChord(chord, true), isTrue);
      expect(LookupHotkeyService.isApplied, isTrue);
      expect(LookupHotkeyService.hotKey.key, PhysicalKeyboardKey.keyL);
      expect(
        hotKeyManager.registeredHotKeyList.map((key) => key.key),
        contains(PhysicalKeyboardKey.keyL),
      );

      expect(await LookupHotkeyService.apply(false), isTrue);
      expect(LookupHotkeyService.isApplied, isFalse);
    });

    test("swaps the chord while enabled", () async {
      expect(
        await LookupHotkeyService.applyChord(
          newChord(PhysicalKeyboardKey.keyL),
          true,
        ),
        isTrue,
      );
      expect(
        await LookupHotkeyService.applyChord(
          newChord(PhysicalKeyboardKey.keyX),
          true,
        ),
        isTrue,
      );
      expect(LookupHotkeyService.hotKey.key, PhysicalKeyboardKey.keyX);
      expect(LookupHotkeyService.isApplied, isTrue);
      expect(
        hotKeyManager.registeredHotKeyList.map((key) => key.key),
        contains(PhysicalKeyboardKey.keyX),
      );
      expect(
        hotKeyManager.registeredHotKeyList.map((key) => key.key),
        isNot(contains(PhysicalKeyboardKey.keyL)),
      );
    });

    test("keeps the old registration when the new chord fails", () async {
      final first = newChord(PhysicalKeyboardKey.keyL);
      expect(await LookupHotkeyService.applyChord(first, true), isTrue);

      failNextRegister = true;
      expect(
        await LookupHotkeyService.applyChord(
          newChord(PhysicalKeyboardKey.keyX),
          true,
        ),
        isFalse,
      );
      expect(LookupHotkeyService.hotKey.key, PhysicalKeyboardKey.keyL);
      expect(LookupHotkeyService.isApplied, isTrue);
      expect(
        hotKeyManager.registeredHotKeyList.map((key) => key.key),
        contains(PhysicalKeyboardKey.keyL),
      );
    });

    test(
      "rejects an unusable chord without touching the registration",
      () async {
        final before = LookupHotkeyService.hotKey;
        final copy = HotKey(
          key: PhysicalKeyboardKey.keyC,
          modifiers: [HotKeyModifier.control],
          scope: HotKeyScope.system,
        );
        expect(await LookupHotkeyService.applyChord(copy, true), isFalse);
        expect(identical(LookupHotkeyService.hotKey, before), isTrue);
        expect(LookupHotkeyService.isApplied, isFalse);
      },
    );

    test("apply loads the stored chord", () async {
      final chord = newChord(PhysicalKeyboardKey.keyL);
      await settings.setLookupHotkeyChord(jsonEncode(chord.toJson()));
      expect(await LookupHotkeyService.apply(false), isTrue);
      expect(LookupHotkeyService.hotKey.key, PhysicalKeyboardKey.keyL);
      expect(LookupHotkeyService.isApplied, isFalse);
      await settings.setLookupHotkeyChord("");
    });

    test("apply registers the stored chord when enabled", () async {
      final chord = newChord(PhysicalKeyboardKey.keyL);
      await settings.setLookupHotkeyChord(jsonEncode(chord.toJson()));
      expect(await LookupHotkeyService.apply(true), isTrue);
      expect(LookupHotkeyService.isApplied, isTrue);
      expect(LookupHotkeyService.hotKey.key, PhysicalKeyboardKey.keyL);
      expect(
        hotKeyManager.registeredHotKeyList.map((key) => key.key),
        contains(PhysicalKeyboardKey.keyL),
      );
      await settings.setLookupHotkeyChord("");
    });

    test(
      "apply falls back to the default chord when nothing is stored",
      () async {
        await settings.setLookupHotkeyChord("");
        expect(await LookupHotkeyService.apply(false), isTrue);
        expect(LookupHotkeyService.hotKey.key, PhysicalKeyboardKey.keyC);
      },
    );

    test(
      "first-enable registration failure leaves nothing registered",
      () async {
        // Another program holds the chord on the very first enable: apply
        // reports the failure and the service stays unregistered, so the
        // settings switch can roll the change back instead of claiming the
        // hotkey is on. Key Z is used because no earlier test in this file
        // registers it: the manager caches native registrations by
        // accelerator, so re-registering an already-seen chord would never
        // reach the platform call the mock fails.
        final before = LookupHotkeyService.hotKey;
        failNextRegister = true;
        expect(
          await LookupHotkeyService.applyChord(
            newChord(PhysicalKeyboardKey.keyZ),
            true,
          ),
          isFalse,
        );
        expect(LookupHotkeyService.isApplied, isFalse);
        expect(identical(LookupHotkeyService.hotKey, before), isTrue);
        expect(hotKeyManager.registeredHotKeyList, isEmpty);
      },
    );

    test(
      "apply writes the normalized chord back over an invalid stored one",
      () async {
        // A stored chord that predates validation (or carries a modifier the
        // platform drops) falls back to the default on read; a successful
        // apply heals the stored value so the fallback does not repeat on
        // every launch.
        final invalidStored = [
          HotKey(
            key: PhysicalKeyboardKey.keyM,
            modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
            scope: HotKeyScope.system,
          ),
          HotKey(
            key: PhysicalKeyboardKey.keyC,
            modifiers: [HotKeyModifier.fn, HotKeyModifier.control],
            scope: HotKeyScope.system,
          ),
          HotKey(
            key: PhysicalKeyboardKey.keyA,
            modifiers: [HotKeyModifier.shift],
            scope: HotKeyScope.system,
          ),
        ];
        final defaultJson = jsonEncode(
          LookupHotkeyService.defaultHotKey.toJson(),
        );
        for (final stored in invalidStored) {
          await settings.setLookupHotkeyChord(jsonEncode(stored.toJson()));
          expect(await LookupHotkeyService.apply(false), isTrue);
          expect(LookupHotkeyService.hotKey.key, PhysicalKeyboardKey.keyC);
          expect(settings.lookupHotkeyChord, defaultJson);
        }
        await settings.setLookupHotkeyChord("");
      },
    );
  });

  group("LookupHotkeyService.handleHotKey with focusedAppResolver", () {
    late List<String?> shown;
    late Future<String?> Function() savedAcquire;
    late Future<void> Function(String?) savedShow;
    late FocusedAppResolver? savedResolver;
    var acquireCalls = 0;

    setUp(() {
      shown = <String?>[];
      acquireCalls = 0;
      savedAcquire = LookupHotkeyService.acquireSelectionText;
      savedShow = LookupHotkeyService.showLookup;
      savedResolver = LookupHotkeyService.focusedAppResolver;
      LookupHotkeyService.showLookup = (text) async {
        shown.add(text);
      };
      LookupHotkeyService.acquireSelectionText = () async {
        acquireCalls++;
        return "hello";
      };
    });

    tearDown(() {
      LookupHotkeyService.acquireSelectionText = savedAcquire;
      LookupHotkeyService.showLookup = savedShow;
      LookupHotkeyService.focusedAppResolver = savedResolver;
    });

    test("skips silently when the focused app is excluded", () async {
      await settings.setLookupExcludedApps(["firefox"]);
      LookupHotkeyService.focusedAppResolver = _FakeFocusedAppResolver(
        "firefox",
      );
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(shown, isEmpty);
    });

    test(
      "matches the exclusion case-insensitively and by containment",
      () async {
        await settings.setLookupExcludedApps(["FireFox"]);
        LookupHotkeyService.focusedAppResolver = _FakeFocusedAppResolver(
          "org.mozilla.firefox",
        );
        await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
        expect(shown, isEmpty);
      },
    );

    test("skips silently when the focused app is Ciyue itself", () async {
      await settings.setLookupExcludedApps([]);
      LookupHotkeyService.focusedAppResolver = _FakeFocusedAppResolver("ciyue");
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(shown, isEmpty);
      expect(acquireCalls, 0);
    });

    test("looks up when the focused app is not excluded", () async {
      await settings.setLookupExcludedApps(["firefox"]);
      LookupHotkeyService.focusedAppResolver = _FakeFocusedAppResolver("code");
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(shown, ["hello"]);
    });

    test("fails closed when the resolver cannot identify the app", () async {
      // The resolver reports null when it cannot identify the focused
      // app, so the lookup reads nothing: the app may be Ciyue itself
      // or an excluded one. Same rule as the bubble.
      await settings.setLookupExcludedApps(["firefox"]);
      LookupHotkeyService.focusedAppResolver = _FakeFocusedAppResolver(null);
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(acquireCalls, 0);
      expect(shown, isEmpty);
    });

    test("never throws when the resolver fails", () async {
      LookupHotkeyService.focusedAppResolver =
          _FakeFocusedAppResolver.throwing();
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(shown, isEmpty);
    });

    test("reads nothing when the resolver fails", () async {
      // The focused app cannot be identified, so no clipboard read happens
      // for an unknown app: the lookup fails closed instead of grabbing
      // text the user may have selected inside Ciyue itself.
      LookupHotkeyService.focusedAppResolver =
          _FakeFocusedAppResolver.throwing();
      await LookupHotkeyService.handleHotKey(LookupHotkeyService.hotKey);
      expect(acquireCalls, 0);
      expect(shown, isEmpty);
    });
  });
}

class _FakeFocusedAppResolver implements FocusedAppResolver {
  _FakeFocusedAppResolver(this._appId) : _throw = false;

  _FakeFocusedAppResolver.throwing() : _appId = null, _throw = true;

  final String? _appId;
  final bool _throw;

  @override
  Future<String?> getFocusedAppId() async {
    if (_throw) throw StateError("no focused app");
    return _appId;
  }
}
