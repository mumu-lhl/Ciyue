import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("theme script marks a dark app theme at document start", () {
    final scripts = dictionaryUserScripts(isDarkTheme: true);
    final theme = scripts.firstWhere((s) => s.source.contains("ciyue-dark"));
    expect(theme.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
    expect(theme.source, contains("var dark = true"));
    expect(theme.source, contains('classList.toggle("ciyue-dark", dark)'));
  });

  test("theme script marks a light app theme by default", () {
    final scripts = dictionaryUserScripts();
    final theme = scripts.firstWhere((s) => s.source.contains("ciyue-dark"));
    expect(theme.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
    expect(theme.source, contains("var dark = false"));
  });
}
