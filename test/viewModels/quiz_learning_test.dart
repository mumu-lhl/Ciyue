import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/services/tts.dart";
import "package:ciyue/viewModels/chat_view_model.dart";
import "package:ciyue/viewModels/quiz_view_model.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("QuizMistakeDao", () {
    late AppDatabase database;
    late QuizMistakeDao dao;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      dao = QuizMistakeDao(database);
    });

    tearDown(() async {
      await database.close();
    });

    test("add and retrieve mistakes", () async {
      await dao.addMistake(
        word: "apple",
        questionType: QuizQuestionType.choice,
        question: "What does apple mean?",
        correctAnswer: "苹果",
        userAnswer: "香蕉",
      );

      final mistakes = await dao.getMistakes();
      expect(mistakes.length, 1);
      expect(mistakes.first.word, "apple");
      expect(mistakes.first.questionType, QuizQuestionType.choice);
      expect(mistakes.first.correctAnswer, "苹果");
      expect(mistakes.first.userAnswer, "香蕉");
      expect(await dao.getMistakeCount(), 1);
    });

    test("re-adding the same word bumps it to the top", () async {
      await dao.addMistake(
        word: "apple",
        questionType: QuizQuestionType.choice,
        question: "q1",
        correctAnswer: "a1",
      );
      await dao.addMistake(
        word: "banana",
        questionType: QuizQuestionType.spelling,
        question: "q2",
        correctAnswer: "a2",
      );
      await dao.addMistake(
        word: "apple",
        questionType: QuizQuestionType.cloze,
        question: "q3",
        correctAnswer: "a3",
      );

      final mistakes = await dao.getMistakes();
      // No duplicate rows; apple moved to the front.
      expect(mistakes.length, 2);
      expect(mistakes.first.word, "apple");
      expect(mistakes.first.questionType, QuizQuestionType.cloze);
    });

    test("removeMistake and clearMistakes", () async {
      await dao.addMistake(
        word: "apple",
        questionType: QuizQuestionType.choice,
        question: "q",
        correctAnswer: "a",
      );
      await dao.removeMistake("apple");
      expect(await dao.getMistakeCount(), 0);

      await dao.addMistake(
        word: "apple",
        questionType: QuizQuestionType.choice,
        question: "q",
        correctAnswer: "a",
      );
      await dao.addMistake(
        word: "banana",
        questionType: QuizQuestionType.choice,
        question: "q",
        correctAnswer: "a",
      );
      await dao.clearMistakes();
      expect(await dao.getMistakeCount(), 0);
      expect(await dao.getMistakes(), isEmpty);
    });

    test("mistake matching is case-insensitive", () async {
      await dao.addMistake(
        word: "Apple",
        questionType: QuizQuestionType.choice,
        question: "q",
        correctAnswer: "a",
      );
      // Same word in a different case must not create a second row.
      await dao.addMistake(
        word: "apple",
        questionType: QuizQuestionType.choice,
        question: "q2",
        correctAnswer: "a",
      );
      expect(await dao.getMistakeCount(), 1);

      // Removal works regardless of the casing the AI produced.
      await dao.removeMistake("APPLE");
      expect(await dao.getMistakeCount(), 0);
    });

    test("options round-trip and question rebuild", () async {
      await dao.addMistake(
        word: "apple",
        questionType: QuizQuestionType.choice,
        question: "What does apple mean?",
        correctAnswer: "苹果",
        userAnswer: "香蕉",
        options: ["苹果", "香蕉", "橙子"],
      );
      final row = (await dao.getMistakes()).single;
      final rebuilt = quizQuestionFromMistake(row);
      expect(rebuilt, isNotNull);
      expect(rebuilt!.options, ["苹果", "香蕉", "橙子"]);
      expect(rebuilt.correctIndex, 0);
      expect(rebuilt.correctAnswer, "苹果");
      expect(rebuilt.isUsable, isTrue);
    });

    test("rows without options cannot be rebuilt (legacy)", () async {
      await dao.addMistake(
        word: "apple",
        questionType: QuizQuestionType.choice,
        question: "q",
        correctAnswer: "a",
      );
      final row = (await dao.getMistakes()).single;
      expect(quizQuestionFromMistake(row), isNull);

      // Spelling rows rebuild fine without options.
      await dao.addMistake(
        word: "banana",
        questionType: QuizQuestionType.spelling,
        question: "A yellow fruit",
        correctAnswer: "banana",
      );
      final spellingRow = (await dao.getMistakes()).firstWhere(
        (m) => m.word == "banana",
      );
      final spelling = quizQuestionFromMistake(spellingRow);
      expect(spelling, isNotNull);
      expect(spelling!.correctAnswer, "banana");
    });
  });

  group("QuizQuestion", () {
    test("fromJson parses all three types", () {
      final choice = QuizQuestion.fromJson({
        "word": "apple",
        "type": "choice",
        "question": "What does apple mean?",
        "options": ["苹果", "香蕉", "橙子", "葡萄"],
        "correctIndex": 0,
        "explanation": "apple means 苹果",
      });
      expect(choice.type, QuizQuestionType.choice);
      expect(choice.correctAnswer, "苹果");

      final spelling = QuizQuestion.fromJson({
        "word": "apple",
        "type": "spelling",
        "question": "A round fruit",
        "options": [],
        "correctIndex": 0,
        "explanation": "a",
      });
      expect(spelling.type, QuizQuestionType.spelling);
      expect(spelling.correctAnswer, "apple");

      final cloze = QuizQuestion.fromJson({
        "word": "apple",
        "type": "cloze",
        "question": "I eat an ____ every day.",
        "options": ["apple", "banana", "car", "run"],
        "correctIndex": 0,
        "explanation": "a",
      });
      expect(cloze.type, QuizQuestionType.cloze);
      expect(cloze.correctAnswer, "apple");
    });

    test("fromJson defaults missing type to choice", () {
      final q = QuizQuestion.fromJson({
        "word": "apple",
        "question": "q",
        "options": ["a"],
        "correctIndex": 0,
        "explanation": "e",
      });
      expect(q.type, QuizQuestionType.choice);
    });

    test("fromJson coerces drifting correctIndex values", () {
      final fromDouble = QuizQuestion.fromJson({
        "word": "apple",
        "question": "q",
        "options": ["a", "b", "c", "d"],
        "correctIndex": 1.0,
      });
      expect(fromDouble.correctIndex, 1);

      final fromString = QuizQuestion.fromJson({
        "word": "apple",
        "question": "q",
        "options": ["a", "b", "c", "d"],
        "correctIndex": "2",
      });
      expect(fromString.correctIndex, 2);

      final outOfRange = QuizQuestion.fromJson({
        "word": "apple",
        "question": "q",
        "options": ["a", "b", "c", "d"],
        "correctIndex": 99,
      });
      expect(outOfRange.correctIndex, 3);
      expect(outOfRange.correctAnswer, "d");
    });

    test("isUsable rejects unanswerable questions", () {
      final noOptions = QuizQuestion.fromJson({
        "word": "apple",
        "type": "choice",
        "question": "q",
        "options": <String>[],
      });
      expect(noOptions.isUsable, isFalse);

      final emptyWord = QuizQuestion.fromJson({
        "word": "",
        "type": "spelling",
        "question": "q",
      });
      expect(emptyWord.isUsable, isFalse);

      final spelling = QuizQuestion.fromJson({
        "word": "apple",
        "type": "spelling",
        "question": "A round fruit",
      });
      expect(spelling.isUsable, isTrue);
    });
  });

  group("TtsHelper.stripMarkdown", () {
    test("removes common markdown syntax", () {
      expect(TtsHelper.stripMarkdown("**Hello** _world_"), "Hello world");
      expect(
        TtsHelper.stripMarkdown("# Title\n- item one\n- item two"),
        "Title\nitem one\nitem two",
      );
      expect(TtsHelper.stripMarkdown("Use `print()` here"), "Use print() here");
      expect(
        TtsHelper.stripMarkdown("[link text](https://example.com)"),
        "link text",
      );
    });

    test("removes code blocks entirely", () {
      final result = TtsHelper.stripMarkdown(
        "Say this\n```dart\nvoid main() {}\n```\nthen that",
      );
      expect(result, contains("Say this"));
      expect(result, contains("then that"));
      expect(result, isNot(contains("void main")));
      expect(result, isNot(contains("```")));
    });
  });

  group("ChatMessage", () {
    test("toJson/fromJson round trip", () {
      const original = ChatMessage(text: "hello", isUser: true);
      final restored = ChatMessage.fromJson(original.toJson());
      expect(restored.text, "hello");
      expect(restored.isUser, isTrue);
    });

    test("fromJson tolerates missing fields", () {
      final m = ChatMessage.fromJson({});
      expect(m.text, "");
      expect(m.isUser, isFalse);
    });
  });

  group("ChatScenario.promptTitle", () {
    test("presets use plain titles, never l10n keys", () {
      for (final s in ChatScenario.presets) {
        expect(s.promptTitle, isNot(startsWith("scenario")));
        expect(s.promptTitle, isNotEmpty);
      }
      expect(ChatScenario.presets.first.promptTitle, "At a Restaurant");
    });

    test("custom scenarios use their own title", () {
      const custom = ChatScenario(
        id: "custom_1",
        titleKey: "At the Airport",
        systemPrompt: "You are a check-in agent.",
      );
      expect(custom.promptTitle, "At the Airport");
    });
  });
}
