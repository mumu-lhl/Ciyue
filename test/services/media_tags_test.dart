import "package:ciyue/services/media_tags.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("rewriteMediaTags audio", () {
    test("turns pyglossary's <audio> back into a sound:// link", () {
      // The exact markup 新明解7 produces after a pyglossary conversion.
      const input =
          '<span class="audio"><audio src="audio/000000.mp3">'
          '<img class="audio" src="Audio.png"/></audio></span>';
      expect(
        rewriteMediaTags(input),
        '<span class="audio"><a href="sound://audio/000000.mp3">'
        '<img class="audio" src="Audio.png"/></a></span>',
      );
    });

    test("adds a speaker icon when the fallback carries no image", () {
      final result = rewriteMediaTags(
        '<audio src="audio/1.mp3">listen</audio>',
      );
      expect(result, startsWith('<a href="sound://audio/1.mp3">listen<svg'));
      expect(result, endsWith("</svg></a>"));
    });

    test("keeps sources that already carry a scheme", () {
      const remote = '<audio src="https://example.com/a.mp3">x</audio>';
      expect(rewriteMediaTags(remote), remote);

      const already = '<audio src="sound://a.mp3">x</audio>';
      expect(rewriteMediaTags(already), already);
    });

    test("matches the tag case-insensitively", () {
      const input = '<AUDIO SRC="audio/1.mp3"><IMG SRC="a.png"></AUDIO>';
      expect(
        rewriteMediaTags(input),
        '<a href="sound://audio/1.mp3"><IMG SRC="a.png"></a>',
      );
    });

    test("tolerates extra attributes on the audio tag", () {
      const input =
          '<audio src="audio/1.mp3" controls>'
          '<img src="a.png"></audio>';
      expect(
        rewriteMediaTags(input),
        '<a href="sound://audio/1.mp3"><img src="a.png"></a>',
      );
    });

    test("leaves an audio element without a src attribute alone", () {
      const input = '<audio><source src="a.mp3"></audio>';
      expect(rewriteMediaTags(input), input);
    });
  });

  group("rewriteMediaTags video", () {
    test("adds controls when it is missing", () {
      expect(
        rewriteMediaTags('<video src="video/1.mp4"></video>'),
        '<video src="video/1.mp4" controls></video>',
      );
    });

    test("keeps an existing controls attribute", () {
      const input = '<video src="video/1.mp4" controls></video>';
      expect(rewriteMediaTags(input), input);
    });

    test("adds controls to a video built from source children", () {
      expect(
        rewriteMediaTags('<video><source src="1.mp4"></video>'),
        '<video controls><source src="1.mp4"></video>',
      );
    });

    test("does not treat a closing tag as an opening one", () {
      expect(rewriteMediaTags("</video>"), "</video>");
    });
  });

  group("rewriteMediaTags", () {
    test("returns content without media tags unchanged", () {
      const input = '<span class="項目"><span class="見出仮名">あ</span></span>';
      expect(rewriteMediaTags(input), input);
    });

    test("handles empty input", () {
      expect(rewriteMediaTags(""), "");
    });
  });
}
