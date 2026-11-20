import 'dart:convert';

import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import '../in_app_webview/in_app_webview_controller.dart';

/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformWebStorageCreationParams] for
/// more information.
class LinuxWebStorageCreationParams extends PlatformWebStorageCreationParams {
  LinuxWebStorageCreationParams({
    required super.localStorage,
    required super.sessionStorage,
  });

  factory LinuxWebStorageCreationParams.fromPlatformWebStorageCreationParams(
    // Recommended placeholder to prevent being broken by platform interface.
    // ignore: avoid_unused_constructor_parameters
    PlatformWebStorageCreationParams params,
  ) {
    return LinuxWebStorageCreationParams(
      localStorage: params.localStorage,
      sessionStorage: params.sessionStorage,
    );
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformWebStorage}
class LinuxWebStorage extends PlatformWebStorage {
  LinuxWebStorage(PlatformWebStorageCreationParams params)
    : super.implementation(
        params is LinuxWebStorageCreationParams
            ? params
            : LinuxWebStorageCreationParams.fromPlatformWebStorageCreationParams(
                params,
              ),
      );

  @override
  PlatformLocalStorage get localStorage => params.localStorage;

  @override
  PlatformSessionStorage get sessionStorage => params.sessionStorage;

  @override
  void dispose() {
    localStorage.dispose();
    sessionStorage.dispose();
  }
}

/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformStorageCreationParams] for
/// more information.
class LinuxStorageCreationParams extends PlatformStorageCreationParams {
  LinuxStorageCreationParams({
    required super.controller,
    required super.webStorageType,
  });

  factory LinuxStorageCreationParams.fromPlatformStorageCreationParams(
    // Recommended placeholder to prevent being broken by platform interface.
    // ignore: avoid_unused_constructor_parameters
    PlatformStorageCreationParams params,
  ) {
    return LinuxStorageCreationParams(
      controller: params.controller,
      webStorageType: params.webStorageType,
    );
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformStorage}
abstract mixin class LinuxStorage implements PlatformStorage {
  @override
  LinuxInAppWebViewController? controller;

  @override
  Future<int?> length() async {
    var result = await controller?.evaluateJavascript(
      source:
          """
    window.$webStorageType.length;
    """,
    );
    return result != null ? int.parse(json.decode(result)) : null;
  }

  @override
  Future<void> setItem({required String key, required dynamic value}) async {
    var encodedValue = json.encode(value);
    await controller?.evaluateJavascript(
      source:
          """
    window.$webStorageType.setItem("$key", ${value is String ? encodedValue : "JSON.stringify($encodedValue)"});
    """,
    );
  }

  @override
  Future<dynamic> getItem({required String key}) async {
    var itemValue = await controller?.evaluateJavascript(
      source:
          """
    window.$webStorageType.getItem("$key");
    """,
    );

    if (itemValue == null) {
      return null;
    }

    try {
      return json.decode(itemValue);
    } catch (e) {}

    return itemValue;
  }

  @override
  Future<void> removeItem({required String key}) async {
    await controller?.evaluateJavascript(
      source:
          """
    window.$webStorageType.removeItem("$key");
    """,
    );
  }

  @override
  Future<List<WebStorageItem>> getItems() async {
    var webStorageItems = <WebStorageItem>[];

    List<Map<dynamic, dynamic>>? items = (await controller?.evaluateJavascript(
      source:
          """
(function() {
  var webStorageItems = [];
  for(var i = 0; i < window.$webStorageType.length; i++){
    var key = window.$webStorageType.key(i);
    webStorageItems.push(
      {
        key: key,
        value: window.$webStorageType.getItem(key)
      }
    );
  }
  return webStorageItems;
})();
    """,
    ))?.cast<Map<dynamic, dynamic>>();

    if (items == null) {
      return webStorageItems;
    }

    for (var item in items) {
      webStorageItems.add(
        WebStorageItem(key: item["key"], value: item["value"]),
      );
    }

    return webStorageItems;
  }

  @override
  Future<void> clear() async {
    await controller?.evaluateJavascript(
      source:
          """
    window.$webStorageType.clear();
    """,
    );
  }

  @override
  Future<String> key({required int index}) async {
    var result = await controller?.evaluateJavascript(
      source:
          """
    window.$webStorageType.key($index);
    """,
    );
    return result != null ? json.decode(result) : null;
  }

  @override
  void dispose() {
    controller = null;
  }
}

/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformLocalStorageCreationParams] for
/// more information.
class LinuxLocalStorageCreationParams
    extends PlatformLocalStorageCreationParams {
  LinuxLocalStorageCreationParams(super.params);

  factory LinuxLocalStorageCreationParams.fromPlatformLocalStorageCreationParams(
    // Recommended placeholder to prevent being broken by platform interface.
    // ignore: avoid_unused_constructor_parameters
    PlatformLocalStorageCreationParams params,
  ) {
    return LinuxLocalStorageCreationParams(params);
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformLocalStorage}
class LinuxLocalStorage extends PlatformLocalStorage with LinuxStorage {
  LinuxLocalStorage(PlatformLocalStorageCreationParams params)
    : super.implementation(
        params is LinuxLocalStorageCreationParams
            ? params
            : LinuxLocalStorageCreationParams.fromPlatformLocalStorageCreationParams(
                params,
              ),
      );

  factory LinuxLocalStorage.defaultStorage({
    required PlatformInAppWebViewController? controller,
  }) {
    return LinuxLocalStorage(
      LinuxLocalStorageCreationParams(
        PlatformLocalStorageCreationParams(
          PlatformStorageCreationParams(
            controller: controller,
            webStorageType: WebStorageType.LOCAL_STORAGE,
          ),
        ),
      ),
    );
  }

  @override
  LinuxInAppWebViewController? get controller =>
      params.controller as LinuxInAppWebViewController?;
}

/// When adding additional fields make sure they can be null or have a default
/// value to avoid breaking changes. See [PlatformSessionStorageCreationParams] for
/// more information.
class LinuxSessionStorageCreationParams
    extends PlatformSessionStorageCreationParams {
  LinuxSessionStorageCreationParams(super.params);

  factory LinuxSessionStorageCreationParams.fromPlatformSessionStorageCreationParams(
    // Recommended placeholder to prevent being broken by platform interface.
    // ignore: avoid_unused_constructor_parameters
    PlatformSessionStorageCreationParams params,
  ) {
    return LinuxSessionStorageCreationParams(params);
  }
}

///{@macro flutter_inappwebview_platform_interface.PlatformSessionStorage}
class LinuxSessionStorage extends PlatformSessionStorage with LinuxStorage {
  LinuxSessionStorage(PlatformSessionStorageCreationParams params)
    : super.implementation(
        params is LinuxSessionStorageCreationParams
            ? params
            : LinuxSessionStorageCreationParams.fromPlatformSessionStorageCreationParams(
                params,
              ),
      );

  factory LinuxSessionStorage.defaultStorage({
    required PlatformInAppWebViewController? controller,
  }) {
    return LinuxSessionStorage(
      LinuxSessionStorageCreationParams(
        PlatformSessionStorageCreationParams(
          PlatformStorageCreationParams(
            controller: controller,
            webStorageType: WebStorageType.SESSION_STORAGE,
          ),
        ),
      ),
    );
  }

  @override
  LinuxInAppWebViewController? get controller =>
      params.controller as LinuxInAppWebViewController?;
}
