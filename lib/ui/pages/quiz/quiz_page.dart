import "package:ciyue/services/tts.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/quiz_view_model.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:gpt_markdown/gpt_markdown.dart";

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final QuizViewModel _viewModel;
  final _spellingController = TextEditingController();
  String? _lastSpellingWord;

  @override
  void initState() {
    super.initState();
    _viewModel = QuizViewModel();
    _viewModel.startQuiz();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _spellingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isLargeScreen(context);
    final locale = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final model = _viewModel;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              model.reviewMode ? locale.reviewMistakes : locale.wordQuiz,
            ),
            actions: [
              if (model.state == QuizState.answering)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      "${model.score} / ${model.totalQuestions}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 700 : 500),
              child: _buildBody(context, model),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, QuizViewModel model) {
    switch (model.state) {
      case QuizState.idle:
        return _buildIdle(context, model);
      case QuizState.loading:
        return const Center(child: CircularProgressIndicator());
      case QuizState.answering:
        return _buildQuestion(context, model);
      case QuizState.finished:
        return _buildResult(context, model);
    }
  }

  Widget _buildIdle(BuildContext context, QuizViewModel model) {
    final locale = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            locale.quizNeedWords,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: model.startQuiz, child: Text(locale.retry)),
          if (model.mistakeCount > 0) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: Text(locale.reviewMistakesWithCount(model.mistakeCount)),
              onPressed: model.startMistakeReview,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, QuizViewModel model) {
    final question = model.currentQuestion!;
    if (question.type == QuizQuestionType.spelling) {
      return _buildSpellingQuestion(context, model, question);
    }
    return _buildChoiceQuestion(context, model, question);
  }

  Widget _questionHeader(
    BuildContext context,
    QuizViewModel model,
    QuizQuestion question,
  ) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (model.currentIndex + 1) / model.totalQuestions,
        ),
        const SizedBox(height: 8),
        Text(
          "${locale.question} ${model.currentIndex + 1} / ${model.totalQuestions}",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildChoiceQuestion(
    BuildContext context,
    QuizViewModel model,
    QuizQuestion question,
  ) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;
    final isCloze = question.type == QuizQuestionType.cloze;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _questionHeader(context, model, question),
          // Word (choice) or sentence (cloze)
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    isCloze ? question.question : question.word,
                    style:
                        (isCloze
                                ? theme.textTheme.titleLarge
                                : theme.textTheme.headlineMedium)
                            ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!isCloze)
                  IconButton(
                    icon: const Icon(Icons.volume_up_outlined),
                    tooltip: locale.readAloud,
                    onPressed: () => TtsHelper.toggleSpeak(question.word),
                  ),
              ],
            ),
          ),
          if (!isCloze) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                question.question,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Options
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final isSelected = model.selectedIndex == index;
                final isCorrect = index == question.correctIndex;
                final showResult = model.isAnswered;

                Color? bgColor;
                if (showResult) {
                  if (isCorrect) {
                    bgColor = theme.colorScheme.primaryContainer;
                  } else if (isSelected) {
                    bgColor = theme.colorScheme.errorContainer;
                  }
                }

                return Card(
                  color: bgColor,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(question.options[index]),
                    leading: showResult && isCorrect
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : showResult && isSelected
                        ? const Icon(Icons.cancel, color: Colors.red)
                        : null,
                    onTap: showResult ? null : () => model.selectAnswer(index),
                  ),
                );
              },
            ),
          ),
          _buildExplanation(context, model, question),
          if (model.isAnswered)
            FilledButton(
              onPressed: model.nextQuestion,
              child: Text(
                model.currentIndex < model.totalQuestions - 1
                    ? locale.next
                    : locale.finish,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpellingQuestion(
    BuildContext context,
    QuizViewModel model,
    QuizQuestion question,
  ) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;
    final answered = model.isAnswered;
    // Clear stale input when moving to a new spelling question.
    if (_lastSpellingWord != question.word) {
      _lastSpellingWord = question.word;
      _spellingController.clear();
    }
    final correct =
        answered &&
        model.spellingAnswer!.trim().toLowerCase() ==
            question.word.trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _questionHeader(context, model, question),
          Center(
            child: Text(
              question.question,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              locale.typeTheWord,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _spellingController,
            enabled: !answered,
            autofocus: true,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: locale.typeTheWord,
              suffixIcon: answered
                  ? Icon(
                      correct ? Icons.check_circle : Icons.cancel,
                      color: correct ? Colors.green : Colors.red,
                    )
                  : null,
            ),
            onSubmitted: (_) {
              if (!answered) {
                model.submitSpelling(_spellingController.text);
              }
            },
          ),
          if (answered && !correct) ...[
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${locale.correctAnswer}: ",
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    question.word,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_outlined),
                    tooltip: locale.readAloud,
                    onPressed: () => TtsHelper.toggleSpeak(question.word),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildExplanation(context, model, question),
          const Spacer(),
          if (!answered)
            FilledButton(
              onPressed: () {
                if (_spellingController.text.trim().isNotEmpty) {
                  model.submitSpelling(_spellingController.text);
                }
              },
              child: Text(locale.submit),
            )
          else
            FilledButton(
              onPressed: () {
                _spellingController.clear();
                model.nextQuestion();
              },
              child: Text(
                model.currentIndex < model.totalQuestions - 1
                    ? locale.next
                    : locale.finish,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExplanation(
    BuildContext context,
    QuizViewModel model,
    QuizQuestion question,
  ) {
    final theme = Theme.of(context);
    if (!model.isAnswered || question.explanation.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectionArea(child: GptMarkdown(question.explanation)),
    );
  }

  Widget _buildResult(BuildContext context, QuizViewModel model) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;
    final percentage = model.totalQuestions > 0
        ? (model.score / model.totalQuestions * 100).round()
        : 0;
    final wrongCount = model.totalQuestions - model.score;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "$percentage%",
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${locale.score}: ${model.score} / ${model.totalQuestions}",
            style: theme.textTheme.titleLarge,
          ),
          if (wrongCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              locale.mistakesCount(wrongCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(onPressed: model.restart, child: Text(locale.retryQuiz)),
          if (!model.reviewMode && model.mistakeCount > 0) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: Text(locale.reviewMistakesWithCount(model.mistakeCount)),
              onPressed: model.startMistakeReview,
            ),
          ],
        ],
      ),
    );
  }
}
