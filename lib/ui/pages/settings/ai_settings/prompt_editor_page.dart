import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "prompts_page.dart" show promptTitle, promptHelper;

/// Full-screen editor for a single prompt: the text field gets the
/// whole page instead of a slice of the AI Settings scroll view,
/// variables are tap-to-insert chips instead of a line of small
/// print to memorize, and the default text is one tap away when
/// deciding whether to keep an edit or reset.
class PromptEditorPage extends ConsumerStatefulWidget {
  const PromptEditorPage({super.key, required this.definition});

  final AiPromptDefinition definition;

  @override
  ConsumerState<PromptEditorPage> createState() => _PromptEditorPageState();
}

class _PromptEditorPageState extends ConsumerState<PromptEditorPage> {
  late final TextEditingController _controller;
  bool _showDefault = false;

  AiPromptDefinition get _definition => widget.definition;

  bool get _customized => _controller.text != _definition.defaultText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(aiPromptsProvider).promptFor(_definition),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(aiPromptsProvider).setPrompt(_definition, value);
    setState(() {});
  }

  void _insertVariable(String variable) {
    final selection = _controller.selection;
    final text = _controller.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final newText = text.replaceRange(start, end, variable);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + variable.length),
    );
    _onChanged(newText);
  }

  Future<void> _reset() async {
    await ref.read(aiPromptsProvider).resetPrompt(_definition);
    _controller.text = _definition.defaultText;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(promptTitle(locale, _definition)),
        actions: [
          if (_customized)
            IconButton(
              tooltip: locale.resetToDefault,
              icon: const Icon(Icons.restart_alt),
              onPressed: _reset,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promptHelper(locale, _definition),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  locale.insertVariableHint,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final variable in _definition.variables)
                      ActionChip(
                        label: Text(
                          variable,
                          style: const TextStyle(fontFamily: "monospace"),
                        ),
                        onPressed: () => _insertVariable(variable),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onChanged,
                  ),
                ),
                if (_customized) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => _showDefault = !_showDefault),
                    child: Row(
                      children: [
                        Icon(
                          _showDefault ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          locale.viewDefaultPrompt,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showDefault)
                    Container(
                      height: 180,
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _definition.defaultText,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
