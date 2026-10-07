import "package:ciyue/core/providers.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";

class LookupMenuItem extends ContextMenuButtonItem {
  LookupMenuItem({required BuildContext context, required String textToLookup})
    : super(
        label: AppLocalizations.of(context)!.lookup,
        onPressed: () async {
          final String text = textToLookup;
          if (text.isNotEmpty && context.mounted) {
            context.push("/word/${Uri.encodeComponent(text)}");
          }
          ContextMenuController.removeAny();
        },
      );
}

class ReadLoudlyMenuItem extends ContextMenuButtonItem {
  ReadLoudlyMenuItem({
    required BuildContext context,
    required String textToRead,
  }) : super(
         label: AppLocalizations.of(context)!.readLoudly,
         onPressed: () async {
           final String text = textToRead;
           if (text.isNotEmpty) {
             await playSoundOfWord(
               text,
               ProviderScope.containerOf(
                 context,
                 listen: false,
               ).read(audioModelProvider).mddAudioList,
             );
           }
           ContextMenuController.removeAny();
         },
       );
}

/// It reads the currently selected text; if empty, falls back to [fallbackText].
AdaptiveTextSelectionToolbar Function(
  BuildContext context,
  SelectableRegionState selectableRegionState,
)
buildCustomContextMenu({required String fallbackText}) {
  return (BuildContext context, SelectableRegionState selectableRegionState) {
    final defaultItems = selectableRegionState.contextMenuButtonItems;

    String text = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(selectionTextViewModelProvider).selectedText;
    if (text.isEmpty) {
      text = fallbackText;
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: [
        ...defaultItems,
        LookupMenuItem(context: context, textToLookup: text),
        ReadLoudlyMenuItem(context: context, textToRead: text),
      ],
    );
  };
}

/// EditableText/TextField variant of the context menu builder to keep code reuse.
/// It adapts to EditableTextState and computes selection text,
/// falling back to [fallbackText] when needed.
EditableTextContextMenuBuilder buildEditableTextCustomContextMenu({
  required String fallbackText,
}) {
  return (BuildContext context, EditableTextState editableTextState) {
    final value = editableTextState.textEditingValue;
    final selection = value.selection;
    final selected = selection.isValid ? selection.textInside(value.text) : "";

    final defaultItems = editableTextState.contextMenuButtonItems;

    final text = selected.isNotEmpty ? selected : fallbackText;

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ...defaultItems,
        LookupMenuItem(context: context, textToLookup: text),
        ReadLoudlyMenuItem(context: context, textToRead: text),
      ],
    );
  };
}
