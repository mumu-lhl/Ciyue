import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/history_page.dart";
import "package:ciyue/viewModels/writing_check_history.dart";
import "package:material_ui/material_ui.dart";
import "package:intl/intl.dart";

class WritingCheckHistoryPage extends StatefulWidget {
  const WritingCheckHistoryPage({super.key});

  @override
  State<WritingCheckHistoryPage> createState() =>
      _WritingCheckHistoryPageState();
}

class _WritingCheckHistoryPageState extends State<WritingCheckHistoryPage> {
  late final WritingCheckHistoryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = WritingCheckHistoryViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HistoryPage<WritingCheckHistoryData, WritingCheckHistoryViewModel>(
      title: l10n.writingCheckHistory,
      viewModel: _viewModel,
      itemBuilder: (context, item, viewModel) {
        return _HistoryListItem(
          key: ValueKey(item.id),
          item: item,
          viewModel: viewModel,
        );
      },
    );
  }
}

class _HistoryListItem extends StatelessWidget {
  const _HistoryListItem({
    super.key,
    required this.item,
    required this.viewModel,
  });

  final WritingCheckHistoryData item;
  final WritingCheckHistoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isSelected = viewModel.selectedIds.contains(item.id);
    final isSelecting = viewModel.isSelecting;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        title: Text(
          item.inputText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.outputText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            SizedBox(height: 4.0),
            Text(
              DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                  .add_jm()
                  .format(item.createdAt),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          if (isSelecting) {
            viewModel.toggleSelection(item.id);
          } else {
            Navigator.of(context).pop(item);
          }
        },
        onLongPress: () {
          viewModel.toggleSelection(item.id);
        },
        trailing: isSelecting
            ? Checkbox(
                value: isSelected,
                onChanged: (value) {
                  viewModel.toggleSelection(item.id);
                },
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  viewModel.deleteHistory(item.id);
                },
              ),
      ),
    );
  }
}
