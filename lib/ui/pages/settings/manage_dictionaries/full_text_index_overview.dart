import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/full_text_index_section.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart";

/// One row per dictionary with its full-text index status and the same
/// management actions as the properties page (build, cancel, rebuild,
/// delete), so the indexes can be seen and maintained in one place
/// without visiting each dictionary's properties page.
class FullTextIndexOverviewPage extends ConsumerWidget {
  const FullTextIndexOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dictionaries = ref.watch(
      manageDictionariesModelProvider.select((model) => model.dictionaries),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fullTextIndexOverview)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: FutureBuilder<List<DictionaryListData>>(
            future: dictionaries,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final dicts = snapshot.data!;
              if (dicts.isEmpty) {
                return Center(child: Text(l10n.empty));
              }
              return ListView(
                children: [
                  for (final dictionary in dicts)
                    FullTextIndexSection(
                      key: ValueKey(dictionary.id),
                      path: dictionary.path,
                      id: dictionary.id,
                      title: dictionary.title != null && dictionary.title != ""
                          ? dictionary.title
                          : basename(dictionary.path),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
