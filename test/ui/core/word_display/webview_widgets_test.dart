import "package:ciyue/ui/core/word_display/entry_link_script.dart";
import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";

void main() {
  test("dictionary link normalization runs at document start", () {
    final script = dictionaryUserScripts().single;
    expect(script.source, dictionaryEntryLinkScript);
    expect(script.injectionTime, UserScriptInjectionTime.AT_DOCUMENT_START);
  });

  test(
    "Dark Reader activates only for Windows dark mode without custom bg",
    () {
      expect(
        shouldUseDarkReaderForDictionary(
          isWindows: true,
          isLightTheme: false,
          enabled: true,
          hasCustomBackground: false,
        ),
        isTrue,
      );
      expect(
        shouldUseDarkReaderForDictionary(
          isWindows: true,
          isLightTheme: false,
          enabled: true,
          hasCustomBackground: true,
        ),
        isFalse,
      );
      expect(
        shouldUseDarkReaderForDictionary(
          isWindows: false,
          isLightTheme: false,
          enabled: true,
          hasCustomBackground: false,
        ),
        isFalse,
      );
    },
  );

  test("Dark Reader remains off unless explicitly enabled", () {
    final scripts = dictionaryUserScripts(
      darkReaderSource: "window.DarkReader = {};",
    );

    expect(scripts, hasLength(1));
    expect(scripts.single.source, isNot(contains("DarkReader.enable")));
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
    expect(
      navigationPolicyForUrl(WebUri("entry://word")),
      NavigationActionPolicy.CANCEL,
    );
    expect(
      navigationPolicyForUrl(WebUri("sound://word.mp3")),
      NavigationActionPolicy.CANCEL,
    );
  });
}
