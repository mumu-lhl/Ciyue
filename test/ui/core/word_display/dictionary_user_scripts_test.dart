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

  test("font fallback is injected at document start", () {
    final scripts = dictionaryUserScripts();
    final fallback = scripts.firstWhere(
      (script) => script.source.contains("var fallback ="),
    );
    expect(fallback.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
    expect(fallback.source, contains("DejaVu Sans"));
    expect(fallback.source, contains("Noto Sans"));
    expect(fallback.source, contains("getPropertyValue(\"font-family\")"));
  });

  test(
    "desktop text selection fallback is injected only with the app menu",
    () {
      final withMenu = dictionaryUserScripts(desktopContextMenu: true);
      final selection = withMenu.firstWhere(
        (script) => script.source.contains("var mouseLongPressTimer"),
      );

      expect(
        selection.injectionTime,
        UserScriptInjectionTime.AT_DOCUMENT_START,
      );
      expect(selection.source, contains("document.caretRangeFromPoint"));
      expect(selection.source, contains("e.button === 0"));
      expect(selection.source, contains("touchLongPressTimer"));
      expect(selection.source, contains("touchLongPressFired"));
      expect(
        selection.source,
        contains("window.__ciyueTextSelectionInstalled"),
      );
      expect(selection.source, contains("passive: false"));
      expect(selection.source, contains("'DesktopContextMenu'"));

      final withoutMenu = dictionaryUserScripts();
      expect(
        withoutMenu.any(
          (script) => script.source.contains("var mouseLongPressTimer"),
        ),
        isFalse,
      );
    },
  );

  test("the paging script is injected and starts inert", () {
    final scripts = dictionaryUserScripts();
    final paging = scripts.firstWhere(
      (script) => script.source.contains("window.ciyuePageBy"),
    );
    // Injected from the start so the mode can be switched on while the entry
    // is already open; it does nothing until `ciyueSetPaging(true)`.
    expect(paging.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
    expect(paging.source, contains("window.ciyuePagingEnabled = false"));
    expect(paging.source, contains("window.ciyueSetPaging = function"));
  });

  test("theme script hands MediaWiki skins the app theme", () {
    final scripts = dictionaryUserScripts(isDarkTheme: true);
    final theme = scripts.firstWhere((s) => s.source.contains("ciyue-dark"));
    expect(theme.source, contains('"skin-theme-clientpref-night"'));
    expect(theme.source, contains('"skin-theme-clientpref-os"'));
    // Light is the skin default, so both classes are removed instead of
    // handing out `-os`, which would keep following the system theme.
    expect(theme.source, contains("root.classList.remove(unwanted[i])"));
    // The parser may set the class after the script runs.
    expect(
      theme.source,
      contains('document.addEventListener("DOMContentLoaded", apply'),
    );
  });
}
