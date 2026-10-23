import "package:ciyue/models/ai_explanation_data.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("AiExplanationData.tryParse", () {
    test("parses a complete structured explanation", () {
      final data = AiExplanationData.tryParse("""
{"phonetic": "/ˌser.ənˈdɪp.ə.ti/", "partOfSpeech": "noun", "meanings": ["the fact of finding something valuable by chance"], "examples": [{"sentence": "Finding that book was pure serendipity.", "translation": "发现那本书纯属机缘巧合。"}], "synonyms": ["chance", "fluke"], "antonyms": ["design"]}
""");
      expect(data, isNotNull);
      expect(data!.phonetic, "/ˌser.ənˈdɪp.ə.ti/");
      expect(data.partOfSpeech, "noun");
      expect(data.meanings, hasLength(1));
      expect(data.examples.single.sentence, contains("serendipity"));
      expect(data.examples.single.translation, "发现那本书纯属机缘巧合。");
      expect(data.synonyms, ["chance", "fluke"]);
      expect(data.antonyms, ["design"]);
    });

    test("tolerates markdown fences and surrounding prose", () {
      final fenced = AiExplanationData.tryParse(
        "Here is the explanation:\n```json\n{\"meanings\": [\"a thing\"]}\n```\nDone.",
      );
      expect(fenced, isNotNull);
      expect(fenced!.meanings, ["a thing"]);
    });

    test("accepts meanings as objects and examples as strings", () {
      final data = AiExplanationData.tryParse("""
{"meanings": [{"definition": "first"}, {"meaning": "second"}], "examples": ["Just a sentence."]}
""");
      expect(data, isNotNull);
      expect(data!.meanings, ["first", "second"]);
      expect(data.examples.single.sentence, "Just a sentence.");
      expect(data.examples.single.translation, isNull);
    });

    test("returns null for markdown text and for empty objects", () {
      expect(
        AiExplanationData.tryParse("## Pronunciation\n/ˌser.ənˈdɪp.ə.ti/"),
        isNull,
      );
      expect(AiExplanationData.tryParse("{}"), isNull);
      expect(AiExplanationData.tryParse("not json at all"), isNull);
      expect(AiExplanationData.tryParse("{\"meanings\": []}"), isNull);
    });

    test("partial data still parses", () {
      final data = AiExplanationData.tryParse(
        "{\"synonyms\": [\"luck\", \"fate\"]}",
      );
      expect(data, isNotNull);
      expect(data!.synonyms, ["luck", "fate"]);
      expect(data.meanings, isEmpty);
      expect(data.phonetic, isNull);
    });
  });
}
