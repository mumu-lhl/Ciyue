import "package:ciyue/database/app/app.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/history_page.dart";
import "package:ciyue/viewModels/translate_history_view_model.dart";
import "package:material_ui/material_ui.dart";
import "package:intl/intl.dart";

class TranslateHistoryPage extends StatefulWidget {
  const TranslateHistoryPage({super.key});

  @override
  State<TranslateHistoryPage> createState() => _TranslateHistoryPageState();
}

class _TranslateHistoryPageState extends State<TranslateHistoryPage> {
  late final TranslateHistoryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = TranslateHistoryViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HistoryPage<TranslateHistoryData, TranslateHistoryViewModel>(
      title: l10n.translationHistory,
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

  final TranslateHistoryData item;
  final TranslateHistoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isSelecting = viewModel.isSelecting;
    final isSelected = viewModel.selectedIds.contains(item.id);

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
        subtitle: Text(
          DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
              .add_jm()
              .format(item.createdAt),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.grey),
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
