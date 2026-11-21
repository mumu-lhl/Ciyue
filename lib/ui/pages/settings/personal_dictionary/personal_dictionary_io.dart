import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:file_selector/file_selector.dart";
import "package:material_ui/material_ui.dart";

/// Whether an import result means nothing was imported because the file
/// itself had no content: the service-level [isEmptyInput] signal (P2-17).
/// A zero import for any other reason — metadata-only file, or every entry
/// skipped with warnings — is not an empty file, so it keeps the counted
/// "Imported 0 entries" message (and the warnings dialog explains the
/// skips when there are any).
bool isEmptyPersonalDictionaryImport(PersonalDslImportResult result) =>
    result.isEmptyInput;

/// Whether an export holds no entries at all: `exportDsl` writes nothing
/// for an empty dictionary, so an empty (or whitespace-only) document is
/// the empty-dictionary signal.
bool isEmptyPersonalDictionaryExport(String dsl) => dsl.trim().isEmpty;

String _sanitizeFileName(String name) {
  final sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), "_");
  final trimmed = sanitized.trim();
  return trimmed.isEmpty ? "dictionary" : trimmed;
}

/// Picks a `.dsl` / `.dsl.dz` file and imports it into [dictionaryId].
///
/// Shows a toast with the imported count, and an info dialog listing any
/// warnings the importer reported. Failures surface as an error toast.
Future<void> importPersonalDictionaryDsl(
  BuildContext context,
  PersonalDictionaryService service,
  int dictionaryId,
) async {
  const typeGroup = XTypeGroup(label: "dsl", extensions: <String>["dsl", "dz"]);
  final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
  if (xFile == null) return;
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  late final PersonalDslImportResult result;
  try {
    result = await service.importDslBytes(
      dictionaryId,
      await xFile.readAsBytes(),
      xFile.name,
    );
  } catch (e, stackTrace) {
    talker.error(
      "Failed to import DSL into dictionary $dictionaryId",
      e,
      stackTrace,
    );
    if (context.mounted) {
      unawaited(
        ToastService.show(
          l10n.personalDictionaryOperationFailed,
          context,
          type: ToastType.error,
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;
  // An empty file imports zero entries with no warnings: say it is empty
  // instead of showing the same "Imported 0 entries" as a real import.
  unawaited(
    ToastService.show(
      isEmptyPersonalDictionaryImport(result)
          ? l10n.personalDictionaryImportEmpty
          : l10n.personalDictionaryImportDone(result.imported),
      context,
    ),
  );

  if (result.warnings.isNotEmpty) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.personalDictionaryImportWarnings),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final warning in result.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text("• ${warning.message(l10n)}"),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

/// Exports [dictionaryId] as DSL text and saves it through the platform
/// file-save flow the app already uses for exports: `file_selector`'s save
/// dialog on desktop, the native create-file flow on Android.
Future<void> exportPersonalDictionaryDsl(
  BuildContext context,
  PersonalDictionaryService service,
  int dictionaryId,
  String name,
) async {
  final l10n = AppLocalizations.of(context)!;
  late final String dsl;
  try {
    dsl = await service.exportDsl(dictionaryId);
  } catch (e, stackTrace) {
    talker.error(
      "Failed to export DSL from dictionary $dictionaryId",
      e,
      stackTrace,
    );
    if (context.mounted) {
      unawaited(
        ToastService.show(
          l10n.personalDictionaryOperationFailed,
          context,
          type: ToastType.error,
        ),
      );
    }
    return;
  }

  // An empty dictionary exports to an empty file: warn first instead of
  // silently saving nothing and reporting success. This is the app's
  // usual confirm-dialog shape (Cancel / go ahead), so the user can
  // still export the empty file on purpose.
  if (isEmptyPersonalDictionaryExport(dsl)) {
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.personalDictionaryExportDsl),
        content: Text(l10n.personalDictionaryExportEmpty),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.personalDictionaryExportDsl),
          ),
        ],
      ),
    );
    if (proceed != true) return;
  }

  try {
    if (isDesktop()) {
      final location = await getSaveLocation(
        suggestedName: "${_sanitizeFileName(name)}.dsl",
      );
      // The user cancelled the save dialog.
      if (location == null) return;
      await File(location.path).writeAsString(dsl);
    } else {
      await PlatformMethod.createFile(dsl);
    }
  } catch (e, stackTrace) {
    talker.error(
      "Failed to save DSL export for dictionary $dictionaryId",
      e,
      stackTrace,
    );
    if (context.mounted) {
      unawaited(
        ToastService.show(
          l10n.personalDictionaryOperationFailed,
          context,
          type: ToastType.error,
        ),
      );
    }
    return;
  }

  if (context.mounted) {
    unawaited(ToastService.show(l10n.personalDictionaryExported, context));
  }
}
