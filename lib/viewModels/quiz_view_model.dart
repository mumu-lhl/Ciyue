import "dart:convert";
import "dart:math" as math;
import "dart:ui" as ui;

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:material_ui/material_ui.dart";

class QuizQuestion {
  final String word;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  QuizQuestion({
    required this.word,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      word: json["word"] as String,
      question: json["question"] as String,
      options: (json["options"] as List).cast<String>(),
      correctIndex: json["correctIndex"] as int,
      explanation: json["explanation"] as String? ?? "",
    );
  }
}

enum QuizState { idle, loading, answering, finished }

class QuizViewModel extends ChangeNotifier {
  final WordbookDao _wordbookDao;
  final AI _ai;

  QuizState _state = QuizState.idle;
  QuizState get state => _state;

  List<QuizQuestion> _questions = [];
  List<QuizQuestion> get questions => _questions;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  int _score = 0;
  int get score => _score;

  int? _selectedIndex;
  int? get selectedIndex => _selectedIndex;

  bool _mounted = true;

  static const int defaultQuestionCount = 5;

  QuizViewModel({WordbookDao? dao})
    : _wordbookDao = dao ?? WordbookDao(mainDatabase),
      _ai = AI(
        provider: settings.aiProvider,
        model: settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
        apikey:
            settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
      );

  int get questionCount =>
      prefs.getInt("quizQuestionCount") ?? defaultQuestionCount;

  Future<void> setQuestionCount(int count) async {
    await prefs.setInt("quizQuestionCount", count);
    notifyListeners();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  int get totalQuestions => _questions.length;

  QuizQuestion? get currentQuestion =>
      _questions.isEmpty ? null : _questions[_currentIndex];

  bool get isAnswered => _selectedIndex != null;

  Future<void> startQuiz() async {
    _state = QuizState.loading;
    _questions = [];
    _currentIndex = 0;
    _score = 0;
    _selectedIndex = null;
    notifyListeners();

    try {
      final allWords = await _wordbookDao.getAllWords();
      if (!_mounted) return;

      if (allWords.length < 4) {
        _state = QuizState.idle;
        notifyListeners();
        return;
      }

      // Pick random words for the quiz.
      final random = math.Random();
      final shuffled = List<WordbookData>.from(allWords)..shuffle(random);
      final count = questionCount.clamp(1, allWords.length);
      final quizWords = shuffled
          .take(count)
          .map((w) => w.word)
          .toList();

      final targetLanguage = settings.language! == "system"
          ? ui.PlatformDispatcher.instance.locale.languageCode
          : settings.language!;

      final template = AIPrompts().quizPrompt;
      final prompt = template
          .replaceAll(r"$count", count.toString())
          .replaceAll(r"$words", quizWords.join(", "))
          .replaceAll(r"$targetLanguage", targetLanguage);

      final response = await _ai.request(prompt);
      if (!_mounted) return;

      // Extract JSON from response (handle markdown code blocks).
      var jsonStr = response.trim();
      if (jsonStr.startsWith("```")) {
        final start = jsonStr.indexOf("\n") + 1;
        final end = jsonStr.lastIndexOf("```");
        jsonStr = jsonStr.substring(start, end).trim();
      }

      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final questionsJson = data["questions"] as List;
      _questions = questionsJson
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList();

      _state = QuizState.answering;
    } catch (e) {
      _state = QuizState.idle;
    } finally {
      if (_mounted) notifyListeners();
    }
  }

  void selectAnswer(int index) {
    if (_state != QuizState.answering || _selectedIndex != null) return;
    _selectedIndex = index;
    if (index == currentQuestion!.correctIndex) {
      _score++;
    }
    notifyListeners();
  }

  void nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      _currentIndex++;
      _selectedIndex = null;
      notifyListeners();
    } else {
      _state = QuizState.finished;
      notifyListeners();
    }
  }

  void restart() {
    startQuiz();
  }
}
