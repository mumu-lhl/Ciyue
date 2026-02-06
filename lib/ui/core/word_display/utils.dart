import "dart:io";

import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:flutter/material.dart";

Widget? buildTitle(String word) {
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
  return FutureBuilder(
    future: dictManager.dicts[id]!.readWord(word),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        if (Platform.isAndroid) {
          return WebviewAndroid(
              content: snapshot.data!, dictId: id, isExpansion: isExpansion);
        } else if (Platform.isWindows || Platform.isLinux) {
          return WebviewWindows(content: snapshot.data!, dictId: id);
        } else {
          return FakeWebViewByAI(html: snapshot.data!);
        }
      } else {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
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
