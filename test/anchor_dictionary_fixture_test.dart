import "dart:io";

import "package:dict_reader/dict_reader.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

/// Built by `tools/make_anchor_fixtures.py`.
const _fixtureDir = "test/fixtures/anchor-dictionary";

/// A dictionary's identity is its extension-less path, so the two builds must
/// not share a stem: `anchor-test.mdx` and `anchor-test.ifo` in one folder
/// would collide and only the MDX file would ever be registered. The same rule
/// is documented for users in the FAQ.
const _mdxPath = "$_fixtureDir/anchor-test-mdx.mdx";
const _stardictPath = "$_fixtureDir/anchor-test-stardict";

String _joinedText(Iterable<StarDictField> fields) =>
    fields.map((field) => field.text ?? "").join();

void main() {
  group("anchor dictionary fixtures", () {
    test(
      "the StarDict build carries the anchors and the literal headword",
      () async {
        final reader = StarDictReader(_stardictPath);
        await reader.init();
        addTearDown(reader.close);

        final demo = await reader.lookup("anchor-demo");
        expect(demo, isNotEmpty);
        final demoHtml = _joinedText(demo.expand((entry) => entry.fields));
        expect(demoHtml, contains('<a id="sumeru"></a>'));
        expect(demoHtml, contains("SUMMERU-MARKER"));
        expect(demoHtml, contains('<a name="named"></a>'));
        expect(demoHtml, contains('href="entry://anchor-demo#sumeru"'));
        expect(demoHtml, contains('href="entry://#sumeru"'));
        expect(demoHtml, contains('href="entry://anchor-demo##sumeru"'));
        // Enough filler sits before the anchor to push it off screen, which is
        // what makes a scroll observable in the first place.
        expect(demoHtml, contains("before filler line 059"));

        final literal = await reader.lookup("anchor-demo#sumeru");
        expect(literal, isNotEmpty);
        expect(
          _joinedText(literal.expand((entry) => entry.fields)),
          contains("LITERAL-HASH-ENTRY"),
        );

        final other = await reader.lookup("anchor-demo-other");
        expect(other, isNotEmpty);
        final otherHtml = _joinedText(other.expand((entry) => entry.fields));
        expect(otherHtml, contains("OTHER-ENTRY"));
        expect(otherHtml, contains('href="entry://#local"'));
        // The in-place anchor must start below the fold too, otherwise a broken
        // scroll into it is indistinguishable from a working one.
        expect(otherHtml, contains("local filler line 059"));
      },
    );

    test(
      "the MDict build carries the anchors and the literal headword",
      () async {
        final reader = DictReader(_mdxPath);
        await reader.initDict();
        addTearDown(reader.close);

        Future<String> valueOf(String key) async {
          final info = await reader.locate(key);
          expect(info, isNotNull, reason: key);
          return reader.readOneMdx(info!);
        }

        final demoHtml = await valueOf("anchor-demo");
        expect(demoHtml, contains('<a id="sumeru"></a>'));
        expect(demoHtml, contains("SUMMERU-MARKER"));
        expect(demoHtml, contains('href="entry://anchor-demo#sumeru"'));
        expect(demoHtml, contains('href="entry://anchor-demo##sumeru"'));
        expect(demoHtml, contains("before filler line 059"));

        final otherHtml = await valueOf("anchor-demo-other");
        expect(otherHtml, contains("OTHER-ENTRY"));
        expect(otherHtml, contains("local filler line 059"));

        expect(
          await valueOf("anchor-demo#sumeru"),
          contains("LITERAL-HASH-ENTRY"),
        );
      },
    );

    test("the two builds can be imported side by side", () async {
      // Distinct stems are what keeps the identity key apart; a shared stem
      // would make the StarDict build silently lose to the MDX one.
      expect(
        p.setExtension(_mdxPath, ""),
        isNot(equals(p.setExtension(_stardictPath, ""))),
      );

      final mdx = DictReader(_mdxPath);
      await mdx.initDict();
      addTearDown(mdx.close);
      final stardict = StarDictReader(_stardictPath);
      await stardict.init();
      addTearDown(stardict.close);

      // Distinct titles keep the two tabs apart when both dictionaries are
      // enabled in the same group.
      expect(mdx.header["Title"], "Anchor Test (MDX)");
      expect(stardict.bookName, "Anchor Test (StarDict)");
      expect(File("$_stardictPath.ifo").existsSync(), isTrue);
      expect(File("$_stardictPath.idx").existsSync(), isTrue);
      expect(File("$_stardictPath.dict").existsSync(), isTrue);
    });
  });
}
