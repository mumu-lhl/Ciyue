import "package:ciyue/core/providers.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/desktop_context_menu_script.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Draws the Windows/Linux right-click menu at the pointer.
///
/// [anchorContext] belongs to the WebView: the script reports CSS pixels
/// relative to it, which have to be turned into overlay coordinates before
/// `showMenu` can place the menu under the cursor.
Future<void> showDesktopContextMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  required WidgetRef ref,
  required int? dictId,
  required DesktopContextMenuRequest request,
}) async {
  final word = request.word;
  if (word.isEmpty || !context.mounted) return;
  final anchor = anchorContext.findRenderObject();
  if (anchor is! RenderBox) return;

  final l10n = AppLocalizations.of(context)!;
  final global = anchor.localToGlobal(Offset(request.x, request.y));
  final position = RelativeRect.fromRect(
    global & const Size(40, 40),
    Offset.zero & MediaQuery.sizeOf(context),
  );

  final action = await showMenu<String>(
    context: context,
    position: position,
    items: [
      PopupMenuItem(value: "lookup", child: Text(l10n.lookup)),
      PopupMenuItem(value: "lookupInNewTab", child: Text(l10n.lookupInNewTab)),
      const PopupMenuDivider(),
      PopupMenuItem(value: "copy", child: Text(l10n.copy)),
      PopupMenuItem(value: "readAloud", child: Text(l10n.readLoudly)),
    ],
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case "lookup":
      handleOpenWordNavigation(context, word, newTab: false, dictId: dictId);
    case "lookupInNewTab":
      handleOpenWordNavigation(context, word, newTab: true, dictId: dictId);
    case "copy":
      await Clipboard.setData(ClipboardData(text: word));
    case "readAloud":
      await playSoundOfWord(word, ref.read(audioModelProvider).mddAudioList);
  }
}
