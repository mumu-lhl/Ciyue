import "package:ciyue/ui/pages/flashcards/providers.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

class FlashcardOverviewCard extends ConsumerWidget {
  final int? tag;

  const FlashcardOverviewCard({super.key, this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(flashcardOverviewProvider(tag));
    return overview.when(
      data: (data) {
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's review",
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                          "${data.due} due · ${data.newCards} new · ${data.done} done"),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: data.due + data.newCards == 0
                      ? null
                      : () => context.push(
                            "/flashcards/review${tag == null ? "" : "?tag=$tag"}",
                          ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Study"),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        margin: EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: ListTile(
          title: const Text("Unable to load flashcards"),
          subtitle: Text("$error"),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(flashcardOverviewProvider(tag)),
          ),
        ),
      ),
    );
  }
}
