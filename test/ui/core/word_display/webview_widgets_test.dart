import "package:ciyue/ui/core/word_display/entry_link_script.dart";
import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";

void main() {
  test("dictionary link normalization runs at document start", () {
    final scripts = dictionaryUserScripts();
    final linkScript = scripts.singleWhere(
      (script) => script.source == dictionaryEntryLinkScript,
    );
    expect(linkScript.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
  });

  test("Dark Reader activates on Windows and Linux dark mode", () {
    for (final isWindows in [true, false]) {
      expect(
        shouldUseDarkReaderForDictionary(
          isWindows: isWindows,
          isLinux: !isWindows,
          isLightTheme: false,
          enabled: true,
          hasCustomBackground: false,
        ),
        isTrue,
      );
    }
    expect(
      shouldUseDarkReaderForDictionary(
        isWindows: true,
        isLinux: false,
        isLightTheme: false,
        enabled: true,
        hasCustomBackground: true,
      ),
      isFalse,
    );
    expect(
      shouldUseDarkReaderForDictionary(
        isWindows: false,
        isLinux: false,
        isLightTheme: false,
        enabled: true,
        hasCustomBackground: false,
      ),
      isFalse,
    );
  });

  test("Dark Reader remains off unless explicitly enabled", () {
    final scripts = dictionaryUserScripts(
      darkReaderSource: "window.DarkReader = {};",
    );

    // Resource normalisation + link normalisation + app theme marker; Dark
    // Reader stays off.
    expect(scripts, hasLength(3));
    expect(
      scripts.every((script) => !script.source.contains("DarkReader.enable")),
      isTrue,
    );
  });

  test("Dark Reader initialization is injected at document end", () {
    final script = dictionaryUserScripts(
      enableDarkReader: true,
      darkReaderSource: "window.DarkReader = { enable: function() {} };",
    ).last;

    expect(script.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_END);
    expect(script.source, contains("darkReader.enable({"));
    expect(script.source, contains("mode: 1"));
  });

  test("dark Windows mode uses a readable default dictionary background", () {
    expect(
      resolveDictionaryBackgroundColor(
        isWindows: true,
        isLightTheme: false,
        customColor: null,
      ),
      Colors.white,
    );
  });

  test("Dark Reader takes over the automatic Windows background", () {
    expect(
      resolveDictionaryBackgroundColor(
        isWindows: true,
        isLightTheme: false,
        customColor: null,
        darkReaderEnabled: true,
      ),
      isNull,
    );
  });

  test("custom dictionary background takes precedence over the fallback", () {
    const customColor = Color(0xFFF5F0E6);

    expect(
      resolveDictionaryBackgroundColor(
        isWindows: true,
        isLightTheme: false,
        customColor: customColor,
      ),
      customColor,
    );
  });

  test("other themes do not get an automatic background", () {
    expect(
      resolveDictionaryBackgroundColor(
        isWindows: true,
        isLightTheme: true,
        customColor: null,
      ),
      isNull,
    );
    expect(
      resolveDictionaryBackgroundColor(
        isWindows: false,
        isLightTheme: false,
        customColor: null,
      ),
      isNull,
    );
  });

  test("custom dictionary styles are injected at document end", () {
    final script = dictionaryUserScripts(
      customCss: "body { color: red; }",
      background: const Color(0xFFF5F0E6),
    ).last;

    expect(script.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_END);
    expect(script.source, contains("#f5f0e6"));
    expect(script.source, contains("body { color: red; }"));
  });

  test("Linux WebView defers HTML loading until its controller is ready", () {
    const content = "<html><body>word</body></html>";
    const url = "http://127.0.0.1:42433/";

    final load = desktopWebViewLoad(content, url);

    expect(load.initialData, isNull);
    expect(load.deferredData.data, content);
    expect(load.deferredData.baseUrl.toString(), url);
  });

  test("regular WebView navigation is allowed", () {
    expect(
      navigationPolicyForUrl(WebUri("http://127.0.0.1:42433/")),
      NavigationActionPolicy.ALLOW,
    );
    for (final handled in [
      "entry://word",
      "gdlookup://localhost/word",
      "bword://word",
      "sound://word.mp3",
    ]) {
      expect(
        navigationPolicyForUrl(WebUri(handled)),
        NavigationActionPolicy.CANCEL,
        reason: handled,
      );
    }
  });

  group("linked words survive the URL container", () {
    test("the encoded path decodes back to the original word", () {
      expect(
        wordFromEntryUrl(WebUri("gdlookup://localhost/%41%62%65%6E%64")),
        "Abend",
      );
      expect(
        wordFromEntryUrl(WebUri("gdlookup://localhost/%41%2E%44%2E")),
        "A.D.",
      );
      expect(
        wordFromEntryUrl(WebUri("gdlookup://localhost/%40smk8-000001-0001")),
        "@smk8-000001-0001",
      );
      expect(
        wordFromEntryUrl(
          WebUri("gdlookup://localhost/%74%61%67%3A%73%75%6D%65%72%75"),
        ),
        "tag:sumeru",
      );
      expect(wordFromEntryUrl(WebUri("gdlookup://localhost/a%2Fb")), "a/b");
    });

    test("legacy entry and bword links still resolve", () {
      // Lower case only: a host is folded, which is the reason words moved into
      // the path in the first place.
      expect(wordFromEntryUrl(WebUri("entry://abend")), "abend");
      expect(wordFromEntryUrl(WebUri("bword://abend")), "abend");
    });

    test("new-tab links keep their word", () {
      expect(wordFromEntryUrl(WebUri("ciyue-open-new-tab://haus")), "haus");
    });
  });
}
