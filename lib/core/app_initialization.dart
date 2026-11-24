import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/hunspell.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:ciyue/services/desktop_selection_atspi.dart";
import "package:ciyue/services/desktop_selection_native.dart";
import "package:ciyue/services/desktop_selection_x11.dart";
import "package:ciyue/services/focused_app_x11.dart";
import "package:ciyue/services/global_hotkey.dart";
import "package:ciyue/services/lookup_bubble.dart";
import "package:ciyue/services/lookup_hotkey.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/services/changelog.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:ciyue/services/selection_watcher.dart";
import "package:ciyue/services/selection_watcher_x11.dart";
import "package:ciyue/services/startup.dart";
import "package:ciyue/services/updater.dart";
import "package:ciyue/services/web_server_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/changelog_dialog.dart";
import "package:ciyue/utils.dart";
import "package:dynamic_color/dynamic_color.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path_provider/path_provider.dart";
import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:simple_secure_storage/simple_secure_storage.dart";
import "package:tray_manager/tray_manager.dart" as tray;
import "package:url_launcher/url_launcher.dart";
import "package:window_manager/window_manager.dart";

Future<void> reloadHunspell() async {
  if (!settings.enableHunspellMorphology) {
    await hunspellManager.close();
    return;
  }

  await reloadHunspellFromDatabase();
}

Future<void> initGroup() async {
  int? groupId = prefs.getInt("currentDictionaryGroupId");
  if (groupId == null) {
    groupId = await dictGroupDao.addGroup("Default", []);
    await prefs.setInt("currentDictionaryGroupId", groupId);
  }
  await dictManager.setCurrentGroup(groupId);
  dictManager.groups = await dictGroupDao.getAllGroups();
  talker.info(
    "Loaded dictionary group $groupId "
    "(${dictManager.dictIds.length} dictionaries)",
  );

  final context = navigatorKey.currentContext;
  if (context != null && context.mounted) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(homeModelProvider).update();
      // A lookup can start before the group finishes loading — an Android
      // intent navigates as soon as its route exists — and that early result
      // is then cached for the page. Drop the cached lookups so the words on
      // screen are resolved again against the final dictionary set.
      container.invalidate(dictionaryLookupProvider);
      // The manage-dictionaries page is not part of the home tree, and on
      // large screens it is built immediately as the default settings
      // detail — possibly while this load is still running. Without this,
      // its checkboxes keep the pre-load state (unchecked) even after the
      // dictionaries are loaded and lookups work.
      container.read(dictManagerModelProvider).update();
    } catch (error, stackTrace) {
      talker.error(
        "Failed to update models after loading dictionaries",
        error,
        stackTrace,
      );
    }
  }
}

tray.TrayIcon? _trayIcon;
tray.ListenerId? _trayIconListenerId;
tray.Menu? _trayMenu;
tray.MenuItem? _showWindowMenuItem;
tray.MenuItem? _exitAppMenuItem;

Future<void> initTrayMenu() async {
  if (!isDesktop()) {
    return;
  }

  final context = navigatorKey.currentContext!;
  final l10n = AppLocalizations.of(context)!;

  var trayIcon = _trayIcon;
  if (trayIcon == null) {
    trayIcon = tray.TrayIcon.create();
    if (trayIcon == null) {
      throw StateError("Unable to create the system tray icon");
    }
    _trayIcon = trayIcon;

    final iconPath = Platform.isWindows
        ? "windows/runner/resources/app_icon.ico"
        : "assets/icon.png";
    final icon = Platform.isWindows
        ? tray.Image.fromFile(iconPath)
        : tray.ImageAsset.fromAsset(iconPath) ?? tray.Image.fromFile(iconPath);
    if (icon == null) {
      throw ArgumentError.value(
        iconPath,
        "iconPath",
        "Unable to load tray icon",
      );
    }
    trayIcon.icon = icon;

    // A click opens the menu natively (and exposes it to Linux StatusNotifier
    // hosts); preserve the existing right-click behavior with an event handler.
    trayIcon.setContextMenuTrigger(tray.ContextMenuTrigger.clicked);
    _trayIconListenerId = trayIcon.addListener((event) {
      if (event is tray.TrayIconRightClickedEvent) {
        _trayIcon?.openContextMenu();
      }
    });
  }

  var menu = _trayMenu;
  if (menu == null) {
    menu = tray.Menu.create();
    if (menu == null) {
      throw StateError("Unable to create the system tray menu");
    }

    final showWindowItem = tray.MenuItem.createWithLabelAndType(
      l10n.showWindow,
      tray.MenuItemType.normal,
    );
    if (showWindowItem == null) {
      throw StateError("Unable to create the show-window tray menu item");
    }
    showWindowItem.addListener((event) {
      if (event is tray.MenuItemClickedEvent) {
        final window = WindowManager.instance.getCurrent();
        window?.show();
        window?.focus();
      }
    });

    final exitAppItem = tray.MenuItem.createWithLabelAndType(
      l10n.exitApp,
      tray.MenuItemType.normal,
    );
    if (exitAppItem == null) {
      throw StateError("Unable to create the exit tray menu item");
    }
    exitAppItem.addListener((event) {
      if (event is tray.MenuItemClickedEvent) {
        unawaited(SystemNavigator.pop());
      }
    });

    menu
      ..addItem(showWindowItem)
      ..addSeparator()
      ..addItem(exitAppItem);
    trayIcon.setContextMenu(menu);
    _trayMenu = menu;
    _showWindowMenuItem = showWindowItem;
    _exitAppMenuItem = exitAppItem;
  } else {
    _showWindowMenuItem!.label = l10n.showWindow;
    _exitAppMenuItem!.label = l10n.exitApp;
  }

  trayIcon.setVisible(true);
}

void disposeTrayMenu() {
  final trayIcon = _trayIcon;
  if (trayIcon != null) {
    final listenerId = _trayIconListenerId;
    if (listenerId != null) {
      trayIcon.removeListener(listenerId);
    }
    trayIcon.setContextMenu(null);
    trayIcon.setVisible(false);
  }

  _showWindowMenuItem?.dispose();
  _exitAppMenuItem?.dispose();
  _trayMenu?.dispose();
  trayIcon?.dispose();

  _trayIcon = null;
  _trayIconListenerId = null;
  _trayMenu = null;
  _showWindowMenuItem = null;
  _exitAppMenuItem = null;
}

/// WebView2 ships with Edge on Windows 10/11, but LTSC and trimmed-down
/// images have no Edge, so the Evergreen Runtime can be missing entirely.
/// Every dictionary entry is rendered through WebView2, so point the user at
/// the installer instead of failing later inside `WebViewEnvironment.create`.
Future<void> _showWebView2InstallPromptIfNeeded() async {
  if (!Platform.isWindows) {
    return;
  }

  String? version;
  try {
    version = await WebViewEnvironment.getAvailableVersion();
  } catch (error, stackTrace) {
    talker.error("Failed to check the WebView2 runtime", error, stackTrace);
    return;
  }
  if (version != null) {
    return;
  }

  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) {
    return;
  }

  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.webView2MissingTitle),
      content: Text(l10n.webView2MissingMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.close),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            unawaited(
              launchUrl(
                Uri.parse("https://go.microsoft.com/fwlink/p/?LinkId=2124703"),
                mode: LaunchMode.externalApplication,
              ),
            );
          },
          child: Text(l10n.webView2Install),
        ),
      ],
    ),
  );
}

/// Whether this engine is the main window on desktop: the lookup popup
/// runs in a second engine that re-runs [initApp] with [isFloatingWindow]
/// set, and that engine must not re-register the system hotkeys, restart
/// the bubble, or resize its own window as if it were the main window.
@visibleForTesting
bool shouldInitDesktopMainWindow({required bool isFloatingWindow}) =>
    isDesktop() && !isFloatingWindow;

Future<void> initApp({bool isFloatingWindow = false}) async {
  runningInFloatingWindow = isFloatingWindow;
  talker.info("Initializing application...");

  final stopWatch = Stopwatch()..start();

  if (!isFloatingWindow) {
    await SimpleSecureStorage.initialize(
      const InitializationOptions(
        appName: "Ciyue",
        namespace: "ciyue_secure_store",
      ),
    );
  }

  await initPrefs();

  // Don't block the real app's first frame on dictionary loading.
  // The UI shows loading state via dictManager.isLoading (Completer-based
  // waitForLoading notifies when done).
  // Hunspell sources are filtered by the active group, so the group must be
  // loaded first even though neither blocks the first frame.
  unawaited(initGroup().then((_) => reloadHunspell()));

  flutterTts = FlutterTts();

  await wordbookTagsDao.loadTagsOrder();
  await wordbookTagsDao.existTag();

  if (Platform.isAndroid) {
    PlatformMethod.initHandler();
    unawaited(PlatformMethod.setSecureFlag(settings.secureScreen));

    // The floating window runs in a second FlutterEngine. Do not initialize
    // process-wide notification state from it; some plugins keep a static
    // channel and the last engine would otherwise steal callbacks from the
    // main engine.
    if (!isFloatingWindow) {
      await PlatformMethod.initNotifications();
      if (settings.notification) {
        await PlatformMethod.createPersistentNotification(true);
      }
    }
  }

  if (isDesktop()) {
    accentColor = await DynamicColorPlugin.getAccentColor();
  }

  if (isFloatingWindow) {
    packageInfo = await PackageInfo.fromPlatform();
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigatorKey.currentContext!;
      final locale = Localizations.localeOf(context);

      await initTrayMenu();

      await _showWebView2InstallPromptIfNeeded();

      packageInfo = await PackageInfo.fromPlatform();

      if (settings.autoUpdate) {
        await Updater.autoUpdate();
      }

      if (await ChangelogService.shouldShowChangelog(locale)) {
        final String changelogContent =
            await ChangelogService.getChangelogContent(locale);
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => ChangelogDialog(
            changelogContent: changelogContent,
            latestOnly: true,
          ),
        );
        await ChangelogService.markChangelogShown();
      }
    });
  }

  stopWatch.stop();

  talker.info("Ciyue spent ${stopWatch.elapsedMilliseconds} ms initializing.");

  final _ = Future.microtask(() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // Add a delay to avoid ConcurrentModificationException in onInit on Android
      // and other potential early initialization issues on other platforms.
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    try {
      if (Platform.isAndroid && settings.ttsEngine != null) {
        await flutterTts.setEngine(settings.ttsEngine!);
      }
      if (settings.ttsLanguage != null) {
        await flutterTts.setLanguage(settings.ttsLanguage!);
      }
      await flutterTts.setSpeechRate(settings.ttsSpeechRate);
      await flutterTts.setPitch(settings.ttsPitch);
    } catch (e) {
      talker.error("Failed to set TTS engine or language: $e");
    }

    if (Platform.isAndroid) {
      try {
        ttsEngines = await flutterTts.getEngines;
      } catch (e) {
        talker.error("Failed to get TTS engines: $e");
      }
    }

    if (!Platform.isLinux) {
      try {
        final List<dynamic> originalTTSLanguages =
            await flutterTts.getLanguages;
        for (final language in originalTTSLanguages) {
          if (language is String) {
            ttsLanguages.add(language);
          }
        }
        ttsLanguages.sort((a, b) => a.toString().compareTo(b.toString()));
      } catch (e) {
        talker.error("Failed to get TTS languages: $e");
      }
    }

    if (Platform.isWindows) {
      windowsWebview2Directory = (await getApplicationCacheDirectory()).path;
    }

    if (shouldInitDesktopMainWindow(isFloatingWindow: isFloatingWindow)) {
      await StartupService.init();

      // The app-wide hotkey is opt-in and off by default; the switch lives in
      // Settings → Other. Wayland sessions cannot read their own minimized
      // state or restore a minimized window, and the GlobalShortcuts portal
      // makes KDE ask for approval on every launch, so [GlobalHotkeyService]
      // skips those sessions and leaves the key to the desktop environment.
      await GlobalHotkeyService.apply(settings.enableGlobalHotkey);
      await initSelectionProviders();
      // The focused-app resolver serves both the hotkey's exclusion check
      // and the bubble; install it before the hotkey is registered.
      final focusedAppResolver = lookupFocusedAppResolver();
      LookupHotkeyService.focusedAppResolver = focusedAppResolver;
      // A registration that fails at startup (another program holds the
      // chord) must not leave the setting claiming the hotkey is on: the
      // switch reads the preference, so write it back off. Wayland is
      // excluded: the chord stays saved for the next X11 session.
      final lookupHotkeyApplied = await LookupHotkeyService.apply(
        settings.enableLookupHotkey,
      );
      if (!lookupHotkeyApplied &&
          settings.enableLookupHotkey &&
          LookupHotkeyService.isSupported) {
        await settings.setEnableLookupHotkey(false);
      }
      await restartLookupBubble(focusedAppResolver: focusedAppResolver);

      final window = WindowManager.instance.getCurrent();
      if (window != null) {
        window.setSize(const Size(800, 600).toNative(), false);
        window.backgroundColor = Colors.transparent.toNative();
        window.isVisibleInTaskbar = true;
        window.center();
        window.show();
        window.focus();
      }
    }

    if (settings.enableWebServer) {
      unawaited(webServerService.start());
    }

    talker.info("Application initialized successfully.");
  });
}

/// Installs the Phase 2 lane providers into the selection ladder, each
/// only when its `isAvailable` says it can work in this process. Until this
/// runs the ladder is the Phase 1 behaviour (synthetic copy on X11 with
/// XTest, clipboard everywhere else). Never throws at startup.
///
/// AT-SPI2 availability is only known after an async probe of the registry
/// daemon, so that probe runs first; a missing registry simply leaves the
/// AT-SPI2 rung uninstalled. Exposed for tests; startup calls it.
@visibleForTesting
Future<void> initSelectionProviders() async {
  try {
    if (!isDesktop()) return;
    // Probe AT-SPI2 on its own: the registry may be absent (or its bus
    // not up yet) at startup, and that must not block the other lanes —
    // the X11 PRIMARY rung is the one the bubble relies on. Linux only:
    // Windows and macOS have no session bus, so the probe there could only
    // fail.
    if (Platform.isLinux) {
      try {
        await AtSpiSelectionProvider.refreshAvailability();
      } catch (error, stackTrace) {
        talker.error("Failed to probe AT-SPI2 availability", error, stackTrace);
      }
    }
    SelectionTextProviders.x11PrimaryProvider =
        X11PrimarySelectionProvider.isAvailable
        ? X11PrimarySelectionProvider()
        : null;
    SelectionTextProviders.atspiProvider = AtSpiSelectionProvider.isAvailable
        ? AtSpiSelectionProvider()
        : null;
    SelectionTextProviders.nativeDesktopProvider = NativeSelection.isAvailable
        ? const NativeSelectionProvider()
        : null;
    SelectionTextProviders.nativeCopySender = NativeSelection.isAvailable
        ? const NativeCopyKeySender()
        : null;
  } catch (error, stackTrace) {
    talker.error(
      "Failed to install the selection providers",
      error,
      stackTrace,
    );
  }
}

/// The selection watcher for this platform, or null when none exists.
/// AT-SPI2 (Lane B) first — it works on X11 and Wayland — else XFixes on
/// X11 (Lane A). Lane C built no watcher, so there is none on
/// Windows/macOS. The watcher only starts when the bubble is enabled.
/// Exposed for tests; [restartLookupBubble] calls it.
@visibleForTesting
SelectionWatcher? lookupSelectionWatcher() {
  if (AtSpiSelectionProvider.isAvailable) {
    return AtSpiSelectionWatcher();
  }
  if (Platform.isLinux && !isWaylandSession()) {
    // isAvailable is an instance getter on the XFixes watcher (it probes
    // libXfixes on construction), so check the instance, not the class.
    final watcher = XFixesSelectionWatcher();
    if (watcher.isAvailable) return watcher;
  }
  return null;
}

/// The focused-app resolver for this platform, or null when none exists.
/// The X11 resolver (Lane A) on X11, Lane C's native resolver on
/// Windows/macOS; none on Wayland, where AT-SPI2 reports no focused app.
/// Exposed for tests; [restartLookupBubble] calls it.
@visibleForTesting
FocusedAppResolver? lookupFocusedAppResolver() {
  if (Platform.isLinux) {
    if (!isWaylandSession() && X11FocusedAppResolver.isAvailable) {
      return const X11FocusedAppResolver();
    }
    return null;
  }
  if ((Platform.isWindows || Platform.isMacOS) && NativeSelection.isAvailable) {
    return const NativeFocusedAppResolver();
  }
  return null;
}

/// Reports whether the bubble's configured modifier key is held, on X11
/// only: the X11 modifier state comes from Lane A's helper, and no other
/// platform has one — there the trigger simply never fires. Exposed for
/// tests; [restartLookupBubble] calls it.
@visibleForTesting
Future<bool> Function(String modifier)? lookupModifierHeld() {
  if (!Platform.isLinux || isWaylandSession()) return null;
  return (modifier) async {
    final parsed = switch (modifier) {
      "alt" => X11Modifier.alt,
      "shift" => X11Modifier.shift,
      _ => X11Modifier.control,
    };
    return X11ModifierState.isHeld(parsed);
  };
}

/// (Re)builds the desktop lookup bubble from the current preferences and
/// starts it when enabled. Called at startup and whenever a bubble
/// preference changes in Settings, so toggling the switch or changing the
/// trigger takes effect without a restart. The service instance itself is
/// never replaced (see [LookupBubbleService.instance]): [reconfigure]
/// updates it in place, so the bubble host — which captured the instance
/// at construction — keeps listening to the live service. A disabled
/// bubble leaves the service stopped with no watcher behind. Never throws.
Future<void> restartLookupBubble({
  FocusedAppResolver? focusedAppResolver,
}) async {
  try {
    if (!isDesktop()) return;
    await LookupBubbleService.instance.reconfigure(
      enabled: settings.enableLookupBubble,
      trigger: settings.lookupBubbleTrigger,
      modifier: settings.lookupBubbleModifier,
      excludedApps: settings.lookupExcludedApps,
      watcher: lookupSelectionWatcher(),
      focusedAppResolver: focusedAppResolver ?? lookupFocusedAppResolver(),
      isModifierHeld: lookupModifierHeld(),
    );
  } catch (error, stackTrace) {
    talker.error("Failed to start the lookup bubble", error, stackTrace);
  }
}

const preferencesAllowList = <String>{
  "currentDictionaryGroupId",
  "exportDirectory",
  "autoExport",
  "exportFileName",
  "autoRemoveSearchWord",
  "language",
  "themeMode",
  "enableDynamicColor",
  "pureBlackDarkMode",
  "eInkMode",
  "themeSeedColor",
  "dictionaryCustomCss",
  "dictionaryBackgroundColor",
  "dictionaryDarkReaderEnabled",
  "contentScale",
  "tagsOrder",
  "secureScreen",
  "searchBarInAppBar",
  "showSidebarIcon",
  "showSearchPane",
  "searchPaneWidth",
  "searchMode",
  "dictionariesDirectory",
  "exportPath",
  "notification",
  "showMoreOptionsButton",
  "skipTaggedWord",
  "aiProvider",
  "aiProviderConfigs",
  "aiProviderFetchedModels",
  "aiExplainWord",
  "aiExplainWordManual",
  "aiExplainSourceLanguageMode",
  "aiExplainSourceLanguage",
  "aiExplainStructured",
  "includePrereleaseUpdates",
  "updateChannel",

  // AI Prompts
  "customExplainPrompt",
  "customExplainStructuredPrompt",
  "customTranslatePrompt",
  "customWritingCheckPrompt",
  "customQuizPrompt",
  "customVocabularyPrompt",
  "customScenarioPrompt",

  // Learning Settings
  "quizQuestionCount",
  "quizQuestionTypes",
  "vocabularyExtractCount",
  "vocabularyDifficulty",
  "customChatScenarios",
  "disabledPresetScenarios",
  "chatHistory",
  "chatSessions",
  "chatActiveSessionId",

  "tabBarPosition",
  "showSearchBarInWordDisplay",
  "autoUpdate",
  "ttsEngine",
  "ttsLanguage",
  "ttsLanguageFavorites",
  "linuxTtsVoice",
  "ttsSpeechRate",
  "ttsPitch",
  "pronunciationMode",
  "wiktionaryPronunciationEnabled",
  "forvoPronunciationEnabled",
  "wiktionaryPronunciationLanguage",
  "forvoPronunciationLanguage",
  "forvoPronunciationQuotaDate",
  "forvoPronunciationQuotaCount",
  "audioDirectory",
  "advance",
  "enableHunspellMorphology",
  "hunspellLookupMode",
  "enableHistory",
  "versionCode",
  "dictionarySwitchStyle",
  "mobileToolbarPreset",
  "rockerGestureAction",
  "wheelGestureAction",
  "translationProvider",
  "deeplxUrl",
  "deeplApiKey",
  "googleCloudApiKey",
  "azureApiKey",
  "azureRegion",
  "yandexApiKey",
  "yandexFolderId",
  "translationSourceOrder",
  "translationSourcesEnabled",
  "isRichOutput",
  "enableTranslationHistory",
  "enableWritingCheckHistory",
  "autoFocusSearch",
  "launchAtStartup",
  "enableGlobalHotkey",
  "enableLookupHotkey",
  "enableLookupBubble",
  "lookupBubbleTrigger",
  "lookupBubbleModifier",
  "lookupExcludedApps",
  "lookupHotkeyChord",
  "flashcardDailyNewLimit",
  "enableWebServer",
  "webServerPort",
  "webServerAllowLan",
  ...CloudSyncConfigurationStore.preferenceKeys,
};

Future<void> initPrefs() async {
  talker.info("Initializing shared preferences...");

  prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: preferencesAllowList,
    ),
  );

  talker.info("Shared preferences initialized successfully.");
}
