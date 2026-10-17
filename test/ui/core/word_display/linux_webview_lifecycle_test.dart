import "dart:async";

import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

class _FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  int created = 0;
  int disposed = 0;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    created++;
    return _FakeInAppWebViewWidget(params, this);
  }
}

class _FakeInAppWebViewWidget extends PlatformInAppWebViewWidget {
  final _FakeInAppWebViewPlatform owner;

  // ignore: use_super_parameters
  _FakeInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
    this.owner,
  ) : super.implementation(params);

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) {
    throw UnimplementedError();
  }

  @override
  void dispose() => owner.disposed++;
}

void main() {
  final fakePlatform = _FakeInAppWebViewPlatform();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
    InAppWebViewPlatform.instance = fakePlatform;
  });

  setUp(() {
    fakePlatform
      ..created = 0
      ..disposed = 0;
    dictManager.dicts[1] = Mdict(path: "unused")..port = 42433;
  });

  tearDown(() => dictManager.dicts.remove(1));

  testWidgets("keeps Linux WebView mounted while the next entry loads", (
    tester,
  ) async {
    final nextContent = Completer<String>();
    var word = "first";
    late StateSetter setWord;

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          wordContentProvider.overrideWith((ref, params) {
            return params.word == "first"
                ? Future<String>.value("<p>first entry</p>")
                : nextContent.future;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                setWord = update;
                return buildWebView(word, 1, false);
              },
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(WebviewWindows), findsOneWidget);
    expect(fakePlatform.created, 1);

    setWord(() => word = "second");
    await tester.pump();

    expect(find.byType(WebviewWindows), findsOneWidget);
    expect(fakePlatform.disposed, 0);
    expect(
      tester.widget<WebviewWindows>(find.byType(WebviewWindows)).content,
      "<p>first entry</p>",
    );

    nextContent.complete("<p>second entry</p>");
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(WebviewWindows), findsOneWidget);
    expect(fakePlatform.disposed, 0);
    expect(
      tester.widget<WebviewWindows>(find.byType(WebviewWindows)).content,
      "<p>second entry</p>",
    );
  });
}
