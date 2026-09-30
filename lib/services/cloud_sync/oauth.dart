import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:flutter_web_auth_2/flutter_web_auth_2.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:url_launcher/url_launcher.dart";

import "configuration.dart";
import "file_store.dart";

enum CloudOAuthProvider { googleDrive, oneDrive }

class CloudOAuthProviderConfiguration {
  final String clientId;
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri redirectUri;
  final String callbackUrlScheme;
  final String scope;
  final Map<String, String> authorizationParameters;

  const CloudOAuthProviderConfiguration({
    required this.clientId,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.redirectUri,
    required this.callbackUrlScheme,
    required this.scope,
    this.authorizationParameters = const {},
  });

  bool get isConfigured => clientId.trim().isNotEmpty;
}

/// Public OAuth configuration is supplied at build time; native apps must not
/// embed a client secret.
class CloudOAuthBuildConfiguration {
  static const googleClientId = String.fromEnvironment(
    "CIYUE_GOOGLE_DRIVE_DESKTOP_CLIENT_ID",
  );
  static const googleAndroidServerClientId = String.fromEnvironment(
    "CIYUE_GOOGLE_ANDROID_SERVER_CLIENT_ID",
  );
  static const googleRedirectUri = String.fromEnvironment(
    "CIYUE_GOOGLE_DRIVE_DESKTOP_REDIRECT_URI",
    defaultValue: "http://localhost:43824",
  );
  static const googlePickerApiKey = String.fromEnvironment(
    "CIYUE_GOOGLE_PICKER_API_KEY",
  );
  static const googleProjectNumber = String.fromEnvironment(
    "CIYUE_GOOGLE_PROJECT_NUMBER",
  );
  static const microsoftClientId = String.fromEnvironment(
    "CIYUE_MICROSOFT_CLIENT_ID",
  );
  static const microsoftDesktopRedirectUri = String.fromEnvironment(
    "CIYUE_MICROSOFT_DESKTOP_REDIRECT_URI",
    defaultValue: "http://localhost:43824",
  );
  static const microsoftAndroidRedirectUri = String.fromEnvironment(
    "CIYUE_MICROSOFT_ANDROID_REDIRECT_URI",
  );
  static const microsoftTenant = String.fromEnvironment(
    "CIYUE_MICROSOFT_TENANT",
    defaultValue: "common",
  );

  static Uri _redirectUri(String value, String setting) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      throw StateError("Set $setting when building Ciyue.");
    }
    return uri;
  }

  static bool get googlePickerConfigured =>
      googlePickerApiKey.isNotEmpty && googleProjectNumber.isNotEmpty;

  static CloudOAuthProviderConfiguration googleDrive() =>
      CloudOAuthProviderConfiguration(
        clientId: googleClientId,
        authorizationEndpoint: Uri.https(
          "accounts.google.com",
          "/o/oauth2/v2/auth",
        ),
        tokenEndpoint: Uri.https("oauth2.googleapis.com", "/token"),
        redirectUri: _redirectUri(
          googleRedirectUri,
          "CIYUE_GOOGLE_DRIVE_DESKTOP_REDIRECT_URI",
        ),
        callbackUrlScheme: _callbackScheme(
          _redirectUri(
            googleRedirectUri,
            "CIYUE_GOOGLE_DRIVE_DESKTOP_REDIRECT_URI",
          ),
        ),
        scope: "https://www.googleapis.com/auth/drive.file",
        authorizationParameters: const {
          "access_type": "offline",
          "prompt": "consent",
        },
      );

  static CloudOAuthProviderConfiguration oneDrive() {
    final tenant = microsoftTenant.trim().isEmpty ? "common" : microsoftTenant;
    final redirectText = Platform.isAndroid
        ? microsoftAndroidRedirectUri
        : microsoftDesktopRedirectUri;
    final redirectSetting = Platform.isAndroid
        ? "CIYUE_MICROSOFT_ANDROID_REDIRECT_URI"
        : "CIYUE_MICROSOFT_DESKTOP_REDIRECT_URI";
    final redirectUri = _redirectUri(redirectText, redirectSetting);
    return CloudOAuthProviderConfiguration(
      clientId: microsoftClientId,
      authorizationEndpoint: Uri.https(
        "login.microsoftonline.com",
        "/$tenant/oauth2/v2.0/authorize",
      ),
      tokenEndpoint: Uri.https(
        "login.microsoftonline.com",
        "/$tenant/oauth2/v2.0/token",
      ),
      redirectUri: redirectUri,
      callbackUrlScheme: _callbackScheme(redirectUri),
      scope: "Files.ReadWrite offline_access",
    );
  }

  static String _callbackScheme(Uri redirectUri) {
    if (redirectUri.scheme == "http" || redirectUri.scheme == "https") {
      return "${redirectUri.scheme}://${redirectUri.authority}";
    }
    return redirectUri.scheme;
  }
}

class CloudOAuthTokens {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final String tokenType;
  final String? scope;

  const CloudOAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.tokenType,
    required this.scope,
  });

  bool expiresWithin(Duration duration, DateTime now) =>
      !expiresAt.isAfter(now.add(duration));

  Map<String, Object?> toJson() => {
    "accessToken": accessToken,
    "refreshToken": refreshToken,
    "expiresAt": expiresAt.toUtc().toIso8601String(),
    "tokenType": tokenType,
    "scope": scope,
  };

  factory CloudOAuthTokens.fromJson(Map<String, Object?> json) {
    final accessToken = json["accessToken"];
    final refreshToken = json["refreshToken"];
    final expiresAt = json["expiresAt"];
    final tokenType = json["tokenType"];
    final scope = json["scope"];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        (refreshToken != null && refreshToken is! String) ||
        expiresAt is! String ||
        tokenType is! String ||
        (scope != null && scope is! String)) {
      throw const FormatException("Invalid stored OAuth credentials.");
    }
    return CloudOAuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken as String?,
      expiresAt: DateTime.parse(expiresAt).toUtc(),
      tokenType: tokenType,
      scope: scope as String?,
    );
  }
}

typedef CloudOAuthBrowser = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});
typedef CloudOAuthClock = DateTime Function();

class CloudOAuthException implements Exception {
  final String message;

  const CloudOAuthException(this.message);

  @override
  String toString() => message;
}

/// Authorization-code + PKCE client shared by Google Drive and Microsoft Graph.
class CloudOAuthClient {
  final CloudOAuthProvider provider;
  final CloudOAuthProviderConfiguration configuration;
  final CloudSecretStorage secretStorage;
  final Dio dio;
  final bool _ownsDio;
  final CloudOAuthBrowser browser;
  final CloudOAuthClock clock;
  final Random random;
  final String secretKey;

  Future<CloudOAuthTokens>? _refreshInFlight;

  CloudOAuthClient({
    required this.provider,
    required this.configuration,
    required this.secretStorage,
    Dio? dio,
    CloudOAuthBrowser? browser,
    CloudOAuthClock? clock,
    Random? random,
  }) : dio = dio ?? Dio(),
       _ownsDio = dio == null,
       browser = browser ?? _launchPlatformBrowser,
       clock = clock ?? DateTime.now,
       random = random ?? Random.secure(),
       secretKey = "ciyue.cloud_sync.oauth.${provider.name}";

  Future<CloudOAuthTokens> authorize() async {
    if (!configuration.isConfigured) {
      throw const CloudOAuthException("OAuth client ID is not configured.");
    }
    final state = _randomUrlSafe(32);
    final verifier = _randomUrlSafe(64);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll("=", "");
    final authorizationUri = configuration.authorizationEndpoint.replace(
      queryParameters: {
        ...configuration.authorizationEndpoint.queryParameters,
        "client_id": configuration.clientId,
        "response_type": "code",
        "redirect_uri": configuration.redirectUri.toString(),
        "response_mode": "query",
        "scope": configuration.scope,
        "state": state,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        ...configuration.authorizationParameters,
      },
    );

    final callback = Uri.parse(
      await browser(
        url: authorizationUri.toString(),
        callbackUrlScheme: configuration.callbackUrlScheme,
      ),
    );
    if (callback.queryParameters["state"] != state) {
      throw const CloudOAuthException("OAuth state validation failed.");
    }
    final error = callback.queryParameters["error"];
    if (error != null) {
      final description = callback.queryParameters["error_description"];
      throw CloudOAuthException(
        description == null
            ? "OAuth authorization failed: $error"
            : "OAuth authorization failed: $description",
      );
    }
    final code = callback.queryParameters["code"];
    if (code == null || code.isEmpty) {
      throw const CloudOAuthException("OAuth response did not contain a code.");
    }

    final response = await dio.postUri<Map<String, dynamic>>(
      configuration.tokenEndpoint,
      data: {
        "client_id": configuration.clientId,
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": configuration.redirectUri.toString(),
        "code_verifier": verifier,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final tokens = _parseTokenResponse(response.data, previous: null);
    await _save(tokens);
    return tokens;
  }

  Future<String> accessToken() async {
    final tokens = await _read();
    if (tokens == null) {
      throw const CloudOAuthException("Connect this cloud account first.");
    }
    if (!tokens.expiresWithin(const Duration(minutes: 1), clock())) {
      return tokens.accessToken;
    }
    final refreshToken = tokens.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const CloudOAuthException(
        "Cloud authorization has expired. Reconnect the account.",
      );
    }
    final existing = _refreshInFlight;
    if (existing != null) return (await existing).accessToken;

    final refresh = _refresh(tokens, refreshToken);
    _refreshInFlight = refresh;
    try {
      return (await refresh).accessToken;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> disconnect() => secretStorage.delete(secretKey);

  void close() {
    if (_ownsDio) dio.close(force: true);
  }

  Future<CloudOAuthTokens?> _read() async {
    final raw = await secretStorage.read(secretKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException("Expected an OAuth token object.");
      }
      return CloudOAuthTokens.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const CloudOAuthException("Stored cloud authorization is invalid.");
    }
  }

  Future<CloudOAuthTokens> _refresh(
    CloudOAuthTokens previous,
    String refreshToken,
  ) async {
    final response = await dio.postUri<Map<String, dynamic>>(
      configuration.tokenEndpoint,
      data: {
        "client_id": configuration.clientId,
        "grant_type": "refresh_token",
        "refresh_token": refreshToken,
        "scope": configuration.scope,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final tokens = _parseTokenResponse(response.data, previous: previous);
    await _save(tokens);
    return tokens;
  }

  CloudOAuthTokens _parseTokenResponse(
    Map<String, dynamic>? response, {
    required CloudOAuthTokens? previous,
  }) {
    if (response == null ||
        response["access_token"] is! String ||
        (response["access_token"] as String).isEmpty) {
      throw const CloudOAuthException(
        "Cloud provider returned no access token.",
      );
    }
    final rawExpiresIn = response["expires_in"];
    final expiresIn = rawExpiresIn is int
        ? rawExpiresIn
        : int.tryParse(rawExpiresIn?.toString() ?? "") ?? 3600;
    final rawRefreshToken = response["refresh_token"];
    final refreshToken = rawRefreshToken is String && rawRefreshToken.isNotEmpty
        ? rawRefreshToken
        : previous?.refreshToken;
    final rawScope = response["scope"];
    return CloudOAuthTokens(
      accessToken: response["access_token"] as String,
      refreshToken: refreshToken,
      expiresAt: clock().toUtc().add(Duration(seconds: expiresIn)),
      tokenType: response["token_type"] as String? ?? "Bearer",
      scope: rawScope is String ? rawScope : previous?.scope,
    );
  }

  Future<void> _save(CloudOAuthTokens tokens) =>
      secretStorage.write(secretKey, jsonEncode(tokens.toJson()));

  String _randomUrlSafe(int length) => base64Url
      .encode(List<int>.generate(length, (_) => random.nextInt(256)))
      .replaceAll("=", "");
}

abstract interface class GoogleDriveAndroidAuthorization {
  Future<void> authorize();

  Future<String> accessToken();

  Future<bool> isAuthorized();

  Future<void> disconnect();
}

class GoogleDriveAndroidAuthorizationPlugin
    implements GoogleDriveAndroidAuthorization {
  static const _driveScope = "https://www.googleapis.com/auth/drive.file";
  static const _scopes = [_driveScope];
  static Future<void>? _initialization;

  final CloudSecretStorage secretStorage;
  final String secretKey;
  GoogleSignInAccount? _account;

  GoogleDriveAndroidAuthorizationPlugin({required this.secretStorage})
    : secretKey = "ciyue.cloud_sync.oauth.googleDrive";

  Future<void> _initialize() {
    final existing = _initialization;
    if (existing != null) return existing;
    final serverClientId =
        CloudOAuthBuildConfiguration.googleAndroidServerClientId;
    if (serverClientId.isEmpty) {
      throw const CloudOAuthException(
        "Set CIYUE_GOOGLE_ANDROID_SERVER_CLIENT_ID when building Ciyue.",
      );
    }
    final initializing = GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
    _initialization = initializing;
    return initializing;
  }

  @override
  Future<void> authorize() async {
    await _initialize();
    final user = await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    await user.authorizationClient.authorizeScopes(_scopes);
    _account = user;
    await secretStorage.write(
      secretKey,
      jsonEncode({"nativeGoogleSignIn": true, "account": user.email}),
    );
  }

  @override
  Future<String> accessToken() async {
    await _initialize();
    final user = await _currentAccount();
    if (user == null) {
      throw const CloudOAuthException(
        "Reconnect the Google Drive account to continue syncing.",
      );
    }
    final authorization = await user.authorizationClient.authorizationForScopes(
      _scopes,
    );
    if (authorization == null || authorization.accessToken.isEmpty) {
      throw const CloudOAuthException(
        "Reconnect the Google Drive account to continue syncing.",
      );
    }
    return authorization.accessToken;
  }

  @override
  Future<bool> isAuthorized() async {
    if (await secretStorage.read(secretKey) == null) return false;
    await _initialize();
    final user = await _currentAccount();
    if (user == null) return false;
    final authorization = await user.authorizationClient.authorizationForScopes(
      _scopes,
    );
    return authorization != null && authorization.accessToken.isNotEmpty;
  }

  @override
  Future<void> disconnect() async {
    if (_initialization != null) await GoogleSignIn.instance.signOut();
    _account = null;
    await secretStorage.delete(secretKey);
  }

  Future<GoogleSignInAccount?> _currentAccount() async {
    final existing = _account;
    if (existing != null) return existing;
    final restoration = GoogleSignIn.instance
        .attemptLightweightAuthentication();
    if (restoration == null) return null;
    _account = await restoration;
    return _account;
  }
}

class CloudOAuthService {
  final CloudSecretStorage secretStorage;
  final CloudOAuthProviderConfiguration Function(CloudOAuthProvider provider)
  configurationForProvider;
  final CloudOAuthBrowser? browser;
  final CloudOAuthClock? clock;
  final GoogleDriveAndroidAuthorization androidGoogleAuthorization;
  final Map<CloudOAuthProvider, CloudOAuthClient> _clients = {};

  CloudOAuthService({
    required this.secretStorage,
    CloudOAuthProviderConfiguration Function(CloudOAuthProvider provider)?
    configurationForProvider,
    this.browser,
    this.clock,
    GoogleDriveAndroidAuthorization? androidGoogleAuthorization,
  }) : configurationForProvider =
           configurationForProvider ?? _buildConfiguration,
       androidGoogleAuthorization =
           androidGoogleAuthorization ??
           GoogleDriveAndroidAuthorizationPlugin(secretStorage: secretStorage);

  Future<void> authorize(CloudOAuthProvider provider) async {
    if (provider == CloudOAuthProvider.googleDrive && Platform.isAndroid) {
      await androidGoogleAuthorization.authorize();
      return;
    }
    await _client(provider).authorize();
  }

  Future<String> accessToken(CloudOAuthProvider provider) =>
      provider == CloudOAuthProvider.googleDrive && Platform.isAndroid
      ? androidGoogleAuthorization.accessToken()
      : _client(provider).accessToken();

  Future<bool> isAuthorized(CloudOAuthProvider provider) async =>
      provider == CloudOAuthProvider.googleDrive && Platform.isAndroid
      ? androidGoogleAuthorization.isAuthorized()
      : await secretStorage.read(_secretKey(provider)) != null;

  CloudAccessTokenProvider tokenProvider(CloudOAuthProvider provider) =>
      () => accessToken(provider);

  Future<void> disconnect([CloudOAuthProvider? provider]) async {
    if (provider != null) {
      if (provider == CloudOAuthProvider.googleDrive && Platform.isAndroid) {
        await androidGoogleAuthorization.disconnect();
      } else {
        await secretStorage.delete(_secretKey(provider));
      }
      return;
    }
    if (Platform.isAndroid) await androidGoogleAuthorization.disconnect();
    for (final provider in CloudOAuthProvider.values) {
      await secretStorage.delete(_secretKey(provider));
    }
  }

  void close() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
  }

  static String _secretKey(CloudOAuthProvider provider) =>
      "ciyue.cloud_sync.oauth.${provider == CloudOAuthProvider.googleDrive ? "googleDrive" : "oneDrive"}";

  CloudOAuthClient _client(CloudOAuthProvider provider) => _clients.putIfAbsent(
    provider,
    () => CloudOAuthClient(
      provider: provider,
      configuration: configurationForProvider(provider),
      secretStorage: secretStorage,
      browser: browser,
      clock: clock,
    ),
  );

  static CloudOAuthProviderConfiguration _buildConfiguration(
    CloudOAuthProvider provider,
  ) => switch (provider) {
    CloudOAuthProvider.googleDrive =>
      CloudOAuthBuildConfiguration.googleDrive(),
    CloudOAuthProvider.oneDrive => CloudOAuthBuildConfiguration.oneDrive(),
  };
}

Future<String> _launchPlatformBrowser({
  required String url,
  required String callbackUrlScheme,
}) => Platform.isMacOS
    ? _launchMacOSLoopback(url: url, callbackUrlScheme: callbackUrlScheme)
    : FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
        options: const FlutterWebAuth2Options(useWebview: false),
      );

Future<String> _launchMacOSLoopback({
  required String url,
  required String callbackUrlScheme,
}) async {
  final callbackUri = Uri.parse(callbackUrlScheme);
  if (callbackUri.scheme != "http" ||
      (callbackUri.host != "localhost" && callbackUri.host != "127.0.0.1") ||
      !callbackUri.hasPort) {
    throw ArgumentError(
      "Callback URL must use http://localhost:{port} on macOS.",
    );
  }

  final servers = <HttpServer>[
    await HttpServer.bind(InternetAddress.loopbackIPv4, callbackUri.port),
  ];
  try {
    servers.add(
      await HttpServer.bind(
        InternetAddress.loopbackIPv6,
        callbackUri.port,
        v6Only: true,
      ),
    );
  } on SocketException {
    // IPv4 loopback is still available on systems without IPv6.
  }
  try {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const CloudOAuthException("Could not open the system browser.");
    }
    final request = await Future.any(servers.map((server) => server.first))
        .timeout(const Duration(minutes: 5));
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(
        "<!doctype html><html><body>Authorization complete. "
        "You may close this tab.</body></html>",
      );
    await request.response.close();
    return request.uri.toString();
  } finally {
    await Future.wait(servers.map((server) => server.close(force: true)));
  }
}
