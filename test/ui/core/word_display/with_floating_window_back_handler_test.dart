import "package:ciyue/ui/core/word_display/utils.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

void main() {
  testWidgets(
    "withFloatingWindowBackHandler does not throw without a GoRouter ancestor",
    (tester) async {
      // The lookup popup runs a plain MaterialApp with no router; previously
      // this called context.canPop() unconditionally and threw.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) =>
                withFloatingWindowBackHandler(context, const Text("word")),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text("word"), findsOneWidget);
    },
  );

  testWidgets("withFloatingWindowBackHandler still works with a router", (
    tester,
  ) async {
    final router = GoRouter(
      routes: [GoRoute(path: "/", builder: (_, _) => const Text("word"))],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            withFloatingWindowBackHandler(context, child ?? const SizedBox()),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text("word"), findsOneWidget);
  });

  testWidgets("onPopAttempt fires when back is attempted", (tester) async {
    // The desktop popup is a second View in the same process, so the
    // process-wide floating-window flag never covers it: the explicit
    // callback is what makes "back closes" work there.
    var popped = false;
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return withFloatingWindowBackHandler(
              context,
              const Text("word"),
              onPopAttempt: () => popped = true,
            );
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await Navigator.of(captured).maybePop();
    expect(popped, isTrue);
  });
}
