import "dart:convert";
import "dart:io";
import "dart:math";

import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:ciyue/services/cloud_sync/oauth.dart";
import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late HttpServer server;
  late _MemoryCloudSecretStorage secrets;
  late List<Map<String, String>> tokenRequests;
  late CloudOAuthClient client;
  late DateTime now;
  var tokenResponse = <String, Object?>{
    "access_token": "access-first",
    "refresh_token": "refresh-first",
    "expires_in": 3600,
    "token_type": "Bearer",
    "scope": "Files.ReadWrite",
  };
  var mismatchState = false;

  setUp(() async {
    tokenRequests = [];
    tokenResponse = {
      "access_token": "access-first",
      "refresh_token": "refresh-first",
      "expires_in": 3600,
      "token_type": "Bearer",
      "scope": "Files.ReadWrite",
    };
    mismatchState = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path != "/token") {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final bodyBytes = await request.fold<List<int>>(
        [],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      final body = utf8.decode(bodyBytes);
      tokenRequests.add(Uri.splitQueryString(body));
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(tokenResponse));
      await request.response.close();
    });

    now = DateTime.utc(2026, 9, 30);
    secrets = _MemoryCloudSecretStorage();
    final redirectUri = Uri.parse(
      "http://localhost:${server.port}/oauth/callback",
    );
    client = CloudOAuthClient(
      provider: CloudOAuthProvider.oneDrive,
      configuration: CloudOAuthProviderConfiguration(
        clientId: "public-client-id",
        authorizationEndpoint: Uri.parse(
          "http://127.0.0.1:${server.port}/authorize",
        ),
        tokenEndpoint: Uri.parse("http://127.0.0.1:${server.port}/token"),
        redirectUri: redirectUri,
        callbackUrlScheme: "http://localhost:${server.port}",
        scope: "Files.ReadWrite offline_access",
      ),
      secretStorage: secrets,
      dio: Dio(),
      clock: () => now,
      random: Random(42),
      browser: ({required url, required callbackUrlScheme}) async {
        final authorizeUri = Uri.parse(url);
        expect(callbackUrlScheme, "http://localhost:${server.port}");
        expect(authorizeUri.queryParameters["client_id"], "public-client-id");
        expect(authorizeUri.queryParameters["code_challenge_method"], "S256");
        expect(authorizeUri.queryParameters["code_challenge"], isNotEmpty);
        final state = authorizeUri.queryParameters["state"]!;
        return redirectUri
            .replace(
              queryParameters: {
                "code": "authorization-code",
                "state": mismatchState ? "incorrect-state" : state,
              },
            )
            .toString();
      },
    );
  });

  tearDown(() async {
    client.dio.close(force: true);
    await server.close(force: true);
  });

  test(
    "uses authorization code with PKCE and stores refresh credentials",
    () async {
      final tokens = await client.authorize();

      expect(tokens.accessToken, "access-first");
      expect(tokens.refreshToken, "refresh-first");
      expect(tokenRequests, hasLength(1));
      expect(tokenRequests.single["grant_type"], "authorization_code");
      expect(tokenRequests.single["code"], "authorization-code");
      expect(tokenRequests.single["code_verifier"], isNotEmpty);
      expect(
        Uri.decodeComponent(tokenRequests.single["redirect_uri"]!),
        "http://localhost:${server.port}/oauth/callback",
      );
      expect(secrets.values.keys, {"ciyue.cloud_sync.oauth.oneDrive"});
      expect(await client.accessToken(), "access-first");
    },
  );

  test("rejects callbacks with a mismatched OAuth state", () async {
    mismatchState = true;

    await expectLater(client.authorize(), throwsA(isA<CloudOAuthException>()));
    expect(tokenRequests, isEmpty);
    expect(secrets.values, isEmpty);
  });

  test("refreshes expired access token and keeps the refresh token", () async {
    tokenResponse = {
      "access_token": "access-expired",
      "refresh_token": "refresh-first",
      "expires_in": 0,
      "token_type": "Bearer",
    };
    await client.authorize();

    tokenResponse = {
      "access_token": "access-refreshed",
      "expires_in": 3600,
      "token_type": "Bearer",
    };
    expect(await client.accessToken(), "access-refreshed");
    expect(tokenRequests, hasLength(2));
    expect(tokenRequests.last["grant_type"], "refresh_token");
    expect(tokenRequests.last["refresh_token"], "refresh-first");

    final stored = jsonDecode(
      secrets.values["ciyue.cloud_sync.oauth.oneDrive"]!,
    ) as Map<String, dynamic>;
    expect(stored["refreshToken"], "refresh-first");
    expect(stored["accessToken"], "access-refreshed");
  });
}

class _MemoryCloudSecretStorage implements CloudSecretStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
