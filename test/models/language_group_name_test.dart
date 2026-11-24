import "package:ciyue/models/language.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("languageCodeFromGroupName", () {
    test("accepts codes and exact language names", () {
      expect(languageCodeFromGroupName("ja"), "ja");
      expect(languageCodeFromGroupName("Japanese"), "ja");
      expect(languageCodeFromGroupName("简体中文"), "zh");
    });

    test("accepts Simplified, Traditional, English and Japanese names", () {
      expect(languageCodeFromGroupName("德语"), "de");
      expect(languageCodeFromGroupName("德語"), "de");
      expect(languageCodeFromGroupName("German"), "de");
      expect(languageCodeFromGroupName("ドイツ語"), "de");
      expect(languageCodeFromGroupName("Deutsch"), "de");
      expect(languageCodeFromGroupName("繁体中文"), "zh_HK");
      expect(languageCodeFromGroupName("正體中文"), "zh_TW");
      expect(languageCodeFromGroupName("한국어"), "ko");
      expect(languageCodeFromGroupName("বাংলা"), "bn");
    });

    test("rejects mixed or unknown names instead of guessing", () {
      expect(languageCodeFromGroupName("英汉双解"), isNull);
      expect(languageCodeFromGroupName("我的词典"), isNull);
      expect(languageCodeFromGroupName("Default"), isNull);
      expect(languageCodeFromGroupName("auto"), isNull);
    });
  });
}
