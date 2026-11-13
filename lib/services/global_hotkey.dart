import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/utils.dart";
import "package:flutter/services.dart";
import "package:hotkey_manager/hotkey_manager.dart";
import "package:window_manager/window_manager.dart";

/// The app-wide `Ctrl+Shift+M` hotkey that minimizes or restores the main
/// window.
///
/// Registration is opt-in ([settings.enableGlobalHotkey], off by default), so
/// merely launching Ciyue never grabs a system-wide key. Wayland sessions are
/// not supported at all: the compositor does not let a client read its own
/// minimized state or restore a minimized window, so the toggle cannot work
/// there. The setting is disabled in the UI and the desktop environment is
/// expected to bind the key instead.
class GlobalHotkeyService {
  GlobalHotkeyService._();

  static HotKey get _hotKey => HotKey(
    key: PhysicalKeyboardKey.keyM,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  /// Whether this session can register a working hotkey at all.
  ///
  /// Wayland exposes no way for a client to read its minimized state or to
  /// restore its own minimized window, so the toggle would silently break.
  static bool get isSupported => isDesktop() && !isWaylandSession();

  /// Whether this process currently holds the registration.
  static bool _applied = false;

  /// Brings the registration in line with [enabled].
  ///
  /// Returns `true` when the requested state is now in effect. The call is a
  /// no-op when the state already matches, and it never throws: failures are
  /// logged and reported so the UI can roll the switch back.
  static Future<bool> apply(bool enabled) async {
    if (!isSupported) {
      // Wayland: never touch hotkey_manager, not even to unregister. The
      // switch is off in the UI, so a request to enable it is a programming
      // error rather than something to act on.
      if (enabled) {
        talker.warning(
          "Global hotkey is not supported on this session; ignoring request.",
        );
      }
      return !enabled;
    }

    if (enabled == _applied) return true;

    try {
      // Unregister first so a stale binding from an earlier enable cannot
      // linger after the user turns the switch off.
      await hotKeyManager.unregisterAll();

      if (enabled) {
        await hotKeyManager.register(_hotKey, keyDownHandler: _toggleWindow);
      }

      _applied = enabled;
      talker.info("Global hotkey ${enabled ? "registered" : "unregistered"}.");
      return true;
    } catch (error, stackTrace) {
      _applied = false;
      talker.error("Failed to update the global hotkey", error, stackTrace);
      return false;
    }
  }

  /// Minimizes the window, or restores/shows it when it is minimized or hidden.
  static Future<void> _toggleWindow(HotKey hotKey) async {
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;

    if (!window.isVisible) {
      window.show();
      window.focus();
      return;
    }

    if (window.isMinimized) {
      window.restore();
      window.focus();
    } else {
      window.minimize();
    }
  }
}
