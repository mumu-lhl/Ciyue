import "dart:io";

import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/storage_management.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as p;

class StorageManagementPage extends StatefulWidget {
  const StorageManagementPage({super.key});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  late final StorageManagementViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = StorageManagementViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    FileSystemEntity entity,
  ) async {
    final locale = AppLocalizations.of(context)!;
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(locale.confirmDelete),
              content: Text(
                locale.confirmDeleteMessage(p.basename(entity.path)),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(locale.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(locale.delete),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm && context.mounted) {
      final success = await _viewModel.deleteEntity(entity);
      if (!success && _viewModel.errorMessage != null && context.mounted) {
        ToastService.show(
          _viewModel.errorMessage!,
          context,
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(locale.manageStorage)),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_viewModel.errorMessage != null) {
            return Center(child: Text(_viewModel.errorMessage!));
          }
          return ListView.builder(
            itemCount:
                _viewModel.entities.length +
                (_viewModel.isAtBaseDirectory ? 0 : 1),
            itemBuilder: (context, index) {
              if (!_viewModel.isAtBaseDirectory && index == 0) {
                return ListTile(
                  leading: const Icon(Icons.arrow_back),
                  title: Text(locale.back),
                  onTap: _viewModel.navigateBack,
                );
              }
              final actualIndex = _viewModel.isAtBaseDirectory
                  ? index
                  : index - 1;
              final entity = _viewModel.entities[actualIndex];
              final isDirectory = entity is Directory;
              return ListTile(
                leading: Icon(
                  isDirectory ? Icons.folder : Icons.insert_drive_file,
                ),
                title: Text(p.basename(entity.path)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmAndDelete(context, entity),
                ),
                onTap: isDirectory
                    ? () => _viewModel.navigateToDirectory(entity)
                    : null, // No action for files
              );
            },
          );
        },
      ),
    );
  }
}
