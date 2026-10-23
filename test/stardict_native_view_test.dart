import "package:ciyue/ui/core/word_display/stardict_native_view.dart";
import "package:dict_reader/dict_reader.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  Future<void> pumpEntries(
    WidgetTester tester,
    List<StardictNativeEntry> entries,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StardictEntryListView(
            entries: entries,
            resourceDirectory: "/nonexistent",
            dictId: 1,
            isExpansion: true,
          ),
        ),
      ),
    );
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
}
