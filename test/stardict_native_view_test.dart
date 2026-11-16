import "dart:convert";
import "dart:typed_data";

import "package:ciyue/ui/core/word_display/stardict_native_view.dart";
import "package:dict_reader/dict_reader.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";

/// A 20x10 two-tone PNG.
///
/// Smaller than any cap, so its rendered size can only change when the zoom is
/// applied to the picture itself.
final _testPng = base64Decode(
  "iVBORw0KGgoAAAANSUhEUgAAABQAAAAKCAIAAAA7N+mxAAAAH0lEQVR42mOQs1mAjL6uEkFG"
  "+GUZRqJmklSjyY5EzQAFgwukVtaujgAAAABJRU5ErkJggg==",
);

void main() {
  Future<void> pumpEntries(
    WidgetTester tester,
    List<StardictNativeEntry> entries, {
    Future<Uint8List?> Function(String file)? resourceResolver,
    double scale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StardictEntryListView(
            entries: entries,
            resourceDirectory: "/nonexistent",
            dictId: 1,
            isExpansion: true,
            resourceResolver: resourceResolver,
            scale: scale,
          ),
        ),
      ),
    );
  }

  /// Decodes the picture, if any, so it has a size to assert on.
  ///
  /// Widget tests do not decode images on their own: the [Image] stays 0x0
  /// until its provider is resolved for real, which silently turns every size
  /// assertion into "0 == 0".
  Future<void> settleImage(WidgetTester tester) async {
    // The picture arrives through a FutureBuilder, so let that future land
    // before looking for the widget.
    await tester.pumpAndSettle();
    final finder = find.byType(Image);
    if (finder.evaluate().isEmpty) return;
    final provider = tester.widget<Image>(finder).image;
    await tester.runAsync(
      () => precacheImage(provider, tester.element(finder)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("renders an XDXF article natively", (tester) async {
    await pumpEntries(tester, [
      StardictNativeEntry(
        headword: "apple",
        fields: [
          StarDictField(
            "x",
            text:
                "<xdxf><k>apple</k><def><gr>noun</gr> <dtrn>a fruit</dtrn> "
                "<ex><exorig>I eat an apple.</exorig>"
                "<extr>我吃一个苹果。</extr></ex> "
                "see <kref>banana</kref></def></xdxf>",
          ),
        ],
      ),
    ]);

    expect(find.text("apple"), findsOneWidget);
    expect(find.textContaining("a fruit"), findsOneWidget);
    expect(find.textContaining("I eat an apple."), findsOneWidget);
    expect(find.textContaining("我吃一个苹果。"), findsOneWidget);
    // Cross-references render as tappable text.
    expect(find.text("banana"), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text("banana"),
        matching: find.byType(GestureDetector),
      ),
      findsOneWidget,
    );
  });

  testWidgets("renders an XDXF fragment without a root element", (
    tester,
  ) async {
    await pumpEntries(tester, [
      StardictNativeEntry(
        headword: "frag",
        fields: [
          StarDictField("x", text: "<k>frag</k><def>fragmented gloss</def>"),
        ],
      ),
    ]);

    expect(find.textContaining("fragmented gloss"), findsOneWidget);
  });

  testWidgets("renders plain and phonetic fields", (tester) async {
    await pumpEntries(tester, [
      StardictNativeEntry(
        headword: "apple",
        fields: [
          StarDictField("m", text: "plain gloss"),
          StarDictField("t", text: "'æpl"),
        ],
      ),
    ]);

    expect(find.text("plain gloss"), findsOneWidget);
    expect(find.text("['æpl]"), findsOneWidget);
  });

  testWidgets("renders Pango markup", (tester) async {
    await pumpEntries(tester, [
      StardictNativeEntry(
        headword: "colored",
        fields: [
          StarDictField(
            "g",
            text: '<span foreground="red">colored</span> word',
          ),
        ],
      ),
    ]);

    expect(find.textContaining("colored"), findsOneWidget);
    expect(find.textContaining("word"), findsWidgets);
  });

  testWidgets("renders a resource image through the resolver", (tester) async {
    await pumpEntries(tester, [
      StardictNativeEntry(
        headword: "pic",
        fields: [
          StarDictField(
            "x",
            text: "<xdxf><k>pic</k><def><rref>pic.png</rref></def></xdxf>",
          ),
        ],
      ),
    ], resourceResolver: (file) async => file == "pic.png" ? _testPng : null);
    await settleImage(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(20, 10));
  });

  testWidgets("renders nothing for an unresolvable resource image", (
    tester,
  ) async {
    await pumpEntries(tester, [
      StardictNativeEntry(
        headword: "pic",
        fields: [
          StarDictField(
            "x",
            text: "<xdxf><k>pic</k><def><rref>gone.png</rref></def></xdxf>",
          ),
        ],
      ),
    ], resourceResolver: (_) async => null);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
  });

  testWidgets("the entry zoom reaches the headword and the image cap", (
    tester,
  ) async {
    Future<void> pump(double scale) async {
      await pumpEntries(
        tester,
        [
          StardictNativeEntry(
            headword: "pic",
            fields: [
              StarDictField(
                "x",
                text: "<xdxf><k>pic</k><def><rref>pic.png</rref></def></xdxf>",
              ),
            ],
          ),
        ],
        resourceResolver: (file) async => file == "pic.png" ? _testPng : null,
        scale: scale,
      );
      await settleImage(tester);
    }

    double headwordSize() => tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .firstWhere((widget) => widget.data == "pic")
        .style!
        .fontSize!;

    BoxConstraints imageConstraints() => tester
        .widget<ConstrainedBox>(
          find
              .ancestor(
                of: find.byType(Image),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        )
        .constraints;

    await pump(1.0);
    final baseSize = headwordSize();

    await pump(2.0);

    expect(headwordSize(), baseSize * 2);
    expect(imageConstraints().maxWidth, 320 * 2);
    expect(imageConstraints().maxHeight, 260 * 2);
    // The picture is laid out twice as large rather than merely allowed to
    // grow: this one is smaller than any cap, so raising the cap alone would
    // leave it at its natural size.
    expect(tester.getSize(find.byType(Image)), const Size(40, 20));
    final provider = tester.widget<Image>(find.byType(Image)).image;
    expect(provider, isA<MemoryImage>());
    expect((provider as MemoryImage).scale, 0.5);
  });

  testWidgets("a missing loose image degrades without crashing", (
    tester,
  ) async {
    await pumpEntries(tester, [
      StardictNativeEntry(
        headword: "pic",
        fields: [
          StarDictField(
            "x",
            text: "<xdxf><k>pic</k><def><rref>pic.png</rref></def></xdxf>",
          ),
        ],
      ),
    ]);
    await tester.pumpAndSettle();

    // The headword still renders; the missing image collapses to nothing.
    expect(find.text("pic"), findsOneWidget);
  });
}
