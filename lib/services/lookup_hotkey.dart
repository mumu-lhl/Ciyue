import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/lookup_exclusion.dart";
import "package:ciyue/services/lookup_popup.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:ciyue/services/selection_watcher.dart";
import "package:ciyue/utils.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:hotkey_manager/hotkey_manager.dart";

/// Why a chord cannot be registered as the lookup shortcut.
enum LookupHotkeyChordError {
  /// No modifier key at all: a bare key would fire on ordinary typing.
  noModifier,

  /// Bare Ctrl+C / Cmd+C: grabbing it starves the focused app's copy.
  copyChord,

  /// The main window's global hotkey chord (Ctrl+Shift+M).
  mainHotkeyConflict,

  /// The trigger key has no usable keyboard mapping.
  unusableKey,

  /// Fn or Caps Lock: the platform layer drops them when registering, so
  /// the chord that takes effect would silently be a shorter one.
  droppedModifier,

  /// Shift is the only modifier and the trigger is a letter or digit:
  /// Shift is a typing modifier, so the chord would fire on ordinary
  /// typing.
  shiftOnlyLetter,
}

/// Pure validation for a candidate lookup chord, so the capture dialog and
/// the stored-chord parser share one rule set.
class LookupHotkeyChordValidation {
  LookupHotkeyChordValidation._();

  static final _modifierPhysicalKeys = <PhysicalKeyboardKey>{
    for (final modifier in HotKeyModifier.values) ...modifier.physicalKeys,
  };

  /// Returns the reason [chord] cannot be used, or null when it is fine.
  static LookupHotkeyChordError? validate(HotKey chord) {
    // The remaining checks read the trigger key, so usability comes first.
    final PhysicalKeyboardKey physicalKey;
    try {
      physicalKey = chord.physicalKey;
      chord.logicalKey;
    } catch (_) {
      return LookupHotkeyChordError.unusableKey;
    }
    // A modifier key cannot be the trigger key of its own chord.
    if (_modifierPhysicalKeys.contains(physicalKey)) {
      return LookupHotkeyChordError.unusableKey;
    }

    final modifiers = chord.modifiers ?? const <HotKeyModifier>[];
    if (modifiers.isEmpty) return LookupHotkeyChordError.noModifier;

    // hotkey_manager's accelerator drops Fn on Linux and both Fn and
    // Caps Lock on Windows, so a chord saved with them would register as a
    // shorter chord (Fn+C as bare C, Fn+Ctrl+C as Ctrl+C). macOS keeps
    // both, so Caps Lock is only rejected elsewhere.
    if (modifiers.contains(HotKeyModifier.fn) ||
        (!Platform.isMacOS && modifiers.contains(HotKeyModifier.capsLock))) {
      return LookupHotkeyChordError.droppedModifier;
    }

    // Shift is a typing modifier: Shift+A would fire on every capital A.
    // Only a lone Shift over a letter or digit trigger is rejected;
    // Shift with another modifier, or over a non-typing key such as F1,
    // is fine.
    if (modifiers.length == 1 &&
        modifiers.single == HotKeyModifier.shift &&
        _isLetterOrDigitKey(physicalKey)) {
      return LookupHotkeyChordError.shiftOnlyLetter;
    }

    // Bare Ctrl+C / Cmd+C: the copy chord on every desktop platform.
    if (physicalKey.usbHidUsage == PhysicalKeyboardKey.keyC.usbHidUsage &&
        modifiers.length == 1 &&
        (modifiers.single == HotKeyModifier.control ||
            modifiers.single == HotKeyModifier.meta)) {
      return LookupHotkeyChordError.copyChord;
    }

    // The main window's global hotkey (Ctrl+Shift+M) is registered through
    // the same manager; taking it would silence the other shortcut.
    if (physicalKey.usbHidUsage == PhysicalKeyboardKey.keyM.usbHidUsage &&
        modifiers.length == 2 &&
        modifiers.contains(HotKeyModifier.control) &&
        modifiers.contains(HotKeyModifier.shift)) {
      return LookupHotkeyChordError.mainHotkeyConflict;
    }

    return null;
  }

  /// Whether [key] types a letter or a digit: HID usage IDs for letters
  /// are 0x04-0x1d, digits 0x1e-0x27, numpad digits 0x59-0x61.
  static bool _isLetterOrDigitKey(PhysicalKeyboardKey key) {
    final usage = key.usbHidUsage & 0xffff;
    return (usage >= 0x04 && usage <= 0x1d) ||
        (usage >= 0x1e && usage <= 0x27) ||
        (usage >= 0x59 && usage <= 0x61);
  }
}

/// The app-wide lookup hotkey: looks up the text selected in another app in
/// the standalone lookup popup (issue #909).
///
/// Registration is opt-in ([settings.enableLookupHotkey], off by default), so
/// merely launching Ciyue never grabs a system-wide key. Wayland sessions are
/// not supported at all: the compositor does not let a client register a
/// global shortcut, so the toggle cannot work there. The setting is disabled
/// in the UI and the desktop environment is expected to bind the key instead.
///
/// The chord itself is user-configurable: [settings.lookupHotkeyChord] holds
/// the stored chord as JSON (empty means the default below), and
/// [applyChord] swaps the live registration over to it.
class LookupHotkeyService {
  LookupHotkeyService._();

  /// The identifier every lookup chord is registered under. One stable id
  /// per registration is what lets per-key unregister find the binding, and
  /// re-registering under the same id replaces the old chord instead of
  /// stacking a second one.
  static const String chordIdentifier = "lookup-hotkey";

  /// The chord: Ctrl+Alt+C on Linux/Windows, Cmd+Option+C on macOS.
  ///
  /// Bare Ctrl+C is deliberately avoided: a probe (2026-11-22) showed
  /// grabbing it starves the focused app's copy and the synthetic-copy
  /// fallback re-fires the handler, while double-Ctrl would need the
  /// KeyboardMonitor, which receives no events in this environment.
  static HotKey get defaultHotKey => HotKey(
    identifier: chordIdentifier,
    key: PhysicalKeyboardKey.keyC,
    modifiers: Platform.isMacOS
        ? [HotKeyModifier.meta, HotKeyModifier.alt]
        : [HotKeyModifier.control, HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  /// The chord currently in effect: the stored custom chord, or the default
  /// while none is stored. A single static instance per registration, so
  /// per-key unregister can find it (see [chordIdentifier]).
  static HotKey get hotKey => _currentHotKey;
  static HotKey _currentHotKey = defaultHotKey;

  /// Whether this session can register a working hotkey at all.
  static bool get isSupported => isDesktop() && !isWaylandSession();

  /// Whether this process currently holds the registration.
  static bool _applied = false;

  /// Whether [apply] currently holds the registration.
  @visibleForTesting
  static bool get isApplied => _applied;

  /// Resolves the focused app for the exclusion check in [handleHotKey].
  /// Null (the default) means no check, the Phase 1 behaviour. The startup
  /// code installs the real resolver; tests stub this.
  static FocusedAppResolver? focusedAppResolver;

  /// Acquires the selected text when the hotkey fires. Defaults to the real
  /// selection ladder; tests stub this to drive [handleHotKey] directly.
  static Future<String?> Function() acquireSelectionText =
      SelectionTextProviders.acquire;

  /// Shows the lookup popup for the acquired text. Defaults to the real
  /// popup service; tests stub this to observe [handleHotKey] without
  /// opening a native window.
  static Future<void> Function(String? text) showLookup =
      LookupPopupService.instance.showLookup;

  /// Parses a chord stored in `settings.lookupHotkeyChord`.
  ///
  /// Empty, malformed, or unusable input falls back to [defaultHotKey];
  /// never throws. The stored JSON is the `HotKey.toJson` form, and the
  /// identifier and scope are forced to this service's values on the way in.
  static HotKey parseChord(String? stored) {
    if (stored == null || stored.trim().isEmpty) return defaultHotKey;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return defaultHotKey;
      final parsed = HotKey.fromJson(decoded);
      final chord = HotKey(
        identifier: chordIdentifier,
        key: parsed.key,
        modifiers: parsed.modifiers,
        scope: HotKeyScope.system,
      );
      if (LookupHotkeyChordValidation.validate(chord) != null) {
        return defaultHotKey;
      }
      return chord;
    } catch (_) {
      return defaultHotKey;
    }
  }

  /// The chord from the user's setting: the stored custom chord, or the
  /// default while none is stored. Reads the settings singleton, so callers
  /// must run after preferences are initialised (startup, settings UI).
  static HotKey chordFromSettings() => parseChord(settings.lookupHotkeyChord);

  /// Short display form of a chord, e.g. "Ctrl + Alt + C".
  static String formatChord(HotKey chord) {
    final modifiers = formatModifiers(chord.modifiers ?? const []);
    return modifiers.isEmpty
        ? _keyLabel(chord)
        : "$modifiers + ${_keyLabel(chord)}";
  }

  /// Short display form of a modifier list, e.g. "Ctrl + Alt".
  static String formatModifiers(List<HotKeyModifier> modifiers) {
    final sorted = [...modifiers]
      ..sort((a, b) => _modifierRank(a).compareTo(_modifierRank(b)));
    return sorted.map(_modifierLabel).join(" + ");
  }

  static int _modifierRank(HotKeyModifier modifier) => switch (modifier) {
    HotKeyModifier.control => 0,
    HotKeyModifier.meta => 1,
    HotKeyModifier.alt => 2,
    HotKeyModifier.shift => 3,
    HotKeyModifier.fn => 4,
    HotKeyModifier.capsLock => 5,
  };

  static String _modifierLabel(HotKeyModifier modifier) => switch (modifier) {
    HotKeyModifier.control => "Ctrl",
    HotKeyModifier.meta => Platform.isMacOS ? "Cmd" : "Super",
    HotKeyModifier.alt => Platform.isMacOS ? "Option" : "Alt",
    HotKeyModifier.shift => "Shift",
    HotKeyModifier.fn => "Fn",
    HotKeyModifier.capsLock => "Caps Lock",
  };

  // The trigger key's label via its logical key: `keyLabel` is release-safe,
  // while `debugName` is null in release builds. Unusable keys have no
  // logical mapping and are rejected by validation before they reach here.
  static String _keyLabel(HotKey chord) {
    try {
      final label = chord.logicalKey.keyLabel;
      if (label.isNotEmpty) return label;
    } catch (_) {}
    return "?";
  }

  /// Brings the registration in line with [enabled], using the chord from
  /// the user's setting (the default while none is stored). The startup code
  /// and the Settings switch both call this after preferences are
  /// initialised, so a custom chord survives a restart. When the stored
  /// chord cannot be read yet (preferences not initialised), the chord
  /// already in effect is kept instead of throwing.
  static Future<bool> apply(bool enabled) async {
    HotKey chord;
    try {
      chord = chordFromSettings();
    } catch (_) {
      chord = _currentHotKey;
    }
    final applied = await applyChord(chord, enabled);
    if (applied) {
      // Persist the normalized chord: a stored value that predates
      // validation (or carries a modifier the platform drops) heals itself
      // instead of falling back to the default on every launch. Reading or
      // writing the preference can fail before preferences are ready; the
      // live registration is already correct, so that never fails the call.
      try {
        final normalized = jsonEncode(chord.toJson());
        if (settings.lookupHotkeyChord != normalized) {
          await settings.setLookupHotkeyChord(normalized);
        }
      } catch (_) {}
    }
    return applied;
  }

  /// Swaps the registered chord and brings the registration in line with
  /// [enabled].
  ///
  /// Returns `true` when the requested state is now in effect. The call is a
  /// no-op when the state already matches, and it never throws: failures are
  /// logged and reported so the UI can roll the change back. On failure the
  /// previous registration is restored when one was live, so a chord the
  /// system refuses never leaves the lookup without a working shortcut.
  static Future<bool> applyChord(HotKey chord, bool enabled) async {
    if (LookupHotkeyChordValidation.validate(chord) != null) {
      talker.warning("Lookup hotkey chord is not usable; ignoring request.");
      return false;
    }

    // Force the service identifier and scope: HotKey mints a random
    // identifier when none is given, and registering under the same
    // identifier is what lets a re-register supersede the previous chord
    // without an explicit unregister first. Without this, a chord saved
    // from the capture dialog (which carries no identifier) would stack a
    // second live registration next to the old one.
    final normalizedChord = HotKey(
      identifier: chordIdentifier,
      key: chord.key,
      modifiers: chord.modifiers,
      scope: HotKeyScope.system,
    );

    if (!isSupported) {
      // Wayland: never touch hotkey_manager, not even to unregister. The
      // switch is off in the UI, so a request to enable it is a programming
      // error rather than something to act on.
      if (enabled) {
        talker.warning(
          "Lookup hotkey is not supported on this session; ignoring request.",
        );
      }
      return !enabled;
    }

    if (enabled == _applied && _isSameChord(normalizedChord, _currentHotKey)) {
      return true;
    }

    final previous = _currentHotKey;
    try {
      // Registering under the same identifier replaces the previous chord:
      // no explicit unregister first, so there is never a window with no
      // registration live. Unregister only when switching off.
      if (enabled) {
        await hotKeyManager.register(
          normalizedChord,
          keyDownHandler: handleHotKey,
        );
      } else if (_applied) {
        // Unregister only this chord: GlobalHotkeyService registers its own
        // key through the same manager, and unregisterAll would drop it.
        await hotKeyManager.unregister(previous);
      }

      _currentHotKey = normalizedChord;
      _applied = enabled;
      talker.info("Lookup hotkey ${enabled ? "registered" : "unregistered"}.");
      return true;
    } catch (error, stackTrace) {
      talker.error(
        "Failed to update the lookup hotkey "
        "(${sessionEnvironmentDescription()})",
        error,
        stackTrace,
      );
      if (_applied) {
        // The new chord did not take: put the old registration back.
        try {
          await hotKeyManager.register(previous, keyDownHandler: handleHotKey);
        } catch (_) {
          _applied = false;
        }
      } else {
        _applied = false;
      }
      return false;
    }
  }

  /// Same key, modifiers, and scope, ignoring the identifier: two parses of
  /// one stored chord compare equal even though each parse mints its own id.
  static bool _isSameChord(HotKey a, HotKey b) {
    Map<String, dynamic> withoutIdentifier(HotKey chord) =>
        chord.toJson()..remove("identifier");
    return jsonEncode(withoutIdentifier(a)) == jsonEncode(withoutIdentifier(b));
  }

  /// Looks up the text selected in the focused app. Never throws: with no
  /// usable selection nothing opens. Selections inside Ciyue itself and
  /// apps on the exclusion list are skipped silently, before any text is
  /// acquired — the same check the bubble applies. When the focused app
  /// cannot be resolved at all, nothing is read either: an unknown app is
  /// not a reason to grab the clipboard. The resolver reports null when
  /// it cannot identify the app, so null fails closed like the bubble.
  static Future<void> handleHotKey(HotKey hotKey) async {
    try {
      final resolver = focusedAppResolver;
      if (resolver != null) {
        final String? appId;
        try {
          appId = await resolver.getFocusedAppId();
        } catch (_) {
          return;
        }
        if (appId == null) return;
        if (LookupExclusionService.isOwnApp(appId) ||
            LookupExclusionService.isExcluded(
              appId,
              settings.lookupExcludedApps,
            )) {
          return;
        }
      }
      final text = (await acquireSelectionText())?.trim();
      if (text == null || text.isEmpty) return;
      await showLookup(text);
    } catch (error, stackTrace) {
      talker.error("Failed to handle the lookup hotkey", error, stackTrace);
    }
  }
}
