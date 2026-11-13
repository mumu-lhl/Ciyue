import "dart:async";
import "dart:io";

import "package:ciyue/core/app_router.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/word_display/entry_pager.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Pages the entry from the device's own keys on Android.
///
/// The volume rocker and the page keys of an e-ink reader are dispatched by
/// the activity before the engine sees them, and a WebView holding the focus
/// would swallow them in any case, so `MainActivity.dispatchKeyEvent` keeps
/// them and calls back here.
///
/// The app only asks for the keys while the e-ink mode is on **and** an entry
/// is on screen; the rest of the time they are handed back to the system, so
/// the volume keys keep changing the volume.
class HardwareKeyPaging {
  HardwareKeyPaging._();

  static const _channel = MethodChannel("org.eu.mumulhl.ciyue/hardware_keys");

  static bool _started = false;
  static ProviderContainer? _container;
  static ProviderSubscription<Settings>? _settingsSubscription;

  /// Installs the handler once, from the running app.
  static void start(ProviderContainer container) {
    if (_started || !Platform.isAndroid) return;
    _started = true;
    _container = container;

    _channel.setMethodCallHandler((call) async {
      if (call.method == "page") {
        final direction = (call.arguments as num?)?.toInt() ?? 0;
        if (direction != 0) {
          await pageActiveEntry(direction);
        }
      }
      return null;
    });

    _settingsSubscription = container.listen<Settings>(
      settingsProvider,
      (previous, next) => _pushState(),
    );
    activeEntryPager.addListener(_pushState);
    // Leaving the entry (chat, settings, a search page) must give the keys
    // back even though the pager stays registered behind the new route.
    router.routerDelegate.addListener(_pushState);
    _pushState();
  }

  /// Whether the route on top is one that shows an entry.
  static bool _entryRouteOnTop() {
    final location = router.routerDelegate.currentConfiguration.uri.path;
    return location == "/" || location.startsWith("/word/");
  }

  /// Detaches the handler again. The app runs one instance for its whole
  /// life, so this exists for tests and for a scope that is torn down.
  static void stop() {
    _settingsSubscription?.close();
    _settingsSubscription = null;
    activeEntryPager.removeListener(_pushState);
    router.routerDelegate.removeListener(_pushState);
    _started = false;
  }

  static void _pushState() {
    final container = _container;
    if (container == null) return;
    final enabled =
        container.read(settingsProvider).eInkMode &&
        activeEntryPager.value != null &&
        _entryRouteOnTop();
    unawaited(
      _channel.invokeMethod<void>("setPagingEnabled", enabled).catchError((
        Object _,
      ) {
        // No Android side (desktop, tests): the keys simply stay the system's.
      }),
    );
  }
}
