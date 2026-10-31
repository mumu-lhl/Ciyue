import "package:args/args.dart";

/// Options parsed from the desktop command line or from a `ciyue://` URL.
///
/// PC builds have no popup window, so the goldendict popup options are
/// accepted for script compatibility and mapped onto the main window; see
/// [effectiveGroupName] and [window].
class CommandLineOptions {
  const CommandLineOptions({
    this.word,
    this.groupName,
    this.popupGroupName,
    this.window,
    this.logToFile = false,
    this.noTts = false,
    this.resetWindowState = false,
    this.togglePopup = false,
    this.showHelp = false,
    this.showVersion = false,
  });

  /// The word or phrase to look up.
  ///
  /// Positional arguments are joined with spaces, so `ciyue break the ice`
  /// and `ciyue "break the ice"` both query the phrase. Put `--` before the
  /// word to look up an entry that itself starts with a dash.
  final String? word;

  /// Dictionary group to switch to before the lookup.
  final String? groupName;

  /// goldendict's popup group option. PC builds have no popup window, so
  /// [effectiveGroupName] falls back to it when [groupName] is absent.
  final String? popupGroupName;

  /// Requested target window: `main` or `popup`.
  ///
  /// PC builds map both to the main window. The field is kept so the message
  /// forwarded to a running instance and future popup support stay
  /// compatible.
  final String? window;

  final bool logToFile;
  final bool noTts;
  final bool resetWindowState;
  final bool togglePopup;
  final bool showHelp;
  final bool showVersion;

  /// PC builds have no popup window, so the popup group acts as the main
  /// group.
  String? get effectiveGroupName => groupName ?? popupGroupName;

  /// Whether startup should print information and exit instead of showing
  /// the GUI.
  bool get isInformational => showHelp || showVersion;

  /// Whether the options ask the app to do something after startup.
  bool get hasActions =>
      word != null ||
      effectiveGroupName != null ||
      logToFile ||
      noTts ||
      resetWindowState ||
      togglePopup;

  /// Whether the options need the mounted UI (router/window), as opposed to
  /// work `main` can do before `runApp`.
  bool get hasUiActions =>
      word != null ||
      effectiveGroupName != null ||
      resetWindowState ||
      togglePopup ||
      window != null;

  Map<String, Object?> toJson() => {
    "word": word,
    "groupName": groupName,
    "popupGroupName": popupGroupName,
    "window": window,
    "logToFile": logToFile,
    "noTts": noTts,
    "resetWindowState": resetWindowState,
    "togglePopup": togglePopup,
    "showHelp": showHelp,
    "showVersion": showVersion,
  };

  factory CommandLineOptions.fromJson(Map<String, Object?> json) {
    return CommandLineOptions(
      word: json["word"] as String?,
      groupName: json["groupName"] as String?,
      popupGroupName: json["popupGroupName"] as String?,
      window: json["window"] as String?,
      logToFile: json["logToFile"] as bool? ?? false,
      noTts: json["noTts"] as bool? ?? false,
      resetWindowState: json["resetWindowState"] as bool? ?? false,
      togglePopup: json["togglePopup"] as bool? ?? false,
      showHelp: json["showHelp"] as bool? ?? false,
      showVersion: json["showVersion"] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return "CommandLineOptions(word: $word, group: $effectiveGroupName, "
        "window: $window, logToFile: $logToFile, noTts: $noTts, "
        "resetWindowState: $resetWindowState, togglePopup: $togglePopup)";
  }
}

/// Thrown when the command line cannot be parsed.
class CommandLineException implements Exception {
  const CommandLineException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Parses desktop arguments and `ciyue://` URLs into [CommandLineOptions].
class CommandLineParser {
  CommandLineParser();

  final ArgParser _parser = _buildParser();

  /// The underlying parser, exposed so callers can print the usage text.
  ArgParser get parser => _parser;

  String get usage => _parser.usage;

  /// Parses [arguments], which must not include the executable name.
  CommandLineOptions parse(List<String> arguments) {
    final ArgResults results;
    try {
      results = _parser.parse(arguments);
    } on FormatException catch (error) {
      throw CommandLineException(error.message);
    }

    var word = _joinPositional(results.rest);
    var groupName = results.option("group-name");
    var popupGroupName = results.option("popup-group-name");

    String? window;
    if (results.flag("scanpopup") || results.flag("popup")) {
      window = "popup";
    }
    if (results.flag("main-window")) {
      window = "main";
    }

    // A URL scheme handler receives the whole `ciyue://...` link as a single
    // positional argument. Fold it into the same option object.
    if (word != null) {
      final uri = Uri.tryParse(word);
      if (uri != null && uri.scheme == "ciyue") {
        final urlOptions = parseUrl(uri);
        if (urlOptions != null) {
          word = urlOptions.word;
          groupName = urlOptions.groupName ?? groupName;
          popupGroupName = urlOptions.popupGroupName ?? popupGroupName;
          window = urlOptions.window ?? window;
        }
      }
    }

    return CommandLineOptions(
      word: _emptyToNull(word),
      groupName: _emptyToNull(groupName),
      popupGroupName: _emptyToNull(popupGroupName),
      window: window,
      logToFile: results.flag("log-to-file"),
      noTts: results.flag("no-tts"),
      resetWindowState: results.flag("reset-window-state"),
      togglePopup: results.flag("toggle-popup"),
      showHelp: results.flag("help"),
      showVersion: results.flag("version"),
    );
  }

  /// Parses a `ciyue://` URL.
  ///
  /// Supported forms:
  /// - `ciyue://query?word=hello&group=Default`
  /// - `ciyue://query?q=hello&popup-group=Default`
  /// - `ciyue://word/hello%20world`
  /// - `ciyue://hello%20world`
  CommandLineOptions? parseUrl(Uri uri) {
    if (uri.scheme != "ciyue") {
      return null;
    }

    final params = uri.queryParameters;
    final host = uri.host;
    final segments = uri.pathSegments;

    final groupName = params["group"] ?? params["group-name"];
    final popupGroupName = params["popup-group"] ?? params["popup-group-name"];

    String? word;
    if (host == "query" || host.isEmpty) {
      word = params["word"] ?? params["q"];
      if (word == null && segments.isNotEmpty) {
        word = segments.join("/");
      }
    } else if (host == "word") {
      word = segments.isNotEmpty ? segments.join("/") : params["word"];
    } else {
      // `Uri.host` keeps percent-encoding for non-standard hosts such as
      // `ciyue://hello%20world`, so decode it explicitly.
      word = _decodeHost(host);
    }

    return CommandLineOptions(
      word: _emptyToNull(word),
      groupName: _emptyToNull(groupName),
      popupGroupName: _emptyToNull(popupGroupName),
    );
  }

  static ArgParser _buildParser() {
    return ArgParser()
      ..addFlag(
        "help",
        abbr: "h",
        negatable: false,
        help: "Print this help and exit.",
      )
      ..addFlag(
        "version",
        abbr: "v",
        negatable: false,
        help: "Print version information and exit.",
      )
      ..addFlag(
        "log-to-file",
        abbr: "l",
        negatable: false,
        help: "Write debug messages to a log file in the app data directory.",
      )
      ..addFlag(
        "reset-window-state",
        abbr: "r",
        negatable: false,
        help: "Reset the main window size and position.",
      )
      ..addFlag("no-tts", negatable: false, help: "Disable text-to-speech.")
      ..addOption(
        "group-name",
        abbr: "g",
        valueHelp: "name",
        help: "Switch the main window to the named dictionary group.",
      )
      ..addOption(
        "popup-group-name",
        abbr: "p",
        valueHelp: "name",
        help: "Accepted for goldendict compatibility; maps to --group-name.",
      )
      ..addFlag(
        "scanpopup",
        abbr: "s",
        negatable: false,
        help: "Accepted for goldendict compatibility; maps to the main window.",
      )
      ..addFlag(
        "popup",
        negatable: false,
        help: "Accepted for goldendict compatibility; maps to the main window.",
      )
      ..addFlag(
        "main-window",
        abbr: "m",
        negatable: false,
        help: "Look the word up in the main window (the default).",
      )
      ..addFlag(
        "toggle-popup",
        abbr: "t",
        negatable: false,
        help: "Accepted for goldendict compatibility; toggles the main window.",
      );
  }

  static String? _joinPositional(List<String> rest) {
    if (rest.isEmpty) {
      return null;
    }
    final joined = rest.join(" ").trim();
    return joined.isEmpty ? null : joined;
  }

  static String _decodeHost(String host) {
    try {
      return Uri.decodeComponent(host);
    } catch (_) {
      return host;
    }
  }

  static String? _emptyToNull(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
