import "dart:io";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:ciyue/viewModels/storage_management.dart";
import "package:path/path.dart" as p;

class StorageManagementPage extends StatelessWidget {
  const StorageManagementPage({super.key});

  Future<void> _confirmAndDelete(
      BuildContext context, FileSystemEntity entity) async {
    final locale = AppLocalizations.of(context)!;
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(locale.confirmDelete),
              content:
                  Text(locale.confirmDeleteMessage(p.basename(entity.path))),
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
      final viewModel =
          Provider.of<StorageManagementViewModel>(context, listen: false);
      final success = await viewModel.deleteEntity(entity);
      if (!success && viewModel.errorMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(viewModel.errorMessage!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(locale.manageStorage),
      ),
      body: Consumer<StorageManagementViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (viewModel.errorMessage != null) {
            return Center(child: Text(viewModel.errorMessage!));
          }
          return ListView.builder(
            itemCount: viewModel.entities.length +
                (viewModel.isAtBaseDirectory ? 0 : 1),
            itemBuilder: (context, index) {
              if (!viewModel.isAtBaseDirectory && index == 0) {
                return ListTile(
                  leading: const Icon(Icons.arrow_back),
                  title: Text(locale.back),
                  onTap: viewModel.navigateBack,
                );
              }
              final actualIndex =
                  viewModel.isAtBaseDirectory ? index : index - 1;
              final entity = viewModel.entities[actualIndex];
              final isDirectory = entity is Directory;
              return ListTile(
                leading:
                    Icon(isDirectory ? Icons.folder : Icons.insert_drive_file),
                title: Text(p.basename(entity.path)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmAndDelete(context, entity),
                ),
                onTap: isDirectory
                    ? () => viewModel.navigateToDirectory(entity)
                    : null, // No action for files
              );
            },
          );
        },
      ),
    );
  }
}
