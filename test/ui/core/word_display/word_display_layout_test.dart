import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  testWidgets("desktop webviews are bounded in expanded panels", (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();

    const dictIds = [1, 2];
    for (final id in dictIds) {
      dictManager.dicts[id] = Mdict(path: "unused_$id")
        ..id = id
        ..title = "dict $id"
        ..port = 1;
    }
    InAppWebViewPlatform.instance = _FakeInAppWebViewPlatform();
    addTearDown(() {
      for (final id in dictIds) {
        dictManager.dicts.remove(id);
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SingleChildScrollView(
            child: ExpansionPanelList(
              children: [
                for (final id in dictIds)
                  ExpansionPanel(
                    isExpanded: true,
                    headerBuilder: (_, _) => ListTile(title: Text("dict $id")),
                    body: WebviewWindows(
                      key: ValueKey("desktop_webview_$id"),
                      content: "",
                      dictId: id,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (final id in dictIds) {
      final boundedWebView = find.descendant(
        of: find.byKey(ValueKey("desktop_webview_$id")),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox && widget.constraints.maxHeight.isFinite,
        ),
      );
      expect(boundedWebView, findsOneWidget);
      expect(tester.getSize(boundedWebView).height, lessThan(double.infinity));
    }
  });
}

class _FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    return _FakeInAppWebViewWidget(params);
  }
}

class _FakeInAppWebViewWidget extends PlatformInAppWebViewWidget {
  // The platform interface exposes only a named implementation constructor.
  // ignore: use_super_parameters
  _FakeInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams params)
    : super.implementation(params);

  @override
  Widget build(BuildContext context) => SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) {
    throw UnimplementedError();
  }

  @override
  void dispose() {}
}
