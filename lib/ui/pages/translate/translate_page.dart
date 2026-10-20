import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/tts.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/language_picker.dart";
import "package:ciyue/ui/core/custom_context_menu.dart";
import "package:ciyue/ui/pages/translate/translate_history_page.dart";
import "package:ciyue/ui/pages/translate/translate_settings_page.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/viewModels/translate_view_model.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:gpt_markdown/gpt_markdown.dart";

class AiTranslatePage extends StatefulWidget {
  const AiTranslatePage({super.key});

  @override
  State<AiTranslatePage> createState() => _AiTranslatePageState();
}

class _AiTranslatePageState extends State<AiTranslatePage> {
  late final AiTranslateViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AiTranslateViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final viewModel = _viewModel;
        return Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: AppLocalizations.of(context)!.translationHistory,
                onPressed: () async {
                  final result = await Navigator.push<TranslateHistoryData>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TranslateHistoryPage(),
                    ),
                  );
                  if (result != null) {
                    viewModel.inputController.text = result.inputText;
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: AppLocalizations.of(context)!.settings,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AiTranslateSettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: isLargeScreen(context)
                ? _DesktopTranslateView(
                    viewModel: viewModel,
                    onSourceTap: () =>
                        _showLanguagePicker(context, viewModel, true),
                    onTargetTap: () =>
                        _showLanguagePicker(context, viewModel, false),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _InputSection(
                                inputController: viewModel.inputController,
                              ),
                              _LanguageSelectionRow(
                                sourceLanguage: viewModel.sourceLanguage,
                                targetLanguage: viewModel.targetLanguage,
                                getLanguageName: viewModel.getLanguageName,
                                onSwap: viewModel.swapLanguages,
                                onSourceTap: () => _showLanguagePicker(
                                  context,
                                  viewModel,
                                  true,
                                ),
                                onTargetTap: () => _showLanguagePicker(
                                  context,
                                  viewModel,
                                  false,
                                ),
                              ),
                              _TranslateButton(
                                onPressed:
                                    viewModel.inputController.text.isEmpty
                                    ? null
                                    : () => viewModel.translateText(context),
                              ),
                            ]),
                          ),
                        ),
                        _ResultsSliver(viewModel: viewModel),
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 16),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    AiTranslateViewModel viewModel,
    bool isSource,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: LanguagePicker(
          selectedLanguage: isSource
              ? viewModel.sourceLanguage
              : viewModel.targetLanguage,
          onLanguageSelected: (languageCode) {
            if (isSource) {
              viewModel.setSourceLanguage(languageCode);
            } else {
              viewModel.setTargetLanguage(languageCode);
            }
            Navigator.pop(context);
          },
          isSource: isSource,
        ),
      ),
    );
  }
}

/// The list of per-source result cards (+ skipped-source hints).
class _ResultsSliver extends StatelessWidget {
  const _ResultsSliver({required this.viewModel});
  final AiTranslateViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hasTranslated) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          for (final entry in viewModel.results)
            _SourceResultCard(entry: entry),
          if (viewModel.skippedSources.isNotEmpty)
            _SkippedSourcesHint(viewModel: viewModel),
        ]),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.viewModel});
  final AiTranslateViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hasTranslated) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.translation,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      children: [
        for (final entry in viewModel.results) _SourceResultCard(entry: entry),
        if (viewModel.skippedSources.isNotEmpty)
          _SkippedSourcesHint(viewModel: viewModel),
      ],
    );
  }
}

/// One translation source's result card: header (source badge + name +
/// actions), body (loading shimmer / result / error), alternatives.
class _SourceResultCard extends StatelessWidget {
  const _SourceResultCard({required this.entry});
  final SourceResult entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;
    final source = entry.source;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: entry.isError
              ? theme.colorScheme.error.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _SourceBadge(name: source.name),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    source.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (entry.status == SourceResultStatus.success) ...[
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: locale.readAloud,
                    icon: const Icon(Icons.volume_up_outlined),
                    onPressed: () => TtsHelper.toggleSpeak(entry.result!.text),
                  ),
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: locale.copy,
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: entry.result!.text),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(locale.copied),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    switch (entry.status) {
      case SourceResultStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              _ShimmerText(),
            ],
          ),
        );
      case SourceResultStatus.error:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.translationFailed,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        );
      case SourceResultStatus.success:
        final result = entry.result!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResultText(entry: entry, text: result.text),
            if (result.alternatives.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final alt in result.alternatives)
                    ActionChip(
                      label: Text(alt),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: alt));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.copied),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        );
    }
  }
}

/// Result text: AI source renders markdown, others plain text with the
/// app's text-selection integration.
class _ResultText extends ConsumerWidget {
  const _ResultText({required this.entry, required this.text});
  final SourceResult entry;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = entry.source.id == "ai"
        ? GptMarkdown(text)
        : Text(text, style: const TextStyle(fontSize: 17, height: 1.45));

    return SelectionArea(
      onSelectionChanged: ref
          .read(selectionTextViewModelProvider)
          .setSelectedText,
      contextMenuBuilder: buildCustomContextMenu(fallbackText: text),
      child: child,
    );
  }
}

/// Colored circular badge with the source's initial.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.name});
  final String name;

  static const _palette = [
    Color(0xFF5B8DEF),
    Color(0xFF34A853),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFE53935),
    Color(0xFF3949AB),
    Color(0xFF6D4C41),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: 14,
      backgroundColor: color.withValues(alpha: 0.16),
      child: Text(
        name.isEmpty ? "?" : name[0].toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ShimmerText extends StatelessWidget {
  const _ShimmerText();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context)!.translating,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Hint listing enabled-but-unconfigured sources, linking to settings.
class _SkippedSourcesHint extends StatelessWidget {
  const _SkippedSourcesHint({required this.viewModel});
  final AiTranslateViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;
    final names = viewModel.skippedSources.map((s) => s.name).join(", ");
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              locale.sourcesNotConfigured(names),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiTranslateSettingsPage(),
                ),
              );
            },
            child: Text(locale.settings),
          ),
        ],
      ),
    );
  }
}

class _InputSection extends StatelessWidget {
  const _InputSection({required this.inputController});

  final TextEditingController inputController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: inputController,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.enterTextToTranslate,
          border: const OutlineInputBorder(),
        ),
        contextMenuBuilder: buildEditableTextCustomContextMenu(
          fallbackText: inputController.text,
        ),
        maxLines: null,
      ),
    );
  }
}

class _LanguageSelectionRow extends StatelessWidget {
  const _LanguageSelectionRow({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.getLanguageName,
    required this.onSwap,
    required this.onSourceTap,
    required this.onTargetTap,
  });

  final String sourceLanguage;
  final String targetLanguage;
  final String Function(String) getLanguageName;
  final VoidCallback onSwap;
  final VoidCallback onSourceTap;
  final VoidCallback onTargetTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LanguageChip(
            languageName: getLanguageName(sourceLanguage) == "Auto Detect"
                ? AppLocalizations.of(context)!.autoDetect
                : getLanguageName(sourceLanguage),
            onTap: onSourceTap,
          ),
          IconButton(icon: const Icon(Icons.swap_horiz), onPressed: onSwap),
          _LanguageChip(
            languageName: getLanguageName(targetLanguage),
            onTap: onTargetTap,
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.languageName, required this.onTap});

  final String languageName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TranslateButton extends StatelessWidget {
  const _TranslateButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.translate_rounded, size: 20),
        onPressed: onPressed,
        label: Text(AppLocalizations.of(context)!.translate),
      ),
    );
  }
}

class _DesktopTranslateView extends StatelessWidget {
  final AiTranslateViewModel viewModel;
  final VoidCallback onSourceTap;
  final VoidCallback onTargetTap;

  const _DesktopTranslateView({
    required this.viewModel,
    required this.onSourceTap,
    required this.onTargetTap,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (viewModel.inputController.text.isNotEmpty) {
            viewModel.translateText(context);
          }
        },
      },
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _LanguageSelectionRow(
              sourceLanguage: viewModel.sourceLanguage,
              targetLanguage: viewModel.targetLanguage,
              getLanguageName: viewModel.getLanguageName,
              onSwap: viewModel.swapLanguages,
              onSourceTap: onSourceTap,
              onTargetTap: onTargetTap,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: viewModel.inputController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.of(context)!
                                      .enterTextToTranslate,
                                  border: InputBorder.none,
                                ),
                                contextMenuBuilder:
                                    buildEditableTextCustomContextMenu(
                                      fallbackText:
                                          viewModel.inputController.text,
                                    ),
                                maxLines: null,
                                expands: true,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (viewModel.inputController.text.isNotEmpty)
                                  IconButton(
                                    tooltip: "Clear",
                                    icon: const Icon(Icons.clear),
                                    onPressed: () =>
                                        viewModel.inputController.clear(),
                                  ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.translate),
                                  label: Text(
                                    "${AppLocalizations.of(context)!.translate} (Ctrl+Enter)",
                                  ),
                                  onPressed:
                                      viewModel.inputController.text.isEmpty
                                      ? null
                                      : () => viewModel.translateText(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _ResultsList(viewModel: viewModel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
