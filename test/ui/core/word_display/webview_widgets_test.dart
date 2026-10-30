import "dart:convert";

import "package:ciyue/ui/core/word_display/entry_anchor.dart";
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

  test("Windows content reload POSTs the same body as the initial load", () {
    const content = "<html><body>café &amp; naïve</body></html>";
    const url = "http://127.0.0.1:42433/";

    final request = windowsContentPostRequest(content, url);

    expect(request.url.toString(), url);
    expect(request.method, "POST");
    expect(request.body, windowsContentPostBody(content));
    final decoded = json.decode(utf8.decode(request.body!)) as Map;
    expect(decoded, {"content": content});
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

  test("a sound reference keeps its folder inside one path segment", () {
    // OJAD's recordings sit under `female/` and `male/` inside res.zip, so the
    // file name itself carries a separator. It has to survive as a single path
    // segment: a raw `/` would read as a path boundary, and the host the old
    // shape put it in would have folded the name to lower case before the file
    // was ever looked up.
    final html = normalizeDictionaryUrls(
      '<a href="sound://female/2830_1_1_female.spx"></a>',
    );

    final encoded = RegExp(r'sound://localhost/([^"]+)"')
        .firstMatch(html)!
        .group(1)!;
    expect(encoded, isNot(contains("/")));
    expect(Uri.decodeComponent(encoded), "female/2830_1_1_female.spx");
  });

  group("linked words survive the URL container", () {
    test("the encoded path decodes back to the original word", () {
      expect(
        wordFromEntryUrl(WebUri("gdlookup://localhost/%41%62%65%6E%64")).word,
        "Abend",
      );
      expect(
        wordFromEntryUrl(WebUri("gdlookup://localhost/%41%2E%44%2E")).word,
        "A.D.",
      );
      expect(
        wordFromEntryUrl(WebUri("gdlookup://localhost/%40smk8-000001-0001"))
            .word,
        "@smk8-000001-0001",
      );
      expect(
        wordFromEntryUrl(
          WebUri("gdlookup://localhost/%74%61%67%3A%73%75%6D%65%72%75"),
        ).word,
        "tag:sumeru",
      );
      expect(
        wordFromEntryUrl(WebUri("gdlookup://localhost/a%2Fb")).word,
        "a/b",
      );
    });

    test("legacy entry and bword links still resolve", () {
      // Lower case only: a host is folded, which is the reason words moved into
      // the path in the first place.
      expect(wordFromEntryUrl(WebUri("entry://abend")).word, "abend");
      expect(wordFromEntryUrl(WebUri("bword://abend")).word, "abend");
    });

    test("new-tab links keep their word", () {
      expect(
        wordFromEntryUrl(WebUri("ciyue-open-new-tab://haus")).word,
        "haus",
      );
    });
  });

  group("anchors", () {
    test("a gdanchor query item is read next to the headword", () {
      final target = wordFromEntryUrl(
        WebUri("gdlookup://localhost/%74%61%67?gdanchor=%73%75%6D%65%72%75"),
      );
      expect(target.word, "tag");
      expect(target.anchor, "sumeru");
    });

    test("a legacy entry link splits at a single hash", () {
      final target = wordFromEntryUrl(WebUri("entry://tag#sumeru"));
      expect(target.word, "tag");
      expect(target.anchor, "sumeru");
    });

    test("a doubled hash stays a literal hash in the headword", () {
      final target = wordFromEntryUrl(WebUri("entry://tag##sumeru"));
      expect(target.word, "tag#sumeru");
      expect(target.anchor, isNull);
    });

    test("a link without an anchor carries none", () {
      expect(
        wordFromEntryUrl(WebUri("gdlookup://localhost/tag")).anchor,
        isNull,
      );
    });
  });

  group("entryLinkHref", () {
    test("puts the word in the path and the anchor in the query", () {
      final href = entryLinkHref(
        const EntryLinkTarget(word: "tag", anchor: "sumeru"),
      );
      final uri = WebUri(href);
      expect(uri.scheme, "gdlookup");
      expect(Uri.decodeComponent(uri.path.substring(1)), "tag");
      expect(uri.queryParameters["gdanchor"], "sumeru");
    });

    test("keeps a literal hash escaped in the headword", () {
      final href = entryLinkHref(const EntryLinkTarget(word: "tag#sumeru"));
      expect(href, isNot(contains("#")));
      expect(Uri.decodeComponent(WebUri(href).path.substring(1)), "tag#sumeru");
    });

    test("returns nothing when there is no word", () {
      expect(entryLinkHref(const EntryLinkTarget(word: "", anchor: "foo")), "");
    });
  });
}
