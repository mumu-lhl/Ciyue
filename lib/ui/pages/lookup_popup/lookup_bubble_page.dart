// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: implementation_imports

import "package:ciyue/core/localization_delegates.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/lookup_bubble.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/src/widgets/_window.dart";
import "package:material_ui/material_ui.dart";

/// The lookup bubble page (issue #909): a single search button in the
/// 48x48 bubble window. Tapping it opens the lookup popup for the text the
/// bubble was shown for; the button itself holds no state — the service
/// owns the text and hides the bubble on tap.
class LookupBubblePage extends StatelessWidget {
  const LookupBubblePage({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    // Opaque on purpose: a bubble floating over an arbitrary app needs its
    // own surface to stay legible. The circle fills the 48x48 window.
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Material(
          color: colorScheme.primaryContainer,
          shape: const CircleBorder(),
          child: IconButton(
            key: const ValueKey("lookup_bubble_button"),
            tooltip: locale.lookup,
            icon: Icon(Icons.search, color: colorScheme.onPrimaryContainer),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }
}

/// Hosts the bubble's second window inside the main window's tree, the way
/// the lookup popup host hosts the popup window.
///
/// The host stays mounted for the app lifetime; it only mounts the bubble
/// [Window] while the service has text to show for, and unmounts it on
/// dismiss — the native window itself is hidden and reused, never destroyed.
/// Mount this next to the lookup popup host in main.dart.
class LookupBubbleHost extends StatefulWidget {
  LookupBubbleHost({
    super.key,
    required this.child,
    LookupBubbleService? service,
  }) : service = service ?? LookupBubbleService.instance;

  final Widget child;

  final LookupBubbleService service;

  @override
  State<LookupBubbleHost> createState() => _LookupBubbleHostState();
}

class _LookupBubbleHostState extends State<LookupBubbleHost> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.service.currentText,
      builder: (context, text, child) {
        final backend = widget.service.bubbleBackend;
        final controller = backend.bubbleController;
        final Widget? bubbleView =
            text == null || controller == null || !backend.isAvailable
            ? null
            : Window(controller: controller, child: _bubbleApp());
        return ViewAnchor(view: bubbleView, child: child!);
      },
      child: widget.child,
    );
  }

  /// The bubble's own app: same seed colour and localizations as the main
  /// window, simplified (no router — the bubble is one button).
  Widget _bubbleApp() {
    final seedColor = settings.themeSeedColor;
    return MaterialApp(
      title: "Ciyue",
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seedColor)),
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
      home: LookupBubblePage(onTap: widget.service.openLookup),
      builder: (context, child) {
        // Some dependencies still use package:flutter/material.dart.
        // Keep their legacy ThemeData and MaterialLocalizations working
        // while they are migrated to package:material_ui.
        // ignore: deprecated_member_use
        return MaterialUiCompatibilityBridge(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// The locale the main window uses, from the language setting.
  Locale? _locale() {
    if (settings.language == "system") return null;
    final parts = settings.language!.split("_");
    if (parts.length > 1) {
      return Locale.fromSubtags(languageCode: parts[0], countryCode: parts[1]);
    }
    return Locale(settings.language!);
  }
}
