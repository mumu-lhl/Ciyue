import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/models/audio.dart";
import "package:ciyue/models/hunspell.dart";
import "package:material_ui/material_ui.dart";

final settings = Settings();

enum TabBarPosition { top, bottom }

enum DictionarySwitchStyle { expansion, tag }

/// Update channel for app updates.
enum UpdateChannel {
  /// Stable releases only.
  stable,

  /// Beta/Alpha prereleases (excludes nightly builds).
  preview,

  /// Nightly builds (bleeding edge).
  nightly,
}

class Settings extends ChangeNotifier {
  // Deliberately does not call super.dispose(): the app uses a single
  // process-lifetime [settings] singleton, which is also what
  // `settingsProvider` exposes. Riverpod's ChangeNotifierProvider disposes
  // its notifier when the provider scope tears down; disposing the shared
  // singleton here would break every later scope
  // ("A Settings was used after being disposed").
  @override
  // ignore: must_call_super
  void dispose() {}

  late bool autoExport;
  late String exportFileName;
  late String? exportDirectory;
  late String? exportPath;

  /// Notify listeners that settings have changed. Use when a field is
  /// modified directly (bypassing a setter).
  void refresh() => notifyListeners();

  late ThemeMode themeMode;
  late bool enableDynamicColor;
  late bool pureBlackDarkMode;
  late Color themeSeedColor;
  late String dictionaryCustomCss;
  late Color? dictionaryBackgroundColor;
  late bool dictionaryDarkReaderEnabled;
  String? language;
  late bool searchBarInAppBar;
  late TabBarPosition tabBarPosition;
  late bool showSidebarIcon;
  late bool showMoreOptionsButton;
  late bool showSearchBarInWordDisplay;
  late DictionarySwitchStyle dictionarySwitchStyle;

  late bool autoRemoveSearchWord;
  late bool autoFocusSearch;

  late bool secureScreen;

  late bool notification;

  late bool autoUpdate;
  late bool enableHistory;
  late UpdateChannel updateChannel;
  late bool skipTaggedWord;
  late bool advance;

  late bool enableHunspellMorphology;
  late HunspellLookupMode hunspellLookupMode;

  late String aiProvider;
  late bool aiExplainWord;

  /// Whether AI word explanations are requested as structured data
  /// (JSON) and rendered natively, instead of markdown text.
  late bool aiExplainStructured;
  Map<String, Map<String, dynamic>> aiProviderConfigs = {};
  Map<String, List<Map<String, String>>> aiProviderFetchedModels = {};

  late String? ttsEngine;
  late String? ttsLanguage;
  late double ttsSpeechRate;
  late double ttsPitch;
  late PronunciationMode pronunciationMode;

  late bool wiktionaryPronunciationEnabled;
  late bool forvoPronunciationEnabled;
  late String wiktionaryPronunciationLanguage;
  late String forvoPronunciationLanguage;

  late String translationProvider;
  late String? deeplxUrl;
  late bool isRichOutput;

  // API keys for key-based translation sources.
  late String? deeplApiKey;
  late String? googleCloudApiKey;
  late String? azureApiKey;
  late String? azureRegion;
  late String? yandexApiKey;
  late String? yandexFolderId;

  late bool enableTranslationHistory;
  late bool enableWritingCheckHistory;

  late bool launchAtStartup;
  late int flashcardDailyNewLimit;

  late bool enableWebServer;
  late int webServerPort;
  late bool webServerAllowLan;

  Settings() {
    launchAtStartup = prefs.getBool("launchAtStartup") ?? false;
    flashcardDailyNewLimit = prefs.getInt("flashcardDailyNewLimit") ?? 20;
    enableWebServer = prefs.getBool("enableWebServer") ?? false;
    webServerPort = prefs.getInt("webServerPort") ?? 47117;
    webServerAllowLan = prefs.getBool("webServerAllowLan") ?? false;
    autoExport = prefs.getBool("autoExport") ?? false;
    exportFileName = prefs.getString("exportFileName") ?? "ciyue";
    exportDirectory = prefs.getString("exportDirectory");
    exportPath = prefs.getString("exportPath");

    autoRemoveSearchWord = prefs.getBool("autoRemoveSearchWord") ?? false;
    autoFocusSearch = prefs.getBool("autoFocusSearch") ?? false;

    secureScreen = prefs.getBool("secureScreen") ?? false;

    language = prefs.getString("language") ?? "system";
    enableDynamicColor = prefs.getBool("enableDynamicColor") ?? true;
    pureBlackDarkMode = prefs.getBool("pureBlackDarkMode") ?? false;
    final int? themeSeedColorValue = prefs.getInt("themeSeedColor");
    themeSeedColor = Color(themeSeedColorValue ?? Colors.blue.toARGB32());
    dictionaryCustomCss = prefs.getString("dictionaryCustomCss") ?? "";
    final backgroundColorValue = prefs.getInt("dictionaryBackgroundColor");
    dictionaryBackgroundColor = backgroundColorValue == null
        ? null
        : Color(backgroundColorValue);
    dictionaryDarkReaderEnabled =
        prefs.getBool("dictionaryDarkReaderEnabled") ?? false;
    searchBarInAppBar = prefs.getBool("searchBarInAppBar") ?? true;
    showSidebarIcon = prefs.getBool("showSidebarIcon") ?? true;
    showMoreOptionsButton = prefs.getBool("showMoreOptionsButton") ?? true;
    showSearchBarInWordDisplay =
        prefs.getBool("showSearchBarInWordDisplay") ?? true;

    final dictionarySwitchStyleString = prefs.getString(
      "dictionarySwitchStyle",
    );
    if (dictionarySwitchStyleString == null) {
      dictionarySwitchStyle = DictionarySwitchStyle.expansion;
    } else {
      dictionarySwitchStyle = DictionarySwitchStyle.values.byName(
        dictionarySwitchStyleString,
      );
    }

    autoUpdate = prefs.getBool("autoUpdate") ?? false;
    // Migrate from old bool pref to enum. Old true -> preview channel.
    final channelString = prefs.getString("updateChannel");
    if (channelString != null) {
      updateChannel = UpdateChannel.values.firstWhere(
        (c) => c.name == channelString,
        orElse: () => UpdateChannel.stable,
      );
    } else {
      // Fallback to legacy bool pref.
      final legacyPrerelease =
          prefs.getBool("includePrereleaseUpdates") ?? false;
      updateChannel = legacyPrerelease
          ? UpdateChannel.preview
          : UpdateChannel.stable;
    }

    notification = prefs.getBool("notification") ?? false;

    enableHistory = prefs.getBool("enableHistory") ?? true;

    advance = prefs.getBool("advance") ?? false;

    enableHunspellMorphology =
        prefs.getBool("enableHunspellMorphology") ?? false;
    final hunspellLookupModeName = prefs.getString("hunspellLookupMode");
    hunspellLookupMode = HunspellLookupMode.values.firstWhere(
      (mode) => mode.name == hunspellLookupModeName,
      orElse: () => HunspellLookupMode.fallback,
    );

    skipTaggedWord = prefs.getBool("skipTaggedWord") ?? false;

    aiProvider = prefs.getString("aiProvider") ?? "openai";
    aiExplainWord = prefs.getBool("aiExplainWord") ?? false;
    aiExplainStructured = prefs.getBool("aiExplainStructured") ?? true;
    translationProvider = prefs.getString("translationProvider") ?? "ai";
    deeplxUrl = prefs.getString("deeplxUrl");
    isRichOutput = prefs.getBool("isRichOutput") ?? false;
    deeplApiKey = prefs.getString("deeplApiKey");
    googleCloudApiKey = prefs.getString("googleCloudApiKey");
    azureApiKey = prefs.getString("azureApiKey");
    azureRegion = prefs.getString("azureRegion");
    yandexApiKey = prefs.getString("yandexApiKey");
    yandexFolderId = prefs.getString("yandexFolderId");

    enableTranslationHistory =
        prefs.getBool("enableTranslationHistory") ?? true;
    enableWritingCheckHistory =
        prefs.getBool("enableWritingCheckHistory") ?? true;

    ttsEngine = prefs.getString("ttsEngine");
    ttsLanguage = prefs.getString("ttsLanguage");
    // 0.5 speech rate and 1.0 pitch are the platform-normal values, so
    // applying the defaults does not change existing users' speech.
    ttsSpeechRate = prefs.getDouble("ttsSpeechRate") ?? 0.5;
    ttsPitch = prefs.getDouble("ttsPitch") ?? 1.0;
    pronunciationMode = PronunciationMode.values.firstWhere(
      (mode) => mode.name == prefs.getString("pronunciationMode"),
      orElse: () => PronunciationMode.packFirst,
    );
    wiktionaryPronunciationEnabled =
        prefs.getBool("wiktionaryPronunciationEnabled") ?? false;
    forvoPronunciationEnabled =
        prefs.getBool("forvoPronunciationEnabled") ?? false;
    wiktionaryPronunciationLanguage =
        prefs.getString("wiktionaryPronunciationLanguage") ?? "";
    forvoPronunciationLanguage =
        prefs.getString("forvoPronunciationLanguage") ?? "";

    var aiProviderConfigsString = prefs.getString("aiProviderConfigs");
    if (aiProviderConfigsString != null) {
      aiProviderConfigs =
          Map.castFrom<dynamic, dynamic, String, Map<String, dynamic>>(
            jsonDecode(aiProviderConfigsString),
          );
    }

    final aiProviderFetchedModelsString = prefs.getString(
      "aiProviderFetchedModels",
    );
    if (aiProviderFetchedModelsString != null) {
      try {
        final decoded =
            jsonDecode(aiProviderFetchedModelsString) as Map<String, dynamic>;
        aiProviderFetchedModels = decoded.map((k, v) {
          final list = (v as List)
              .map((item) => Map<String, String>.from(item as Map))
              .toList();
          return MapEntry(k, list);
        });
      } catch (_) {}
    }

    final tabBarPositionString = prefs.getString("tabBarPosition");
    if (tabBarPositionString == null) {
      tabBarPosition = TabBarPosition.top;
    } else {
      tabBarPosition = TabBarPosition.values.byName(tabBarPositionString);
    }

    final themeModeString = prefs.getString("themeMode");
    switch (themeModeString) {
      case "light":
        themeMode = ThemeMode.light;
      case "dark":
        themeMode = ThemeMode.dark;
      case "system" || null:
        themeMode = ThemeMode.system;
    }
  }

  String get aiAPIUrl {
    return aiProviderConfigs[aiProvider]?["apiUrl"] ?? "";
  }

  Map<String, dynamic> getAiProviderConfig(String provider) {
    return aiProviderConfigs[provider] ?? {"model": "", "apiKey": ""};
  }

  Future<void> saveAiProviderConfig(
    String provider,
    String model,
    String apiKey,
  ) async {
    final currentConfig = aiProviderConfigs[provider] ?? {};
    currentConfig["model"] = model;
    currentConfig["apiKey"] = apiKey;
    aiProviderConfigs[provider] = currentConfig;
    await prefs.setString("aiProviderConfigs", jsonEncode(aiProviderConfigs));
  }

  /// The image-generation model chosen for a provider, stored in
  /// the same per-provider config map under `imageModel`.
  Future<void> saveAiProviderImageModel(
    String provider,
    String imageModel,
  ) async {
    final currentConfig = aiProviderConfigs[provider] ?? {};
    currentConfig["imageModel"] = imageModel;
    aiProviderConfigs[provider] = currentConfig;
    await prefs.setString("aiProviderConfigs", jsonEncode(aiProviderConfigs));
  }

  List<ModelInfo> getFetchedModels(String provider) {
    final list = aiProviderFetchedModels[provider];
    if (list == null || list.isEmpty) return [];
    return list
        .map((m) => ModelInfo(m["originName"]!, m["shownName"]!))
        .toList();
  }

  Future<void> saveFetchedModels(
    String provider,
    List<ModelInfo> models,
  ) async {
    aiProviderFetchedModels[provider] = models
        .map((m) => {"originName": m.originName, "shownName": m.shownName})
        .toList();
    await prefs.setString(
      "aiProviderFetchedModels",
      jsonEncode(aiProviderFetchedModels),
    );
  }

  Future<void> setAiAPIUrl(String apiUrl) async {
    if (aiProviderConfigs[aiProvider] == null) {
      aiProviderConfigs[aiProvider] = {};
    }

    aiProviderConfigs[aiProvider]!["apiUrl"] = apiUrl;
    await prefs.setString("aiProviderConfigs", jsonEncode(aiProviderConfigs));
    notifyListeners();
  }

  Future<void> setEnableDynamicColor(bool value) async {
    enableDynamicColor = value;
    await prefs.setBool("enableDynamicColor", value);
    notifyListeners();
  }

  Future<void> setThemeSeedColor(Color color) async {
    themeSeedColor = color;
    await prefs.setInt("themeSeedColor", color.toARGB32());
    notifyListeners();
  }

  Future<void> setPureBlackDarkMode(bool value) async {
    pureBlackDarkMode = value;
    await prefs.setBool("pureBlackDarkMode", value);
    notifyListeners();
  }

  Future<void> setDictionaryCustomCss(String value) async {
    dictionaryCustomCss = value;
    await prefs.setString("dictionaryCustomCss", value);
    notifyListeners();
  }

  Future<void> setDictionaryBackgroundColor(Color? color) async {
    dictionaryBackgroundColor = color;
    if (color == null) {
      await prefs.remove("dictionaryBackgroundColor");
    } else {
      await prefs.setInt("dictionaryBackgroundColor", color.toARGB32());
    }
    notifyListeners();
  }

  Future<void> setDictionaryDarkReaderEnabled(bool value) async {
    dictionaryDarkReaderEnabled = value;
    await prefs.setBool("dictionaryDarkReaderEnabled", value);
    notifyListeners();
  }

  Future<void> setTabBarPosition(TabBarPosition position) async {
    tabBarPosition = position;
    await prefs.setString("tabBarPosition", position.name);
    notifyListeners();
  }

  Future<void> setDictionarySwitchStyle(DictionarySwitchStyle style) async {
    dictionarySwitchStyle = style;
    await prefs.setString("dictionarySwitchStyle", style.name);
    notifyListeners();
  }

  Future<void> setAutoUpdate(bool value) async {
    autoUpdate = value;
    await prefs.setBool("autoUpdate", value);
    notifyListeners();
  }

  Future<void> setUpdateChannel(UpdateChannel channel) async {
    updateChannel = channel;
    await prefs.setString("updateChannel", channel.name);
    notifyListeners();
  }

  Future<void> setTTSEngine(String engine) async {
    ttsEngine = engine;
    await prefs.setString("ttsEngine", engine);
    notifyListeners();
  }

  Future<void> setTTSLanguage(String lang) async {
    ttsLanguage = lang;
    await prefs.setString("ttsLanguage", lang);
    notifyListeners();
  }

  Future<void> setTTSSpeechRate(double rate) async {
    ttsSpeechRate = rate;
    await prefs.setDouble("ttsSpeechRate", rate);
    notifyListeners();
  }

  Future<void> setTTSPitch(double pitch) async {
    ttsPitch = pitch;
    await prefs.setDouble("ttsPitch", pitch);
    notifyListeners();
  }

  Future<void> setPronunciationMode(PronunciationMode mode) async {
    pronunciationMode = mode;
    await prefs.setString("pronunciationMode", mode.name);
    notifyListeners();
  }

  Future<void> setWiktionaryPronunciationEnabled(bool value) async {
    wiktionaryPronunciationEnabled = value;
    await prefs.setBool("wiktionaryPronunciationEnabled", value);
    notifyListeners();
  }

  Future<void> setForvoPronunciationEnabled(bool value) async {
    forvoPronunciationEnabled = value;
    await prefs.setBool("forvoPronunciationEnabled", value);
    notifyListeners();
  }

  Future<void> setWiktionaryPronunciationLanguage(String value) async {
    wiktionaryPronunciationLanguage = value;
    await prefs.setString("wiktionaryPronunciationLanguage", value);
    notifyListeners();
  }

  Future<void> setForvoPronunciationLanguage(String value) async {
    forvoPronunciationLanguage = value;
    await prefs.setString("forvoPronunciationLanguage", value);
    notifyListeners();
  }

  Future<void> setAdvance(bool value) async {
    advance = value;
    await prefs.setBool("advance", value);
    notifyListeners();
  }

  Future<void> setEnableWebServer(bool value) async {
    enableWebServer = value;
    await prefs.setBool("enableWebServer", value);
    notifyListeners();
  }

  Future<void> setWebServerPort(int value) async {
    webServerPort = value;
    await prefs.setInt("webServerPort", value);
    notifyListeners();
  }

  Future<void> setWebServerAllowLan(bool value) async {
    webServerAllowLan = value;
    await prefs.setBool("webServerAllowLan", value);
    notifyListeners();
  }

  Future<void> setEnableHunspellMorphology(bool value) async {
    enableHunspellMorphology = value;
    await prefs.setBool("enableHunspellMorphology", value);
    notifyListeners();
  }

  Future<void> setHunspellLookupMode(HunspellLookupMode mode) async {
    hunspellLookupMode = mode;
    await prefs.setString("hunspellLookupMode", mode.name);
    notifyListeners();
  }

  Future<void> setEnableHistory(bool value) async {
    enableHistory = value;
    await prefs.setBool("enableHistory", value);
    notifyListeners();
  }

  Future<void> setTranslationProvider(String provider) async {
    translationProvider = provider;
    await prefs.setString("translationProvider", provider);
    notifyListeners();
  }

  Future<void> setDeeplxUrl(String url) async {
    deeplxUrl = url;
    await prefs.setString("deeplxUrl", url);
    notifyListeners();
  }

  Future<void> setDeeplApiKey(String? value) async {
    deeplApiKey = value;
    await prefs.setString("deeplApiKey", value ?? "");
    notifyListeners();
  }

  Future<void> setGoogleCloudApiKey(String? value) async {
    googleCloudApiKey = value;
    await prefs.setString("googleCloudApiKey", value ?? "");
    notifyListeners();
  }

  Future<void> setAzureApiKey(String? value) async {
    azureApiKey = value;
    await prefs.setString("azureApiKey", value ?? "");
    notifyListeners();
  }

  Future<void> setAzureRegion(String? value) async {
    azureRegion = value;
    await prefs.setString("azureRegion", value ?? "");
    notifyListeners();
  }

  Future<void> setYandexApiKey(String? value) async {
    yandexApiKey = value;
    await prefs.setString("yandexApiKey", value ?? "");
    notifyListeners();
  }

  Future<void> setYandexFolderId(String? value) async {
    yandexFolderId = value;
    await prefs.setString("yandexFolderId", value ?? "");
    notifyListeners();
  }

  Future<void> setRichOutput(bool value) async {
    isRichOutput = value;
    await prefs.setBool("isRichOutput", value);
    notifyListeners();
  }

  Future<void> setEnableTranslationHistory(bool value) async {
    enableTranslationHistory = value;
    await prefs.setBool("enableTranslationHistory", value);
    notifyListeners();
  }

  Future<void> setEnableWritingCheckHistory(bool value) async {
    enableWritingCheckHistory = value;
    await prefs.setBool("enableWritingCheckHistory", value);
    notifyListeners();
  }

  Future<void> setLaunchAtStartup(bool value) async {
    launchAtStartup = value;
    await prefs.setBool("launchAtStartup", value);
    notifyListeners();
  }

  Future<void> setFlashcardDailyNewLimit(int value) async {
    flashcardDailyNewLimit = value.clamp(0, 9999);
    await prefs.setInt("flashcardDailyNewLimit", flashcardDailyNewLimit);
    notifyListeners();
  }
}
