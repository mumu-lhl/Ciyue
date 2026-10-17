import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/flashcards/providers.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class FlashcardSettingsPage extends ConsumerStatefulWidget {
  const FlashcardSettingsPage({super.key});

  @override
  ConsumerState<FlashcardSettingsPage> createState() =>
      _FlashcardSettingsPageState();
}

class _FlashcardSettingsPageState extends ConsumerState<FlashcardSettingsPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(flashcardDailyNewLimitProvider).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.flashcards)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.flashcardsNewCardsPerDay,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              helperText: l10n.flashcardsAllowedRange,
              suffixText: l10n.flashcardsCardsUnit,
            ),
            onSubmitted: (_) => _save(),
            onTapOutside: (_) => _save(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.flashcardsScheduling),
            subtitle: Text(l10n.flashcardsFsrsInfo),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final parsed = int.tryParse(_controller.text) ?? 20;
    final normalized = normalizeFlashcardDailyLimit(parsed);
    _controller.text = normalized.toString();
    await ref
        .read(flashcardDailyNewLimitProvider.notifier)
        .setLimit(normalized);
  }
}
