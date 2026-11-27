// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: implementation_imports

import "package:ciyue/core/localization_delegates.dart";
import "package:ciyue/core/locale_utils.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/lookup_popup.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/lookup_popup/lookup_popup_page.dart";
import "package:flutter/services.dart";
import "package:flutter/src/widgets/_window.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

/// Hosts the lookup popup's second window inside the main window's tree.
///
/// The popup content lives in the [Window] built here, so it renders into
/// the popup controller's view while the main window keeps its implicit
/// engine view untouched. Providers flow from the root [ProviderScope] above
/// this host, so the popup page can use the same providers as the main UI.
///
/// The host stays mounted for the app lifetime (see main.dart); it only
/// mounts the popup [Window] while the service has an active request, and
/// unmounts it on dismiss — the native window itself is hidden and reused,
/// never destroyed.
class LookupPopupHost extends ConsumerStatefulWidget {
  LookupPopupHost({
    super.key,
    required this.child,
    this.popupBuilder,
    LookupPopupService? service,
  }) : service = service ?? LookupPopupService.instance;

  final Widget child;

  /// Builds the popup content for [request]; defaults to [LookupPopupPage].
  /// Tests substitute a stand-in here so they never build the real page.
  final Widget Function(LookupPopupRequest request, VoidCallback onClose)?
  popupBuilder;

  final LookupPopupService service;

  @override
  ConsumerState<LookupPopupHost> createState() => _LookupPopupHostState();
}

class _LookupPopupHostState extends ConsumerState<LookupPopupHost> {
  @override
  void initState() {
    super.initState();
    widget.service.currentRequest.addListener(_onRequestChanged);
  }

  @override
  void dispose() {
    widget.service.currentRequest.removeListener(_onRequestChanged);
    super.dispose();
  }

  void _onRequestChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.service.currentRequest.value;
    // The splash tree is mounted before initPrefs() runs, and reading the
    // settings then would construct Settings while its `prefs` field is still
    // unset. A popup cannot be requested before the services start, which
    // happens after the preferences are loaded, so only watch while there is a
    // popup to render. The popup app reads its theme, mode and locale from the
    // settings at build time, so this still rebuilds the open popup when the
    // reader changes any of them in the main window.
    if (request != null) {
      ref.watch(settingsProvider);
    }
    final backend = widget.service.windowBackend;
    final controller = backend.controller;
    final Widget? popupView =
        request == null || controller == null || !backend.isAvailable
        ? null
        : Window(controller: controller, child: _popupApp(request));
    return ViewAnchor(view: popupView, child: widget.child);
  }

  /// The popup's own app: same seed colour and localizations as the main
  /// window, simplified (no router, no dynamic colour — the popup is one
  /// page). Escape closes it from anywhere inside the popup.
  Widget _popupApp(LookupPopupRequest request) {
    final seedColor = settings.themeSeedColor;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.service.hide();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MaterialApp(
        title: "Ciyue",
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: settings.themeMode,
        locale: _locale(),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
          const FallbackMaterialLocalizationsDelegate(),
          const FallbackWidgetsLocalizationsDelegate(),
          const FallbackCupertinoLocalizationsDelegate(),
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        home:
            widget.popupBuilder?.call(request, widget.service.hide) ??
            LookupPopupPage(
              text: request.text,
              initialMode: request.mode,
              onClose: widget.service.hide,
            ),
        builder: (context, child) {
          // Some dependencies still use package:flutter/material.dart.
          // Keep their legacy ThemeData and MaterialLocalizations working
          // while they are migrated to package:material_ui.
          // ignore: deprecated_member_use
          return MaterialUiCompatibilityBridge(
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  /// The locale the main window uses, from the language setting.
  Locale? _locale() => localeFromLanguageCode(settings.language);
}
