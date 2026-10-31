import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";

/// What the "not found" page offers instead of a dead end.
///
/// Four groups, each with a quiet heading: the headwords a phrase may be
/// hiding, readings of the query as several headwords (`Anime + Cover`,
/// `倾奇 + 者`), the hiragana spelling of a katakana word's long vowels
/// (`フーゾク` -> `ふうぞく`), and the words the morphology engine believes the
/// query was meant to be. Every entry is a chip that opens the word, so a
/// compound can be read one part at a time.
class MissingWordSuggestionsView extends StatelessWidget {
  final MissingWordSuggestions suggestions;

  /// Called with the word behind the tapped chip.
  final void Function(String word) onSelected;

  const MissingWordSuggestionsView({
    super.key,
    required this.suggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    // Everything the dictionaries can answer on their own comes first, with
    // spelling suggestions below. The groups above arrive in a few milliseconds
    // against Hunspell's hundreds, so the group that fills in last cannot push
    // the ones the user is already reading off the screen.
    return Column(
      children: [
        if (suggestions.phrases.isNotEmpty) ...[
          _Heading(text: l10n.phraseSuggestions),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final phrase in suggestions.phrases)
                _Chip(word: phrase, onSelected: onSelected),
            ],
          ),
        ],
        if (suggestions.splits.isNotEmpty) ...[
          _Heading(text: l10n.wordParts),
          for (final split in suggestions.splits)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < split.parts.length; i++) ...[
                    if (i > 0) const Text("+"),
                    _Chip(word: split.parts[i], onSelected: onSelected),
                  ],
                ],
              ),
            ),
        ],
        if (suggestions.longVowelReadings.isNotEmpty) ...[
          _Heading(text: l10n.longVowelReadings),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in suggestions.longVowelReadings)
                _Chip(word: word, onSelected: onSelected),
            ],
          ),
        ],
        if (suggestions.spellingSuggestions.isNotEmpty) ...[
          _Heading(text: l10n.spellingSuggestions),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in suggestions.spellingSuggestions)
                _Chip(word: word, onSelected: onSelected),
            ],
          ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.secondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String word;
  final void Function(String word) onSelected;

  const _Chip({required this.word, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(word), onPressed: () => onSelected(word));
  }
}
