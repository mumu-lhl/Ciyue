import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/text_buttons.dart";
import "package:ciyue/ui/core/word_display.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

class SearchWordDialog extends ConsumerStatefulWidget {
  const SearchWordDialog({super.key});

  @override
  ConsumerState<SearchWordDialog> createState() => _SearchWordDialogState();
}

class _SearchWordDialogState extends ConsumerState<SearchWordDialog> {
  final _searchController = TextEditingController();
  late final WordbookModel _model;

  @override
  void initState() {
    super.initState();
    _model = ref.read(wordbookModelProvider);
    _searchController.addListener(() {
      _model.search(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Search"),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Search",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
              ),
            ),
            CheckboxListTile(
              title: const Text("Fuzzy search"),
              value: _model.fuzzySearch,
              onChanged: (value) {
                _model.toggleFuzzySearch();
                _model.search(_searchController.text);
                setState(() {});
              },
            ),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final model = ref.watch(wordbookModelProvider);
                  if (model.searchResults.isEmpty &&
                      _searchController.text.isNotEmpty) {
                    return const Center(child: Text("No results found"));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: model.searchResults.length,
                    itemBuilder: (context, index) {
                      final word = model.searchResults[index];
                      return ListTile(
                        title: Text(word),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(
                            "/word/${Uri.encodeComponent(word)}",
                            extra: WordListContext(
                              words: List<String>.from(model.searchResults),
                              initialIndex: index,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextCloseButton()],
    );
  }
}

class MonthPickerDialog extends ConsumerStatefulWidget {
  const MonthPickerDialog({super.key});

  @override
  ConsumerState<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends ConsumerState<MonthPickerDialog> {
  late int selectedYear;
  late int selectedMonth;
  late final int initialYear;

  @override
  void initState() {
    super.initState();
    final initialDate =
        ref.read(wordbookModelProvider).selectedDate ?? DateTime.now();
    selectedYear = initialDate.year;
    selectedMonth = initialDate.month;
    initialYear = initialDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: 300,
        height: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  onPressed: () {
                    setState(() {
                      selectedYear--;
                    });
                  },
                ),
                Text(
                  selectedYear.toString(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: () {
                    setState(() {
                      selectedYear++;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pop(DateTime(selectedYear, month));
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            initialYear == selectedYear &&
                                month == selectedMonth
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          month.toString(),
                          style: TextStyle(
                            color:
                                initialYear == selectedYear &&
                                    month == selectedMonth
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MoreOptionsDialog extends ConsumerStatefulWidget {
  const MoreOptionsDialog({super.key});

  @override
  ConsumerState<MoreOptionsDialog> createState() => _MoreOptionsDialogState();
}

class _MoreOptionsDialogState extends ConsumerState<MoreOptionsDialog> {
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(AppLocalizations.of(context)!.more),
      children: [
        SimpleDialogOption(
          child: CheckboxListTile(
            value: settings.skipTaggedWord,
            onChanged: (value) async {
              if (value != null) {
                settings.skipTaggedWord = value;
                await prefs.setBool("skipTaggedWord", value);
                setState(() {});
                if (mounted) {
                  final wordbookModel = ref.read(wordbookModelProvider);
                  wordbookModel.updateWordList();
                }
              }
            },
            title: Text(AppLocalizations.of(context)!.skipTaggedWord),
          ),
        ),
      ],
    );
  }
}

class TagListDialog extends ConsumerStatefulWidget {
  final List<WordbookTag> tagsDisplay;
  final Future<void> Function(BuildContext context) buildAddTag;

  const TagListDialog({
    super.key,
    required this.tagsDisplay,
    required this.buildAddTag,
  });

  @override
  ConsumerState<TagListDialog> createState() => _TagListDialogState();
}

class _TagListDialogState extends ConsumerState<TagListDialog> {
  @override
  Widget build(BuildContext context) {
    final model = ref.read(wordbookModelProvider);
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.tagList),
      content: SizedBox(
        height: 300,
        width: 300,
        child: ReorderableListView(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          onReorderItem: (oldIndex, newIndex) async {
            await model.reorderTags(oldIndex, newIndex, widget.tagsDisplay);
            setState(() {});
          },
          children: widget.tagsDisplay
              .map(
                (tag) => ListTile(
                  key: ValueKey(tag.id),
                  title: Text(tag.tag),
                  leading: ReorderableDragStartListener(
                    index: widget.tagsDisplay.indexOf(tag),
                    child: const Icon(Icons.drag_handle),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await model.removeTag(tag.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        model.showTagsListDialog(context);
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextCloseButton(),
        TextButton(
          child: Text(AppLocalizations.of(context)!.add),
          onPressed: () async {
            context.pop();
            await widget.buildAddTag(context);
          },
        ),
      ],
    );
  }
}
