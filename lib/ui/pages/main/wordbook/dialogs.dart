import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/text_buttons.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

class SearchWordDialog extends StatefulWidget {
  const SearchWordDialog({super.key});

  @override
  State<SearchWordDialog> createState() => _SearchWordDialogState();
}

class _SearchWordDialogState extends State<SearchWordDialog> {
  final _searchController = TextEditingController();
  late final WordbookModel _model;

  @override
  void initState() {
    super.initState();
    _model = context.read<WordbookModel>();
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
              child: Consumer<WordbookModel>(
                builder: (context, model, child) {
                  if (model.searchResults.isEmpty &&
                      _searchController.text.isNotEmpty) {
                    return const Center(
                      child: Text("No results found"),
                    );
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
                          context.push("/word/${Uri.encodeComponent(word)}");
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
      actions: [
        TextCloseButton(),
      ],
    );
  }
}

class MonthPickerDialog extends StatefulWidget {
  const MonthPickerDialog({super.key});

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int selectedYear;
  late int selectedMonth;
  late final int initialYear;

  @override
  void initState() {
    super.initState();
    final initialDate =
        context.read<WordbookModel>().selectedDate ?? DateTime.now();
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
                      Navigator.of(context).pop(
                        DateTime(selectedYear, month),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: initialYear == selectedYear &&
                                month == selectedMonth
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          month.toString(),
                          style: TextStyle(
                            color: initialYear == selectedYear &&
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

class MoreOptionsDialog extends StatefulWidget {
  const MoreOptionsDialog({super.key});

  @override
  State<MoreOptionsDialog> createState() => _MoreOptionsDialogState();
}

class _MoreOptionsDialogState extends State<MoreOptionsDialog> {
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
                if (context.mounted) {
                  final wordbookModel = context.read<WordbookModel>();
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

class TagListDialog extends StatefulWidget {
  final List<WordbookTag> tagsDisplay;
  final Future<void> Function(BuildContext context) buildAddTag;

  const TagListDialog({
    super.key,
    required this.tagsDisplay,
    required this.buildAddTag,
  });

  @override
  State<TagListDialog> createState() => _TagListDialogState();
}

class _TagListDialogState extends State<TagListDialog> {
  @override
  Widget build(BuildContext context) {
    final model = context.read<WordbookModel>();
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.tagList),
      content: SizedBox(
        height: 300,
        width: 300,
        child: ReorderableListView(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          onReorder: (oldIndex, newIndex) async {
            await model.reorderTags(oldIndex, newIndex, widget.tagsDisplay);
            setState(() {});
          },
          children: widget.tagsDisplay
              .map((tag) => ListTile(
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
                  ))
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
