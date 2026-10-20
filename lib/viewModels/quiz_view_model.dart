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

/// Question types supported by the quiz.
class QuizQuestionType {
  static const String choice = "choice";
  static const String spelling = "spelling";
  static const String cloze = "cloze";

  static const List<String> all = [choice, spelling, cloze];
}

class QuizQuestion {
  final String word;
  final String type;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  QuizQuestion({
    required this.word,
    this.type = QuizQuestionType.choice,
    required this.question,
    this.options = const [],
    this.correctIndex = 0,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    // AI output drifts: numbers arrive as doubles or strings, options
    // may contain non-strings. Coerce everything instead of casting.
    final options = (json["options"] as List?)
        ?.map((e) => e.toString())
        .toList();
    final rawIndex = json["correctIndex"];
    var correctIndex = switch (rawIndex) {
      int i => i,
      double d => d.toInt(),
      String s => int.tryParse(s) ?? double.tryParse(s)?.toInt() ?? 0,
      _ => 0,
    };
    if (options != null && options.isNotEmpty) {
      correctIndex = correctIndex.clamp(0, options.length - 1);
    } else {
      correctIndex = 0;
    }
    return QuizQuestion(
      word: json["word"]?.toString() ?? "",
      type: json["type"]?.toString() ?? QuizQuestionType.choice,
      question: json["question"]?.toString() ?? "",
      options: options ?? const [],
      correctIndex: correctIndex,
      explanation: json["explanation"]?.toString() ?? "",
    );
  }

  /// Whether this question can actually be answered: choice/cloze
  /// questions need options with a valid correct index.
  bool get isUsable {
    if (word.isEmpty || question.isEmpty) return false;
    if (type == QuizQuestionType.spelling) return true;
    return options.length >= 2 &&
        correctIndex >= 0 &&
        correctIndex < options.length;
  }

  /// The canonical correct answer text, regardless of type.
  String get correctAnswer {
    if (type == QuizQuestionType.spelling) return word;
    if (options.isNotEmpty &&
        correctIndex >= 0 &&
        correctIndex < options.length) {
      return options[correctIndex];
    }
    return word;
  }
}

/// Rebuild the original question from a stored mistake row, so review
/// works offline without asking the AI to regenerate questions.
/// Returns null when the row can't be rebuilt (rows written before
/// schema v24 have no stored options) — the caller falls back to AI
/// generation for those words.
QuizQuestion? quizQuestionFromMistake(QuizMistake mistake) {
  if (mistake.questionType == QuizQuestionType.spelling) {
    return QuizQuestion(
      word: mistake.word,
      type: QuizQuestionType.spelling,
      question: mistake.question,
      options: const [],
      correctIndex: 0,
      explanation: "",
    );
  }
  final raw = mistake.options;
  if (raw == null) return null;
  try {
    final options = (json.decode(raw) as List)
        .map((e) => e.toString())
        .toList();
    final correctIndex = options.indexOf(mistake.correctAnswer);
    if (options.length < 2 || correctIndex < 0) return null;
    return QuizQuestion(
      word: mistake.word,
      type: mistake.questionType,
      question: mistake.question,
      options: options,
      correctIndex: correctIndex,
      explanation: "",
    );
  } catch (_) {
    return null;
  }
}

enum QuizState { idle, loading, answering, finished }

class QuizViewModel extends ChangeNotifier {
  final WordbookDao _wordbookDao;
  final QuizMistakeDao _mistakeDao;
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

  String? _spellingAnswer;
  String? get spellingAnswer => _spellingAnswer;

  bool _spellingChecked = false;
  bool get spellingChecked => _spellingChecked;

  bool _reviewMode = false;
  bool get reviewMode => _reviewMode;

  /// Set when quiz generation failed (network, API, malformed AI
  /// output) so the UI can show an error instead of the misleading
  /// "not enough words" message.
  bool _loadFailed = false;
  bool get loadFailed => _loadFailed;

  int _mistakeCount = 0;
  int get mistakeCount => _mistakeCount;

  bool _mounted = true;

  static const int defaultQuestionCount = 5;

  QuizViewModel({WordbookDao? dao, QuizMistakeDao? mistakeDao})
    : _wordbookDao = dao ?? WordbookDao(mainDatabase),
      _mistakeDao = mistakeDao ?? QuizMistakeDao(mainDatabase),
      _ai = AI(
        provider: settings.aiProvider,
        model: settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
        apikey:
            settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
      ) {
    _loadMistakeCount();
  }

  Future<void> _loadMistakeCount() async {
    try {
      _mistakeCount = await _mistakeDao.getMistakeCount();
      if (_mounted) notifyListeners();
    } catch (_) {}
  }

  int get questionCount =>
      prefs.getInt("quizQuestionCount") ?? defaultQuestionCount;

  Future<void> setQuestionCount(int count) async {
    await prefs.setInt("quizQuestionCount", count);
    notifyListeners();
  }

  /// Enabled question types, persisted as a JSON list in prefs.
  List<String> get questionTypes {
    try {
      final raw = prefs.getString("quizQuestionTypes");
      if (raw == null) return List.of(QuizQuestionType.all);
      final list = (json.decode(raw) as List).cast<String>();
      final valid = list
          .where((t) => QuizQuestionType.all.contains(t))
          .toList();
      return valid.isEmpty ? List.of(QuizQuestionType.all) : valid;
    } catch (_) {
      return List.of(QuizQuestionType.all);
    }
  }

  Future<void> setQuestionTypes(List<String> types) async {
    final valid = types.where((t) => QuizQuestionType.all.contains(t)).toList();
    await prefs.setString(
      "quizQuestionTypes",
      json.encode(valid.isEmpty ? QuizQuestionType.all : valid),
    );
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

  bool get isAnswered =>
      _selectedIndex != null || (_spellingChecked && _spellingAnswer != null);

  /// Human-readable description of enabled types for the AI prompt.
  String _typesDescription(List<String> types) {
    final parts = <String>[];
    if (types.contains(QuizQuestionType.choice)) {
      parts.add(
        '"choice": show the word and ask for its meaning; provide 4 options (1 correct, 3 plausible distractors)',
      );
    }
    if (types.contains(QuizQuestionType.spelling)) {
      parts.add(
        '"spelling": show the meaning/definition in the target language and ask the user to spell the word; set "options" to [] and "correctIndex" to 0',
      );
    }
    if (types.contains(QuizQuestionType.cloze)) {
      parts.add(
        '"cloze": show an example sentence with the word replaced by "____" and ask which word fits; provide 4 word options (1 correct, 3 plausible distractors)',
      );
    }
    return parts.join("\n");
  }

  Future<void> startQuiz() => _startQuiz(reviewOnly: false);

  Future<void> startMistakeReview() => _startQuiz(reviewOnly: true);

  Future<void> _startQuiz({required bool reviewOnly}) async {
    _state = QuizState.loading;
    _loadFailed = false;
    _questions = [];
    _currentIndex = 0;
    _score = 0;
    _selectedIndex = null;
    _spellingAnswer = null;
    _spellingChecked = false;
    _reviewMode = reviewOnly;
    notifyListeners();

    // Questions rebuilt locally from stored mistake rows (review
    // mode). Only words that can't be rebuilt go to the AI.
    var localQuestions = <QuizQuestion>[];
    try {
      List<String> quizWords;
      if (reviewOnly) {
        final mistakes = await _mistakeDao.getMistakes();
        if (!_mounted) return;
        if (mistakes.isEmpty) {
          _state = QuizState.idle;
          notifyListeners();
          return;
        }
        final random = math.Random();
        final shuffled = List.of(mistakes)..shuffle(random);
        final aiWords = <String>[];
        for (final m in shuffled) {
          final q = quizQuestionFromMistake(m);
          if (q != null) {
            localQuestions.add(q);
          } else {
            aiWords.add(m.word);
          }
        }
        if (aiWords.isEmpty) {
          // Everything rebuilt locally — review works fully offline.
          _questions = localQuestions;
          _state = QuizState.answering;
          notifyListeners();
          return;
        }
        quizWords = aiWords;
      } else {
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
        quizWords = shuffled.take(count).map((w) => w.word).toList();
      }

      final targetLanguage = settings.language! == "system"
          ? ui.PlatformDispatcher.instance.locale.languageCode
          : settings.language!;

      final types = questionTypes;
      final template = AIPrompts().quizPrompt;
      final prompt = template
          .replaceAll(r"$count", quizWords.length.toString())
          .replaceAll(r"$words", quizWords.join(", "))
          .replaceAll(r"$targetLanguage", targetLanguage)
          .replaceAll(r"$types", _typesDescription(types));

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
      _questions = [
        ...localQuestions,
        ...questionsJson
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .where((q) => q.isUsable),
      ];

      if (_questions.isEmpty) {
        // The AI returned nothing usable (empty array, refusal, or
        // unanswerable questions) — report failure instead of
        // entering the answering state with no questions.
        _loadFailed = true;
        _state = QuizState.idle;
      } else {
        _state = QuizState.answering;
      }
    } catch (e) {
      if (localQuestions.isNotEmpty) {
        // Review mode: the AI fallback failed (e.g. offline) but the
        // locally rebuilt questions are still usable on their own.
        _questions = localQuestions;
        _state = QuizState.answering;
      } else {
        _loadFailed = true;
        _state = QuizState.idle;
      }
    } finally {
      if (_mounted) notifyListeners();
    }
  }

  void selectAnswer(int index) {
    if (_state != QuizState.answering || _selectedIndex != null) return;
    _selectedIndex = index;
    final q = currentQuestion!;
    if (index == q.correctIndex) {
      _score++;
      // A correct answer clears the word from the mistake book in
      // both modes — it has been mastered either way.
      _mistakeDao.removeMistake(q.word).then((_) => _loadMistakeCount());
    } else {
      _recordMistake(q, userAnswer: q.options[index]);
    }
    notifyListeners();
  }

  /// Submit a spelling answer. Returns true if correct.
  bool submitSpelling(String answer) {
    if (_state != QuizState.answering || _spellingChecked) return false;
    final q = currentQuestion!;
    _spellingAnswer = answer;
    _spellingChecked = true;
    final correct = answer.trim().toLowerCase() == q.word.trim().toLowerCase();
    if (correct) {
      _score++;
      _mistakeDao.removeMistake(q.word).then((_) => _loadMistakeCount());
    } else {
      _recordMistake(q, userAnswer: answer.trim());
    }
    notifyListeners();
    return correct;
  }

  void _recordMistake(QuizQuestion q, {String? userAnswer}) {
    _mistakeDao
        .addMistake(
          word: q.word,
          questionType: q.type,
          question: q.question,
          correctAnswer: q.correctAnswer,
          userAnswer: userAnswer,
          // Persist the options so review can rebuild this exact
          // question offline (spelling needs none).
          options: q.type == QuizQuestionType.spelling ? null : q.options,
        )
        .then((_) => _loadMistakeCount())
        .catchError((_) {});
  }

  void nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      _currentIndex++;
      _selectedIndex = null;
      _spellingAnswer = null;
      _spellingChecked = false;
      notifyListeners();
    } else {
      _state = QuizState.finished;
      notifyListeners();
    }
  }

  Future<void> clearMistakes() async {
    await _mistakeDao.clearMistakes();
    _mistakeCount = 0;
    notifyListeners();
  }

  void restart() {
    _startQuiz(reviewOnly: _reviewMode);
  }
}
