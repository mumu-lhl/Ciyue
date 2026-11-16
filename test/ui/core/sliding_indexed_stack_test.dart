import "package:ciyue/ui/core/sliding_indexed_stack.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

class _Host extends StatefulWidget {
  const _Host({super.key, required this.pages, this.disableAnimations = false});

  final List<Widget> pages;
  final bool disableAnimations;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var index = 0;

  void setIndex(int value) => setState(() => index = value);

  @override
  Widget build(BuildContext context) {
    final stack = SlidingIndexedStack(index: index, children: widget.pages);
    if (!widget.disableAnimations) {
      return stack;
    }
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: stack,
    );
  }
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Count $count"),
        TextButton(
          onPressed: () => setState(() => count++),
          child: const Text("Increment"),
        ),
      ],
    );
  }
}

Widget _page(String label, {Widget? body}) {
  return Container(
    color: Colors.white,
    alignment: Alignment.topLeft,
    child: body ?? Text(label),
  );
}

void main() {
  Future<void> setSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<_HostState> pumpHost(
    WidgetTester tester, {
    List<Widget>? pages,
    bool disableAnimations = false,
  }) async {
    await setSurface(tester);
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          key: key,
          pages: pages ?? [_page("Page 0"), _page("Page 1"), _page("Page 2")],
          disableAnimations: disableAnimations,
        ),
      ),
    );
    return key.currentState!;
  }

  testWidgets("shows the initial page and keeps the others offstage", (
    tester,
  ) async {
    await pumpHost(tester);

    expect(find.text("Page 0"), findsOneWidget);
    expect(find.text("Page 1"), findsNothing);
    expect(find.text("Page 1", skipOffstage: false), findsOneWidget);
    expect(find.text("Page 2", skipOffstage: false), findsOneWidget);
    expect(tester.getTopLeft(find.text("Page 0")), Offset.zero);
  });

  testWidgets("switching forward slides the new page in from the right", (
    tester,
  ) async {
    final host = await pumpHost(tester);

    host.setIndex(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final incomingLeft = tester.getTopLeft(find.text("Page 1")).dx;
    final outgoingLeft = tester.getTopLeft(find.text("Page 0")).dx;
    expect(incomingLeft, greaterThan(0));
    expect(incomingLeft, lessThan(400));
    expect(outgoingLeft, lessThan(0));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text("Page 1")), Offset.zero);
    expect(find.text("Page 0"), findsNothing);
  });

  testWidgets("switching back slides the new page in from the left", (
    tester,
  ) async {
    final host = await pumpHost(tester);
    host.setIndex(1);
    await tester.pump();
    await tester.pumpAndSettle();

    host.setIndex(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final incomingLeft = tester.getTopLeft(find.text("Page 0")).dx;
    final outgoingLeft = tester.getTopLeft(find.text("Page 1")).dx;
    expect(incomingLeft, lessThan(0));
    expect(outgoingLeft, greaterThan(0));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text("Page 0")), Offset.zero);
  });

  testWidgets("switching forward slides in from the left in RTL locales", (
    tester,
  ) async {
    await setSurface(tester);
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: _Host(key: key, pages: [_page("Page 0"), _page("Page 1")]),
        ),
      ),
    );
    final host = key.currentState!;

    host.setIndex(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.getTopLeft(find.text("Page 1")).dx, lessThan(0));
    expect(tester.getTopLeft(find.text("Page 0")).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text("Page 1")), Offset.zero);
  });

  testWidgets("switches instantly when animations are disabled", (
    tester,
  ) async {
    final host = await pumpHost(tester, disableAnimations: true);

    host.setIndex(1);
    await tester.pump();
    await tester.pump();

    expect(tester.getTopLeft(find.text("Page 1")), Offset.zero);
    expect(find.text("Page 0"), findsNothing);
  });

  testWidgets("a switch mid-animation lands on the latest index", (
    tester,
  ) async {
    final host = await pumpHost(tester);

    host.setIndex(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    host.setIndex(2);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text("Page 2")), Offset.zero);
    expect(find.text("Page 0"), findsNothing);
    expect(find.text("Page 1"), findsNothing);
  });

  testWidgets("keeps page state across switches", (tester) async {
    final host = await pumpHost(
      tester,
      pages: [
        _page("Page 0", body: const _Counter()),
        _page("Page 1"),
      ],
    );

    await tester.tap(find.text("Increment"));
    await tester.pump();
    expect(find.text("Count 1"), findsOneWidget);

    host.setIndex(1);
    await tester.pump();
    await tester.pumpAndSettle();
    host.setIndex(0);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text("Count 1"), findsOneWidget);
  });
}
