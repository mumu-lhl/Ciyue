import "dart:ffi";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/desktop_selection_x11.dart";
import "package:ciyue/services/selection_watcher.dart";
import "package:flutter/foundation.dart";

/// XGetClassHint on a window that vanished raises a fatal X error: the
/// default handler prints it and kills the process. The focused window can
/// disappear between XGetInputFocus and XGetClassHint, so the hint lookup
/// runs under a temporary handler that swallows the error instead — the
/// previous handler is restored before returning, so the toolkit's own
/// error handling is untouched outside this one call.
int _swallowXError(Pointer<Void> display, Pointer<Void> errorEvent) => 0;

/// Resolves the focused application through XGetInputFocus + XGetClassHint.
///
/// Returns the WM_CLASS `res_class` (falling back to `res_name`), e.g.
/// `Org.eu.mumulhl.ciyue` for Ciyue itself. Never throws: an unknown
/// focus, a missing class hint, or any failure is null.
class X11FocusedAppResolver implements FocusedAppResolver {
  const X11FocusedAppResolver();

  /// Whether the resolver can run in this process: libX11 opens and a
  /// display connects. Cached; never throws.
  static bool get isAvailable => X11Bindings.isDisplayAvailable;

  // The native callable for the error handler. Pointer.fromFunction
  // closures are freed with the Pointer, so this is held for the life of
  // the process rather than created per call.
  static final Pointer<
    NativeFunction<Int32 Function(Pointer<Void>, Pointer<Void>)>
  >
  _errorHandler =
      Pointer.fromFunction<Int32 Function(Pointer<Void>, Pointer<Void>)>(
        _swallowXError,
        0,
      );

  @override
  Future<String?> getFocusedAppId() async {
    try {
      final bindings = X11Bindings.instance;
      if (bindings == null) return null;
      final display = bindings.openDisplay(nullptr);
      if (display == nullptr) return null;
      try {
        final focus = bindings.allocUint64();
        final revertTo = bindings.allocInt32();
        try {
          bindings.getInputFocus(display, focus, revertTo);
          final window = focus.value;
          // None (0) and PointerRoot (1) are not windows: asking for a
          // class hint on them is a fatal BadWindow.
          if (window <= 1) return null;
          return _resolveAppId(bindings, display, window);
        } finally {
          bindings.freePointer(focus);
          bindings.freePointer(revertTo);
        }
      } finally {
        bindings.closeDisplay(display);
      }
    } catch (error, stackTrace) {
      talker.error("Failed to resolve the focused app", error, stackTrace);
      return null;
    }
  }

  /// The WM_CLASS of [window], or null when it has none or is already
  /// gone. Exposed for tests: a live focus cannot be pointed at a
  /// destroyed window on demand.
  @visibleForTesting
  Future<String?> getAppIdForWindow(int window) async {
    try {
      final bindings = X11Bindings.instance;
      if (bindings == null) return null;
      final display = bindings.openDisplay(nullptr);
      if (display == nullptr) return null;
      try {
        return _resolveAppId(bindings, display, window);
      } finally {
        bindings.closeDisplay(display);
      }
    } catch (error, stackTrace) {
      talker.error("Failed to resolve the app for a window", error, stackTrace);
      return null;
    }
  }

  /// The WM_CLASS of [window], walking up to the toplevel when the window
  /// itself has none. Toolkits put keyboard focus on the focused widget's
  /// own window (a text field's child window), and only toplevels carry
  /// WM_CLASS — reading the focused window alone therefore reports null
  /// for every real app. Bounded so a pathological parent chain cannot
  /// loop forever; a window that vanishes mid-walk resolves to null
  /// instead of crashing (the swallowing handler from
  /// [_classHintForWindow] covers each step).
  static String? _resolveAppId(
    X11Bindings bindings,
    Pointer<Void> display,
    int window,
  ) {
    var current = window;
    for (var depth = 0; depth < 16; depth++) {
      final appId = _classHintForWindow(bindings, display, current);
      if (appId != null) return appId;
      final parent = _parentWindow(bindings, display, current);
      if (parent == null || parent == 0 || parent == current) return null;
      current = parent;
    }
    return null;
  }

  /// The parent window of [window] via XQueryTree, or null when the query
  /// fails (the window is already gone). The children list XQueryTree
  /// allocates is freed with XFree; the caller only needs the parent.
  static int? _parentWindow(
    X11Bindings bindings,
    Pointer<Void> display,
    int window,
  ) {
    final root = bindings.allocUint64();
    final parent = bindings.allocUint64();
    final children = bindings.allocPointer().cast<Pointer<Uint64>>();
    final nchildren = bindings.allocBytes(4).cast<Uint32>();
    try {
      final previousHandler = bindings.setErrorHandler(
        _errorHandler.cast<Void>(),
      );
      try {
        final status = bindings.queryTree(
          display,
          window,
          root,
          parent,
          children,
          nchildren,
        );
        // Force delivery of any error the request raised while the
        // swallowing handler is still installed.
        bindings.sync(display, 0);
        if (status == 0) return null;
      } finally {
        bindings.setErrorHandler(previousHandler);
      }
      final childrenList = children.value;
      if (childrenList != nullptr) bindings.free(childrenList.cast<Void>());
      return parent.value;
    } finally {
      bindings.freePointer(root);
      bindings.freePointer(parent);
      bindings.freePointer(children);
      bindings.freePointer(nchildren);
    }
  }

  static String? _classHintForWindow(
    X11Bindings bindings,
    Pointer<Void> display,
    int window,
  ) {
    // XClassHint is two char*: res_name, then res_class.
    final hint = bindings.allocBytes(16);
    try {
      final previousHandler = bindings.setErrorHandler(
        _errorHandler.cast<Void>(),
      );
      try {
        final status = bindings.getClassHint(
          display,
          window,
          hint.cast<Void>(),
        );
        // Force delivery of any error the request raised while the
        // swallowing handler is still installed.
        bindings.sync(display, 0);
        if (status == 0) return null;
      } finally {
        bindings.setErrorHandler(previousHandler);
      }
      final name = hint.cast<Pointer<Void>>()[0];
      final classHint = hint.cast<Pointer<Void>>()[1];
      try {
        final resClass = X11Bindings.readCString(classHint).trim();
        if (resClass.isNotEmpty) return resClass;
        final resName = X11Bindings.readCString(name).trim();
        return resName.isEmpty ? null : resName;
      } finally {
        if (name != nullptr) bindings.free(name);
        if (classHint != nullptr) bindings.free(classHint);
      }
    } finally {
      bindings.freePointer(hint);
    }
  }
}
