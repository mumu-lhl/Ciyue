import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  test("Linux WebView loadData does not cancel its pending load", () {
    final pubspec = File("pubspec.yaml").readAsStringSync();
    final cmake = File(
      "packages/flutter_inappwebview_linux/linux/CMakeLists.txt",
    ).readAsStringSync();
    final workflow = File(".github/workflows/linux-build.yml")
        .readAsStringSync();
    final source = File(
      "packages/flutter_inappwebview_linux/linux/in_app_webview/"
      "in_app_webview.cc",
    ).readAsStringSync();
    final loadData = source.substring(
      source.indexOf("void InAppWebView::loadData("),
      source.indexOf("void InAppWebView::loadFile("),
    );

    expect(
      pubspec,
      contains(
        "flutter_inappwebview_linux:\n"
        "    path: packages/flutter_inappwebview_linux",
      ),
    );
    expect(cmake, contains("option(FLUTTER_INAPPWEBVIEW_FORCE_LEGACY_WPE"));
    expect(cmake, contains("if(NOT FLUTTER_INAPPWEBVIEW_FORCE_LEGACY_WPE)"));
    expect(
      cmake,
      contains("if(WPE_FDO_FOUND AND FLUTTER_INAPPWEBVIEW_FORCE_LEGACY_WPE)"),
    );
    expect(loadData, isNot(contains("webkit_web_view_stop_loading")));
    expect(
      workflow,
      contains(
        'Path("packages/flutter_inappwebview_linux/linux/in_app_webview")',
      ),
    );
  });

  test("Linux custom schemes are registered once per context", () {
    final source = File(
      "packages/flutter_inappwebview_linux/linux/in_app_webview/"
      "in_app_webview.cc",
    ).readAsStringSync();

    expect(source, contains("webkit_uri_scheme_request_get_web_view(request)"));
    expect(source, contains("g_object_get_data("));
    expect(source, contains("request_web_view"));
    expect(source, contains("scheme_registered"));
    expect(source, contains("g_object_set_data(G_OBJECT(context)"));
    expect(
      source,
      contains("InAppWebView::OnCustomSchemeRequest, nullptr, nullptr"),
    );
    expect(
      source,
      contains(
        "g_object_set_data(G_OBJECT(webview_), "
        "kInAppWebViewInstanceDataKey, nullptr)",
      ),
    );
  });
}
