import "package:ciyue/services/command_line.dart";
import "package:test/test.dart";

void main() {
  final parser = CommandLineParser();

  group("CommandLineParser.parse", () {
    test("parses a single word", () {
      final options = parser.parse(["hello"]);
      expect(options.word, "hello");
      expect(options.hasActions, isTrue);
      expect(options.hasUiActions, isTrue);
    });

    test("keeps a quoted phrase as one argument", () {
      final options = parser.parse(["break the ice"]);
      expect(options.word, "break the ice");
    });

    test("joins multiple positional arguments into a phrase", () {
      final options = parser.parse(["break", "the", "ice"]);
      expect(options.word, "break the ice");
    });

    test("stops option parsing after --", () {
      final options = parser.parse(["--", "--word"]);
      expect(options.word, "--word");
    });

    test("parses option values before the word", () {
      final options = parser.parse(["-g", "Default", "hello"]);
      expect(options.groupName, "Default");
      expect(options.effectiveGroupName, "Default");
      expect(options.word, "hello");
    });

    test("maps the popup group onto the effective group", () {
      final options = parser.parse(["--popup-group-name", "Popup"]);
      expect(options.groupName, isNull);
      expect(options.popupGroupName, "Popup");
      expect(options.effectiveGroupName, "Popup");
    });

    test("prefers the main group over the popup group", () {
      final options = parser.parse([
        "--group-name",
        "Main",
        "--popup-group-name",
        "Popup",
      ]);
      expect(options.effectiveGroupName, "Main");
    });

    test("maps popup and main window flags", () {
      expect(parser.parse(["-s"]).window, "popup");
      expect(parser.parse(["--popup"]).window, "popup");
      expect(parser.parse(["--main-window"]).window, "main");
      expect(parser.parse(["-m"]).window, "main");
    });

    test("parses boolean flags", () {
      final options = parser.parse([
        "--log-to-file",
        "--no-tts",
        "--reset-window-state",
        "--toggle-popup",
      ]);
      expect(options.logToFile, isTrue);
      expect(options.noTts, isTrue);
      expect(options.resetWindowState, isTrue);
      expect(options.togglePopup, isTrue);
      expect(options.hasUiActions, isTrue);
    });

    test("parses help and version", () {
      expect(parser.parse(["--help"]).showHelp, isTrue);
      expect(parser.parse(["-h"]).showHelp, isTrue);
      expect(parser.parse(["--version"]).showVersion, isTrue);
      expect(parser.parse(["-v"]).showVersion, isTrue);
      expect(parser.parse(["--help"]).isInformational, isTrue);
    });

    test("rejects unknown options", () {
      expect(
        () => parser.parse(["--nope"]),
        throwsA(isA<CommandLineException>()),
      );
    });

    test("parses a URL passed as a positional argument", () {
      final options = parser.parse(["ciyue://query?word=hello&group=Default"]);
      expect(options.word, "hello");
      expect(options.groupName, "Default");
    });
  });

  group("CommandLineParser.parseUrl", () {
    test("parses ciyue://query", () {
      final options = parser.parseUrl(
        Uri.parse("ciyue://query?word=hello&group=Default"),
      );
      expect(options?.word, "hello");
      expect(options?.groupName, "Default");
    });

    test("parses ciyue://word/path", () {
      final options = parser.parseUrl(Uri.parse("ciyue://word/hello%20world"));
      expect(options?.word, "hello world");
    });

    test("parses ciyue://word as host", () {
      final options = parser.parseUrl(Uri.parse("ciyue://hello%20world"));
      expect(options?.word, "hello world");
    });

    test("parses q and popup-group aliases", () {
      final options = parser.parseUrl(
        Uri.parse("ciyue://query?q=hello&popup-group=Popup"),
      );
      expect(options?.word, "hello");
      expect(options?.popupGroupName, "Popup");
    });

    test("returns null for other schemes", () {
      expect(parser.parseUrl(Uri.parse("https://example.com")), isNull);
    });
  });

  group("CommandLineOptions", () {
    test("round-trips through JSON", () {
      const options = CommandLineOptions(
        word: "break the ice",
        groupName: "Default",
        popupGroupName: "Popup",
        window: "main",
        logToFile: true,
        noTts: true,
        resetWindowState: true,
        togglePopup: true,
        showHelp: true,
        showVersion: true,
      );

      final restored = CommandLineOptions.fromJson(options.toJson());
      expect(restored.word, options.word);
      expect(restored.groupName, options.groupName);
      expect(restored.popupGroupName, options.popupGroupName);
      expect(restored.window, options.window);
      expect(restored.logToFile, options.logToFile);
      expect(restored.noTts, options.noTts);
      expect(restored.resetWindowState, options.resetWindowState);
      expect(restored.togglePopup, options.togglePopup);
      expect(restored.showHelp, options.showHelp);
      expect(restored.showVersion, options.showVersion);
      expect(restored.effectiveGroupName, options.effectiveGroupName);
    });

    test("hasUiActions ignores main-only flags", () {
      expect(const CommandLineOptions().hasUiActions, isFalse);
      expect(const CommandLineOptions(logToFile: true).hasUiActions, isFalse);
      expect(const CommandLineOptions(noTts: true).hasUiActions, isFalse);
      expect(
        const CommandLineOptions(resetWindowState: true).hasUiActions,
        isTrue,
      );
      expect(const CommandLineOptions(togglePopup: true).hasUiActions, isTrue);
    });
  });
}
