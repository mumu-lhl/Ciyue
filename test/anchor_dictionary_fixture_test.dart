import "package:dict_reader/dict_reader.dart";
import "package:flutter_test/flutter_test.dart";

/// Built by `tools/make_anchor_fixtures.py`.
const _fixtureDir = "test/fixtures/anchor-dictionary";

String _joinedText(Iterable<StarDictField> fields) =>
    fields.map((field) => field.text ?? "").join();

void main() {
  group("anchor dictionary fixtures", () {
    test(
      "the StarDict build carries the anchors and the literal headword",
      () async {
        final reader = StarDictReader("$_fixtureDir/anchor-test");
        await reader.init();
        addTearDown(reader.close);

        final tag = await reader.lookup("tag");
        expect(tag, isNotEmpty);
        final tagHtml = _joinedText(tag.expand((entry) => entry.fields));
        expect(tagHtml, contains('<a id="sumeru"></a>'));
        expect(tagHtml, contains("SUMMERU-MARKER"));
        expect(tagHtml, contains('<a name="named"></a>'));
        expect(tagHtml, contains('href="entry://tag#sumeru"'));
        expect(tagHtml, contains('href="entry://#sumeru"'));
        expect(tagHtml, contains('href="entry://tag##sumeru"'));
        // Enough filler sits before the anchor to push it off screen, which is
        // what makes a scroll observable in the first place.
        expect(tagHtml, contains("before filler line 059"));

        final literal = await reader.lookup("tag#sumeru");
        expect(literal, isNotEmpty);
        expect(
          _joinedText(literal.expand((entry) => entry.fields)),
          contains("LITERAL-HASH-ENTRY"),
        );

        final other = await reader.lookup("other");
        expect(other, isNotEmpty);
        expect(
          _joinedText(other.expand((entry) => entry.fields)),
          contains("OTHER-ENTRY"),
        );
      },
    );

    test(
      "the MDict build carries the anchors and the literal headword",
      () async {
        final reader = DictReader("$_fixtureDir/anchor-test.mdx");
        await reader.initDict();
        addTearDown(reader.close);

        Future<String> valueOf(String key) async {
          final info = await reader.locate(key);
          expect(info, isNotNull, reason: key);
          return reader.readOneMdx(info!);
        }

        final tagHtml = await valueOf("tag");
        expect(tagHtml, contains('<a id="sumeru"></a>'));
        expect(tagHtml, contains("SUMMERU-MARKER"));
        expect(tagHtml, contains('href="entry://tag#sumeru"'));
        expect(tagHtml, contains('href="entry://tag##sumeru"'));
        expect(tagHtml, contains("before filler line 059"));

        expect(await valueOf("tag#sumeru"), contains("LITERAL-HASH-ENTRY"));
        expect(await valueOf("other"), contains("OTHER-ENTRY"));
      },
    );
  });
}
