import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/desktop_selection_xtest.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:ciyue/services/selection_watcher.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// Native selection access on Windows and macOS, backed by the
/// `ciyue/selection` method channel implemented in the runners
/// (`windows/runner/selection_channel.cpp`,
/// `macos/Runner/SelectionChannel.swift`).
///
/// The channel is created lazily on first use, so importing this file never
/// touches the binary messenger. Every call returns null/false instead of
/// throwing — including when the native side is missing (an older build) or
/// the platform has no native implementation.
class NativeSelection {
  NativeSelection._();

  static const String channelName = "ciyue/selection";

  /// Which platforms have a native implementation. Overridable in tests:
  /// the test host is Linux, where the real check is false, so tests stub
  /// this to drive the channel path.
  @visibleForTesting
  static bool Function() platformCheck = () =>
      Platform.isWindows || Platform.isMacOS;

  /// Whether the native selection channel is available in this process.
  static bool get isAvailable => platformCheck();

  static MethodChannel? _channel;

  static MethodChannel get _channelInstance =>
      _channel ??= const MethodChannel(channelName);

  static Future<T?> _invoke<T>(String method) async {
    try {
      return await _channelInstance.invokeMethod<T>(method);
    } on MissingPluginException catch (error, stackTrace) {
      talker.warning(
        "Native selection channel is missing ($method)",
        error,
        stackTrace,
      );
      return null;
    } on PlatformException catch (error, stackTrace) {
      talker.error(
        "Native selection channel call failed ($method)",
        error,
        stackTrace,
      );
      return null;
    } catch (error, stackTrace) {
      talker.error(
        "Native selection channel call failed ($method)",
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Like [_invoke], but a failure is a [SelectionUnavailableException] so
  /// the ladder can try the next rung instead of treating a broken channel
  /// as "no selection". Only the selection provider uses this: the sender
  /// and the app resolver report failure as false/null to their own
  /// callers.
  static Future<T?> _invokeOrThrow<T>(String method) async {
    try {
      return await _channelInstance.invokeMethod<T>(method);
    } catch (error) {
      throw SelectionUnavailableException(
        "native selection call $method failed: $error",
      );
    }
  }
}

/// Reads the selected text of the focused element in another application
/// through the native runner. Windows only, macOS only — anywhere else this
/// returns null without touching the channel.
///
/// Returns null only when the native side reports no selection. A missing
/// or failing channel throws [SelectionUnavailableException] so the ladder
/// can try the next rung instead of reporting "no selection".
class NativeSelectionProvider implements SelectionTextProvider {
  const NativeSelectionProvider();

  @override
  Future<String?> getSelectedText() async {
    if (!NativeSelection.isAvailable) {
      throw const SelectionUnavailableException(
        "native selection is unavailable",
      );
    }
    final text = (await NativeSelection._invokeOrThrow<String>(
      "getSelectedText",
    ))?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}

/// Sends the platform copy keystroke through the native runner: Ctrl+C on
/// Windows (SendInput), Cmd+C on macOS (CGEvent). Replaces
/// [UnsupportedCopyKeySender] on those platforms; the ladder wires it in.
class NativeCopyKeySender implements CopyKeySender {
  const NativeCopyKeySender();

  @override
  Future<bool> sendCopy() async {
    if (!NativeSelection.isAvailable) return false;
    return await NativeSelection._invoke<bool>("sendCopy") ?? false;
  }
}

/// Resolves the focused application through the native runner.
class NativeFocusedAppResolver implements FocusedAppResolver {
  const NativeFocusedAppResolver();

  @override
  Future<String?> getFocusedAppId() async {
    if (!NativeSelection.isAvailable) return null;
    final id = (await NativeSelection._invoke<String>("getFocusedAppId"))
        ?.trim();
    return (id == null || id.isEmpty) ? null : id;
  }
}
