import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/floating_window.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:ciyue/ui/core/word_display/webview_widgets.dart";
import "package:ciyue/utils.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

Widget? buildTitle(
  String word,
  Settings settings, {
  required SearchController controller,
}) {
  if (settings.showSearchBarInWordDisplay) {
    return WordSearchBarWithSuggestions(word: word, controller: controller);
  } else {
    return null;
  }
}

Widget withFloatingWindowBackHandler(BuildContext context, Widget child) {
  final canPop = context.canPop();

  return PopScope(
    canPop: !runningInFloatingWindow || canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && runningInFloatingWindow && !canPop) {
        unawaited(dismissFloatingWindow());
      }
    },
    child: child,
  );
}

Widget buildWebView(String word, int id, bool isExpansion) {
  return _WordContentView(word: word, dictId: id, isExpansion: isExpansion);
}

class _WordContentView extends ConsumerStatefulWidget {
  final String word;
  final int dictId;
  final bool isExpansion;

  const _WordContentView({
    required this.word,
    required this.dictId,
    required this.isExpansion,
  });

  @override
  ConsumerState<_WordContentView> createState() => _WordContentViewState();
}

class _WordContentViewState extends ConsumerState<_WordContentView> {
  String? _lastLinuxContent;

  @override
  void didUpdateWidget(_WordContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dictId != oldWidget.dictId) _lastLinuxContent = null;
  }

  Widget _buildContent(String content) {
    if (Platform.isAndroid) {
      return WebviewAndroid(
        word: widget.word,
        content: content,
        dictId: widget.dictId,
        isExpansion: widget.isExpansion,
      );
    } else if (isDesktop()) {
      return WebviewWindows(content: content, dictId: widget.dictId);
    } else {
      return FakeWebViewByAI(html: content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(
      wordContentProvider((word: widget.word, dictId: widget.dictId)),
    );

    // Keep the Linux platform view mounted while the next word is looked up.
    // Recreating WPEBackend-FDO views can crash the WebProcess and leave a
    // blank texture; WebviewWindows reloads this retained view when content
    // changes.
    if (Platform.isLinux &&
        contentAsync.isLoading &&
        _lastLinuxContent != null) {
      return WebviewWindows(content: _lastLinuxContent!, dictId: widget.dictId);
    }

    return contentAsync.when(
      data: (content) {
        if (Platform.isLinux) _lastLinuxContent = content;
        return _buildContent(content);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error: $err")),
    );
  }
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
