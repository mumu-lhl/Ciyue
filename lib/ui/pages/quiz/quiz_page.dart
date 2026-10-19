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

  @override
  void initState() {
    super.initState();
    _viewModel = QuizViewModel();
    _viewModel.startQuiz();
  }

  @override
  void dispose() {
    _viewModel.dispose();
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
            title: Text(locale.wordQuiz),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            locale.quizNeedWords,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: model.startQuiz,
            child: Text(locale.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, QuizViewModel model) {
    final question = model.currentQuestion!;
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress
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
          // Word
          Center(
            child: Text(
              question.word,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
                    onTap: showResult
                        ? null
                        : () => model.selectAnswer(index),
                  ),
                );
              },
            ),
          ),
          // Explanation after answering
          if (model.isAnswered && question.explanation.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectionArea(
                child: GptMarkdown(question.explanation),
              ),
            ),
          // Next button
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

  Widget _buildResult(BuildContext context, QuizViewModel model) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;
    final percentage = model.totalQuestions > 0
        ? (model.score / model.totalQuestions * 100).round()
        : 0;

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
          const SizedBox(height: 32),
          FilledButton(
            onPressed: model.restart,
            child: Text(locale.retryQuiz),
          ),
        ],
      ),
    );
  }
}
