import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'cookie_manager/cookie_manager.dart';
import 'find_interaction/find_interaction_controller.dart';
import 'http_auth_credentials_database.dart';
import 'in_app_browser/in_app_browser.dart';
import 'in_app_webview/in_app_webview.dart';
import 'in_app_webview/in_app_webview_controller.dart';
import 'in_app_webview/headless_in_app_webview.dart';
import 'proxy_controller/proxy_controller.dart';
import 'web_message/web_message_channel.dart';
import 'web_message/web_message_listener.dart';
import 'web_message/web_message_port.dart';
import 'web_storage/web_storage.dart';
import 'web_storage/web_storage_manager.dart';
import 'webview_environment/webview_environment.dart';

/// Implementation of [InAppWebViewPlatform] using WPE WebKit.
class LinuxInAppWebViewPlatform extends InAppWebViewPlatform {
  static void registerWith() {
    InAppWebViewPlatform.instance = LinuxInAppWebViewPlatform();
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [InAppWebViewController] in `flutter_inappwebview` instead.
  @override
  LinuxInAppWebViewController createPlatformInAppWebViewController(
    PlatformInAppWebViewControllerCreationParams params,
  ) {
    return LinuxInAppWebViewController(params);
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [InAppWebViewController] in `flutter_inappwebview` instead.
  @override
  LinuxInAppWebViewController createPlatformInAppWebViewControllerStatic() {
    return LinuxInAppWebViewController.static();
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [InAppWebView] in `flutter_inappwebview` instead.
  @override
  LinuxInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    return LinuxInAppWebViewWidget(params);
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [InAppWebView] in `flutter_inappwebview` instead.
  @override
  LinuxInAppWebViewWidget createPlatformInAppWebViewWidgetStatic() {
    return LinuxInAppWebViewWidget.static();
  }

  @override
  PlatformCookieManager createPlatformCookieManagerStatic() {
    return LinuxCookieManager.static();
  }

  @override
  LinuxCookieManager createPlatformCookieManager(
    PlatformCookieManagerCreationParams params,
  ) {
    return LinuxCookieManager(params);
  }

  @override
  PlatformWebViewEnvironment createPlatformWebViewEnvironmentStatic() {
    return LinuxWebViewEnvironment.static();
  }

  @override
  LinuxWebViewEnvironment createPlatformWebViewEnvironment(
    PlatformWebViewEnvironmentCreationParams params,
  ) {
    return LinuxWebViewEnvironment(params);
  }

  // ************************************************************************ //
  // Create static instances of unsupported classes to be able to call        //
  // isClassSupported, isMethodSupported, isPropertySupported, etc.           //
  // static methods without throwing a missing platform implementation        //
  // exception.                                                               //
  // ************************************************************************ //

  @override
  PlatformChromeSafariBrowser createPlatformChromeSafariBrowserStatic() {
    return _PlatformChromeSafariBrowser.static();
  }

  @override
  LinuxHttpAuthCredentialDatabase createPlatformHttpAuthCredentialDatabase(
    PlatformHttpAuthCredentialDatabaseCreationParams params,
  ) {
    return LinuxHttpAuthCredentialDatabase(params);
  }

  @override
  LinuxHttpAuthCredentialDatabase
  createPlatformHttpAuthCredentialDatabaseStatic() {
    return LinuxHttpAuthCredentialDatabase.static();
  }

  @override
  LinuxInAppBrowser createPlatformInAppBrowserStatic() {
    return LinuxInAppBrowser.static();
  }

  @override
  LinuxInAppBrowser createPlatformInAppBrowser(
    PlatformInAppBrowserCreationParams params,
  ) {
    return LinuxInAppBrowser(params);
  }

  @override
  PlatformHeadlessInAppWebView createPlatformHeadlessInAppWebViewStatic() {
    return LinuxHeadlessInAppWebView.static();
  }

  @override
  LinuxHeadlessInAppWebView createPlatformHeadlessInAppWebView(
    PlatformHeadlessInAppWebViewCreationParams params,
  ) {
    return LinuxHeadlessInAppWebView(params);
  }

  @override
  PlatformProcessGlobalConfig createPlatformProcessGlobalConfigStatic() {
    return _PlatformProcessGlobalConfig.static();
  }

  @override
  PlatformProxyController createPlatformProxyControllerStatic() {
    return LinuxProxyController.static();
  }

  @override
  LinuxProxyController createPlatformProxyController(
    PlatformProxyControllerCreationParams params,
  ) {
    return LinuxProxyController(params);
  }

  @override
  PlatformServiceWorkerController
  createPlatformServiceWorkerControllerStatic() {
    return _PlatformServiceWorkerController.static();
  }

  @override
  PlatformTracingController createPlatformTracingControllerStatic() {
    return _PlatformTracingController.static();
  }

  @override
  PlatformFindInteractionController
  createPlatformFindInteractionControllerStatic() {
    return LinuxFindInteractionController.static();
  }

  @override
  LinuxFindInteractionController createPlatformFindInteractionController(
    PlatformFindInteractionControllerCreationParams params,
  ) {
    return LinuxFindInteractionController(params);
  }

  @override
  PlatformPrintJobController createPlatformPrintJobControllerStatic() {
    return _PlatformPrintJobController.static();
  }

  @override
  PlatformPullToRefreshController
  createPlatformPullToRefreshControllerStatic() {
    return _PlatformPullToRefreshController.static();
  }

  @override
  PlatformWebAuthenticationSession
  createPlatformWebAuthenticationSessionStatic() {
    return _PlatformWebAuthenticationSession.static();
  }

  @override
  PlatformWebNotificationController
  createPlatformWebNotificationControllerStatic() {
    return _PlatformWebNotificationController.static();
  }

  @override
  LinuxWebMessageChannel createPlatformWebMessageChannelStatic() {
    return LinuxWebMessageChannel.static();
  }

  @override
  LinuxWebMessageChannel createPlatformWebMessageChannel(
    PlatformWebMessageChannelCreationParams params,
  ) {
    return LinuxWebMessageChannel(params);
  }

  @override
  LinuxWebMessagePort createPlatformWebMessagePort(
    PlatformWebMessagePortCreationParams params,
  ) {
    return LinuxWebMessagePort(params);
  }

  @override
  PlatformWebMessageListener createPlatformWebMessageListenerStatic() {
    return LinuxWebMessageListener.static();
  }

  @override
  LinuxWebMessageListener createPlatformWebMessageListener(
    PlatformWebMessageListenerCreationParams params,
  ) {
    return LinuxWebMessageListener(params);
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [WebStorage] in `flutter_inappwebview` instead.
  @override
  LinuxWebStorage createPlatformWebStorage(
    PlatformWebStorageCreationParams params,
  ) {
    return LinuxWebStorage(params);
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [WebStorage] in `flutter_inappwebview` instead.
  @override
  LinuxWebStorage createPlatformWebStorageStatic() {
    return LinuxWebStorage(
      LinuxWebStorageCreationParams(
        localStorage: createPlatformLocalStorageStatic(),
        sessionStorage: createPlatformSessionStorageStatic(),
      ),
    );
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [LocalStorage] in `flutter_inappwebview` instead.
  @override
  LinuxLocalStorage createPlatformLocalStorage(
    PlatformLocalStorageCreationParams params,
  ) {
    return LinuxLocalStorage(params);
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [LocalStorage] in `flutter_inappwebview` instead.
  @override
  LinuxLocalStorage createPlatformLocalStorageStatic() {
    return LinuxLocalStorage.defaultStorage(controller: null);
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [SessionStorage] in `flutter_inappwebview` instead.
  @override
  LinuxSessionStorage createPlatformSessionStorage(
    PlatformSessionStorageCreationParams params,
  ) {
    return LinuxSessionStorage(params);
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [SessionStorage] in `flutter_inappwebview` instead.
  @override
  LinuxSessionStorage createPlatformSessionStorageStatic() {
    return LinuxSessionStorage.defaultStorage(controller: null);
  }

  @override
  PlatformWebStorageManager createPlatformWebStorageManagerStatic() {
    return LinuxWebStorageManager.static();
  }

  @override
  LinuxWebStorageManager createPlatformWebStorageManager(
    PlatformWebStorageManagerCreationParams params,
  ) {
    return LinuxWebStorageManager(params);
  }

  @override
  PlatformAssetsPathHandler createPlatformAssetsPathHandlerStatic() {
    return _PlatformAssetsPathHandler.static();
  }

  @override
  PlatformResourcesPathHandler createPlatformResourcesPathHandlerStatic() {
    return _PlatformResourcesPathHandler.static();
  }

  @override
  PlatformInternalStoragePathHandler
  createPlatformInternalStoragePathHandlerStatic() {
    return _PlatformInternalStoragePathHandler.static();
  }

  @override
  PlatformCustomPathHandler createPlatformCustomPathHandlerStatic() {
    return _PlatformCustomPathHandler.static();
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [InAppLocalhostServer] in `flutter_inappwebview` instead.
  @override
  DefaultInAppLocalhostServer createPlatformInAppLocalhostServer(
    PlatformInAppLocalhostServerCreationParams params,
  ) {
    return DefaultInAppLocalhostServer(params);
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [InAppLocalhostServer] in `flutter_inappwebview` instead.
  @override
  DefaultInAppLocalhostServer createPlatformInAppLocalhostServerStatic() {
    return DefaultInAppLocalhostServer.static();
  }

  /// This function should only be called by the app-facing package.
  /// Look at using [WebViewFeature] in `flutter_inappwebview` instead
  @override
  PlatformWebViewFeature createPlatformWebViewFeatureStatic() {
    return _PlatformWebViewFeature.static();
  }
}

// Stub implementations for unsupported classes

class _PlatformChromeSafariBrowser extends PlatformChromeSafariBrowser {
  _PlatformChromeSafariBrowser(PlatformChromeSafariBrowserCreationParams params)
    : super.implementation(params);
  static final _PlatformChromeSafariBrowser _staticValue =
      _PlatformChromeSafariBrowser(
        const PlatformChromeSafariBrowserCreationParams(),
      );

  factory _PlatformChromeSafariBrowser.static() => _staticValue;
}

class _PlatformProcessGlobalConfig extends PlatformProcessGlobalConfig {
  _PlatformProcessGlobalConfig(PlatformProcessGlobalConfigCreationParams params)
    : super.implementation(params);
  static final _PlatformProcessGlobalConfig _staticValue =
      _PlatformProcessGlobalConfig(
        const PlatformProcessGlobalConfigCreationParams(),
      );

  factory _PlatformProcessGlobalConfig.static() => _staticValue;
}

class _PlatformServiceWorkerController extends PlatformServiceWorkerController {
  _PlatformServiceWorkerController(
    PlatformServiceWorkerControllerCreationParams params,
  ) : super.implementation(params);
  static final _PlatformServiceWorkerController _staticValue =
      _PlatformServiceWorkerController(
        const PlatformServiceWorkerControllerCreationParams(),
      );

  factory _PlatformServiceWorkerController.static() => _staticValue;

  @override
  ServiceWorkerClient? get serviceWorkerClient => throw UnimplementedError();
}

class _PlatformTracingController extends PlatformTracingController {
  _PlatformTracingController(PlatformTracingControllerCreationParams params)
    : super.implementation(params);
  static final _PlatformTracingController _staticValue =
      _PlatformTracingController(
        const PlatformTracingControllerCreationParams(),
      );

  factory _PlatformTracingController.static() => _staticValue;
}

class _PlatformPrintJobController extends PlatformPrintJobController {
  _PlatformPrintJobController(PlatformPrintJobControllerCreationParams params)
    : super.implementation(params);

  static final _PlatformPrintJobController _staticValue =
      _PlatformPrintJobController(
        const PlatformPrintJobControllerCreationParams(id: ''),
      );

  factory _PlatformPrintJobController.static() => _staticValue;
}

class _PlatformPullToRefreshController extends PlatformPullToRefreshController {
  _PlatformPullToRefreshController(
    PlatformPullToRefreshControllerCreationParams params,
  ) : super.implementation(params);

  static final _PlatformPullToRefreshController _staticValue =
      _PlatformPullToRefreshController(
        PlatformPullToRefreshControllerCreationParams(),
      );

  factory _PlatformPullToRefreshController.static() => _staticValue;
}

class _PlatformWebAuthenticationSession
    extends PlatformWebAuthenticationSession {
  _PlatformWebAuthenticationSession(
    PlatformWebAuthenticationSessionCreationParams params,
  ) : super.implementation(params);

  static final _PlatformWebAuthenticationSession _staticValue =
      _PlatformWebAuthenticationSession(
        const PlatformWebAuthenticationSessionCreationParams(),
      );

  factory _PlatformWebAuthenticationSession.static() => _staticValue;
}

class _PlatformWebNotificationController
    extends PlatformWebNotificationController {
  _PlatformWebNotificationController(
    PlatformWebNotificationControllerCreationParams params,
  ) : super.implementation(params);

  static final _PlatformWebNotificationController _staticValue =
      _PlatformWebNotificationController(
        PlatformWebNotificationControllerCreationParams(
          id: '',
          notification: WebNotification(),
        ),
      );

  factory _PlatformWebNotificationController.static() => _staticValue;
}

class _PlatformWebViewFeature extends PlatformWebViewFeature {
  _PlatformWebViewFeature(PlatformWebViewFeatureCreationParams params)
    : super.implementation(params);

  static final _PlatformWebViewFeature _staticValue = _PlatformWebViewFeature(
    PlatformWebViewFeatureCreationParams(),
  );
  factory _PlatformWebViewFeature.static() => _staticValue;
}

class _PlatformAssetsPathHandler extends PlatformAssetsPathHandler {
  _PlatformAssetsPathHandler(PlatformAssetsPathHandlerCreationParams params)
    : super.implementation(params);

  static final _PlatformAssetsPathHandler _staticValue =
      _PlatformAssetsPathHandler(
        PlatformAssetsPathHandlerCreationParams(
          PlatformPathHandlerCreationParams(path: ''),
        ),
      );

  factory _PlatformAssetsPathHandler.static() => _staticValue;

  @override
  PlatformPathHandlerEvents? eventHandler;

  @override
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) => {
    "path": path,
    "type": type,
  };

  @override
  Map<String, dynamic> toJson() => toMap();
}

class _PlatformResourcesPathHandler extends PlatformResourcesPathHandler {
  _PlatformResourcesPathHandler(
    PlatformResourcesPathHandlerCreationParams params,
  ) : super.implementation(params);

  static final _PlatformResourcesPathHandler _staticValue =
      _PlatformResourcesPathHandler(
        PlatformResourcesPathHandlerCreationParams(
          PlatformPathHandlerCreationParams(path: ''),
        ),
      );

  factory _PlatformResourcesPathHandler.static() => _staticValue;

  @override
  PlatformPathHandlerEvents? eventHandler;

  @override
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) => {
    "path": path,
    "type": type,
  };

  @override
  Map<String, dynamic> toJson() => toMap();
}

class _PlatformInternalStoragePathHandler
    extends PlatformInternalStoragePathHandler {
  _PlatformInternalStoragePathHandler(
    PlatformInternalStoragePathHandlerCreationParams params,
  ) : super.implementation(params);

  static final _PlatformInternalStoragePathHandler _staticValue =
      _PlatformInternalStoragePathHandler(
        PlatformInternalStoragePathHandlerCreationParams(
          PlatformPathHandlerCreationParams(path: ''),
          directory: '',
        ),
      );

  factory _PlatformInternalStoragePathHandler.static() => _staticValue;

  @override
  PlatformPathHandlerEvents? eventHandler;

  @override
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) => {
    "path": path,
    "type": type,
  };

  @override
  Map<String, dynamic> toJson() => toMap();
}

class _PlatformCustomPathHandler extends PlatformCustomPathHandler {
  _PlatformCustomPathHandler(PlatformCustomPathHandlerCreationParams params)
    : super.implementation(params);

  static final _PlatformCustomPathHandler _staticValue =
      _PlatformCustomPathHandler(
        PlatformCustomPathHandlerCreationParams(
          PlatformPathHandlerCreationParams(path: ''),
        ),
      );

  factory _PlatformCustomPathHandler.static() => _staticValue;

  @override
  PlatformPathHandlerEvents? eventHandler;

  @override
  Map<String, dynamic> toMap({EnumMethod? enumMethod}) => {
    "path": path,
    "type": type,
  };

  @override
  Map<String, dynamic> toJson() => toMap();
}
