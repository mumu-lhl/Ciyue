import "dart:io";

import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

Widget? buildTitle(String word, Settings settings) {
  if (settings.showSearchBarInWordDisplay) {
    return WordSearchBarWithSuggestions(
      word: word,
      controller: SearchController(),
    );
  } else {
    return null;
  }
}

Widget buildWebView(String word, int id, bool isExpansion) {
  return Consumer(
    builder: (context, ref, child) {
      final contentAsync =
          ref.watch(wordContentProvider((word: word, dictId: id)));

      return contentAsync.when(
        data: (content) {
          if (Platform.isAndroid) {
            return WebviewAndroid(
              content: content,
              dictId: id,
              isExpansion: isExpansion,
            );
          } else if (Platform.isWindows || Platform.isLinux) {
            return WebviewWindows(content: content, dictId: id);
          } else {
            return FakeWebViewByAI(html: content);
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      );
    },
  );
}

class KeepAliveWidget extends StatefulWidget {
  final Widget child;

  const KeepAliveWidget({super.key, required this.child});

  @override
  State<KeepAliveWidget> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<KeepAliveWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
