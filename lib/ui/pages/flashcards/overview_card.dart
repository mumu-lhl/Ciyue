import "package:ciyue/ui/pages/flashcards/providers.dart";
import "package:material_ui/material_ui.dart";
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
        final theme = Theme.of(context);
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's review",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${data.due} due · ${data.newCards} new · ${data.done} done",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: data.due + data.newCards == 0
                      ? null
                      : () => context.push(
                          "/flashcards/review${tag == null ? "" : "?tag=$tag"}",
                        ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
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
