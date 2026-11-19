import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:file_selector/file_selector.dart";
import "package:material_ui/material_ui.dart";

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
      ToastService.show(e.toString(), context, type: ToastType.error);
    }
    return;
  }

  if (!context.mounted) return;
  ToastService.show(
    l10n.personalDictionaryImportDone(result.imported),
    context,
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
                  child: Text("• $warning"),
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
      ToastService.show(e.toString(), context, type: ToastType.error);
    }
    return;
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
      ToastService.show(e.toString(), context, type: ToastType.error);
    }
    return;
  }

  if (context.mounted) {
    ToastService.show(l10n.personalDictionaryExported, context);
  }
}
