import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/viewModels/chat_view_model.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

Map<String, dynamic> sessionJson({
  required String id,
  required int updatedAt,
  String? initialContext,
  List<Map<String, dynamic>> messages = const [],
}) {
  return {
    "id": id,
    "createdAt": updatedAt,
    "updatedAt": updatedAt,
    "initialContext": initialContext,
    "scenarioId": null,
    "messages": messages,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // No allowList: the Settings singleton's constructor reads
    // dozens of keys, and a restricted cache throws on any of them.
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
  });

  setUp(() async {
    await prefs.remove("chatSessions");
    await prefs.remove("chatActiveSessionId");
    await prefs.remove("chatHistory");
    settings.aiProvider = "openai";
    settings.aiProviderConfigs = {};
  });

  group("aiConfigurationGaps", () {
    test("unconfigured provider misses model and key", () {
      final gaps = aiConfigurationGaps("openai");
      expect(gaps.missingModel, isTrue);
      expect(gaps.missingApiKey, isTrue);
      expect(isAiProviderConfigured("openai"), isFalse);
    });

    test("model without key still misses the key", () {
      settings.aiProviderConfigs = {
        "openai": {"model": "gpt-x", "apiKey": ""},
      };
      final gaps = aiConfigurationGaps("openai");
      expect(gaps.missingModel, isFalse);
      expect(gaps.missingApiKey, isTrue);
    });

    test("local providers need a model but no key", () {
      settings.aiProviderConfigs = {
        "ollama": {"model": "llama3", "apiKey": ""},
      };
      expect(isAiProviderConfigured("ollama"), isTrue);
      settings.aiProviderConfigs = {
        "openai_compatible": {"model": "local-model", "apiKey": ""},
      };
      expect(isAiProviderConfigured("openai_compatible"), isTrue);
    });

    test(
      "AI.request throws AiNotConfiguredException when unconfigured",
      () async {
        final ai = AI(provider: "openai", model: "", apikey: "");
        await expectLater(
          ai.request("hello"),
          throwsA(isA<AiNotConfiguredException>()),
        );
      },
    );
  });

  group("ChatViewModel sessions", () {
    test("fresh start has one empty active session", () {
      final vm = ChatViewModel();
      expect(vm.sessions.length, 1);
      expect(vm.messages, isEmpty);
      expect(vm.activeSessionId, vm.sessions.first.id);
      vm.dispose();
    });

    test("legacy single history migrates into a session", () async {
      await prefs.setString(
        "chatHistory",
        json.encode({
          "messages": [
            {"text": "hello", "isUser": true},
            {"text": "hi there", "isUser": false},
          ],
          "scenarioId": null,
          "initialContext": "apple",
        }),
      );
      final vm = ChatViewModel();
      expect(vm.sessions.length, 1);
      expect(vm.messages.length, 2);
      expect(vm.initialContext, "apple");
      vm.dispose();
    });

    test("switching and deleting sessions", () async {
      await prefs.setString(
        "chatSessions",
        json.encode([
          sessionJson(
            id: "a",
            updatedAt: 1000,
            messages: [
              {"text": "first conversation", "isUser": true},
            ],
          ),
          sessionJson(
            id: "b",
            updatedAt: 2000,
            messages: [
              {"text": "second conversation", "isUser": true},
            ],
          ),
        ]),
      );
      final vm = ChatViewModel();
      // Most recently updated session is active by default.
      expect(vm.activeSessionId, "b");
      expect(vm.messages.single.text, "second conversation");

      vm.switchSession("a");
      expect(vm.activeSessionId, "a");
      expect(vm.messages.single.text, "first conversation");
      expect(prefs.getString("chatActiveSessionId"), "a");

      // Deleting a non-active session keeps the current one.
      vm.deleteSession("b");
      expect(vm.sessions.length, 1);
      expect(vm.activeSessionId, "a");

      // Deleting the active session falls back to a fresh one.
      vm.deleteSession("a");
      expect(vm.sessions.length, 1);
      expect(vm.activeSessionId, isNot("a"));
      expect(vm.messages, isEmpty);
      vm.dispose();
    });

    test("new session keeps existing conversations", () async {
      await prefs.setString(
        "chatSessions",
        json.encode([
          sessionJson(
            id: "a",
            updatedAt: 1000,
            messages: [
              {"text": "keep me", "isUser": true},
            ],
          ),
        ]),
      );
      final vm = ChatViewModel();
      vm.newSession();
      expect(vm.messages, isEmpty);
      expect(vm.sessions.length, 2);
      vm.switchSession("a");
      expect(vm.messages.single.text, "keep me");
      vm.dispose();
    });

    test("word context reuses its own session", () async {
      await prefs.setString(
        "chatSessions",
        json.encode([
          sessionJson(
            id: "w1",
            updatedAt: 1000,
            initialContext: "banana",
            messages: [
              {"text": "what does banana mean", "isUser": true},
            ],
          ),
        ]),
      );
      final vm = ChatViewModel(initialContext: "banana");
      expect(vm.activeSessionId, "w1");
      expect(vm.messages.length, 1);
      vm.dispose();

      final vm2 = ChatViewModel(initialContext: "cherry");
      expect(vm2.activeSessionId, isNot("w1"));
      expect(vm2.initialContext, "cherry");
      expect(vm2.messages, isEmpty);
      expect(vm2.sessions.length, 2);
      vm2.dispose();
    });

    test(
      "sendMessage is blocked with an explanation when unconfigured",
      () async {
        final vm = ChatViewModel();
        expect(vm.aiConfigured, isFalse);
        vm.textController.text = "hello";
        await vm.sendMessage();
        // Nothing was sent and the typed text is preserved.
        expect(vm.messages, isEmpty);
        expect(vm.textController.text, "hello");
        vm.dispose();
      },
    );

    test("session titles derive from the first user message", () {
      final session = ChatSession(
        id: "x",
        createdAt: 0,
        updatedAt: 0,
        messages: const [
          ChatMessage(
            text: "  a very long question that keeps going  ",
            isUser: true,
          ),
        ],
      );
      expect(session.displayTitle, "a very long question that keeps going");
      expect(session.isPristine, isFalse);
      final empty = ChatSession(id: "y", createdAt: 0, updatedAt: 0);
      expect(empty.isPristine, isTrue);
      expect(empty.displayTitle, "");
    });
  });
}
