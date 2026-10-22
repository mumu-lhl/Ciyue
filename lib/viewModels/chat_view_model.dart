import "dart:async";
import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/chat_scenarios.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:material_ui/material_ui.dart";
import "package:path_provider/path_provider.dart";

class ChatMessage {
  final String text;
  final bool isUser;

  /// Local files of images attached to (or generated for) this
  /// message, kept in the app's chat_images directory.
  final List<String> imagePaths;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.imagePaths = const [],
  });

  Map<String, dynamic> toJson() => {
    "text": text,
    "isUser": isUser,
    if (imagePaths.isNotEmpty) "imagePaths": imagePaths,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json["text"] as String? ?? "",
    isUser: json["isUser"] as bool? ?? false,
    imagePaths: [
      for (final path in (json["imagePaths"] as List? ?? const []))
        if (path is String) path,
    ],
  );
}

/// One conversation thread. The chat keeps many of these and the
/// user can switch between them, instead of the old single history
/// that could only be resumed or deleted wholesale.
class ChatSession {
  final String id;
  final int createdAt;
  int updatedAt;

  /// Word this conversation is about (word-detail entry), if any.
  String? initialContext;

  /// Active roleplay scenario id, if any.
  String? scenarioId;

  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.initialContext,
    this.scenarioId,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  /// True when nothing has happened in this session yet — such
  /// sessions are discarded when the user switches away, so the
  /// session list doesn't fill up with untouched "new chat" rows.
  bool get isPristine =>
      messages.isEmpty && scenarioId == null && initialContext == null;

  /// Title derived from content: the first user message, else the
  /// word the conversation is about. Empty when neither exists
  /// (callers fall back to a scenario name or a generic label).
  String get displayTitle {
    for (final message in messages) {
      final text = message.text.trim();
      if (message.isUser && text.isNotEmpty) {
        return text.length > 40 ? "${text.substring(0, 40)}…" : text;
      }
    }
    return initialContext ?? "";
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "initialContext": initialContext,
    "scenarioId": scenarioId,
    "messages": messages.map((m) => m.toJson()).toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final messagesJson = json["messages"] as List? ?? const [];
    return ChatSession(
      id: json["id"] as String? ?? "",
      createdAt: (json["createdAt"] as num?)?.toInt() ?? 0,
      updatedAt: (json["updatedAt"] as num?)?.toInt() ?? 0,
      initialContext: json["initialContext"] as String?,
      scenarioId: json["scenarioId"] as String?,
      messages: [
        for (final m in messagesJson)
          if (m is Map<String, dynamic>) ChatMessage.fromJson(m),
      ],
    );
  }
}

/// A preset roleplay scenario for language learning.
class ChatScenario {
  final String id;
  final String titleKey;
  final String systemPrompt;

  const ChatScenario({
    required this.id,
    required this.titleKey,
    required this.systemPrompt,
  });

  /// Human-readable title for use inside AI prompts. Presets store an
  /// l10n key in [titleKey], which must never leak into a prompt;
  /// custom scenarios store their actual title in [titleKey].
  String get promptTitle {
    switch (id) {
      case "restaurant":
        return "At a Restaurant";
      case "travel":
        return "Travel";
      case "business":
        return "Business Meeting";
      case "shopping":
        return "Shopping";
      case "daily":
        return "Daily Chat";
      default:
        return titleKey;
    }
  }

  static const List<ChatScenario> presets = [
    ChatScenario(
      id: "restaurant",
      titleKey: "scenarioRestaurant",
      systemPrompt: "You are a waiter at a restaurant. Roleplay a dining scenario with the user to help them practice ordering food and conversing in a restaurant. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "travel",
      titleKey: "scenarioTravel",
      systemPrompt: "You are a friendly local tour guide. Roleplay a travel scenario with the user to help them practice asking for directions, booking hotels, and sightseeing conversations. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "business",
      titleKey: "scenarioBusiness",
      systemPrompt: "You are a business colleague. Roleplay a workplace scenario with the user to help them practice meetings, emails, and professional small talk. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "shopping",
      titleKey: "scenarioShopping",
      systemPrompt: "You are a shop assistant. Roleplay a shopping scenario with the user to help them practice asking about prices, sizes, and making purchases. Stay in character. Gently correct their language mistakes.",
    ),
    ChatScenario(
      id: "daily",
      titleKey: "scenarioDaily",
      systemPrompt: "You are a friendly language partner. Have a casual daily conversation with the user to help them practice everyday speaking. Gently correct their language mistakes and suggest more natural expressions.",
    ),
  ];
}

class ChatViewModel extends ChangeNotifier {
  final textController = TextEditingController();
  final focusNode = FocusNode();

  final List<ChatSession> _sessions = [];
  late ChatSession _active;
  late final AI _ai;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  bool _disposed = false;

  /// Incremented whenever the active conversation changes (switch,
  /// new, clear, scenario) or the view model is disposed. Streaming
  /// loops capture their generation and stop writing once it no
  /// longer matches, so a stale stream can never write into a
  /// different conversation.
  int _streamGeneration = 0;

  /// Active scenario for roleplay, synced from the active session.
  ChatScenario? _scenario;
  ChatScenario? get scenario => _scenario;

  ChatViewModel({String? initialContext}) {
    final config = settings.getAiProviderConfig(settings.aiProvider);
    _ai = AI(
      provider: settings.aiProvider,
      model: config["model"] ?? "",
      apikey: config["apiKey"] ?? "",
    );
    _loadSessions();
    if (initialContext != null) {
      // Reuse the word's existing conversation if there is one, so
      // asking about the same word twice continues the same thread.
      final existing = _sessions
          .where((s) => s.initialContext == initialContext)
          .toList();
      _active = existing.isNotEmpty
          ? existing.reduce((a, b) => a.updatedAt >= b.updatedAt ? a : b)
          : _createSession(initialContext: initialContext);
    } else if (_sessions.isNotEmpty) {
      final lastActiveId = prefs.getString(_activeSessionKey);
      final lastActive = _sessions.where((s) => s.id == lastActiveId);
      _active = lastActive.isNotEmpty ? lastActive.first : _mostRecent();
    } else {
      _active = _createSession();
    }
    _syncScenario();
  }

  // --- Session access -------------------------------------------------

  /// All sessions, most recently updated first.
  List<ChatSession> get sessions {
    final sorted = List<ChatSession>.of(_sessions)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(sorted);
  }

  String get activeSessionId => _active.id;

  List<ChatMessage> get messages => _active.messages;

  /// The active session's word context, restored from storage when
  /// the chat is reopened without fresh context.
  String? get initialContext => _active.initialContext;

  /// Whether the current AI provider has a model (and API key,
  /// where required) configured. AI actions gate on this so a
  /// missing configuration surfaces as an explanation in the UI
  /// instead of a silent no-op.
  bool get aiConfigured => isAiProviderConfigured(settings.aiProvider);

  ChatSession _mostRecent() =>
      _sessions.reduce((a, b) => a.updatedAt >= b.updatedAt ? a : b);

  ChatSession _createSession({String? initialContext, String? scenarioId}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = ChatSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: now,
      updatedAt: now,
      initialContext: initialContext,
      scenarioId: scenarioId,
    );
    _sessions.add(session);
    return session;
  }

  void _syncScenario() {
    final id = _active.scenarioId;
    if (id == null) {
      _scenario = null;
      return;
    }
    for (final s in ChatScenarioManager().allScenarios) {
      if (s.id == id) {
        _scenario = s;
        return;
      }
    }
    _scenario = null;
  }

  void _activate(ChatSession session) {
    _active = session;
    _syncScenario();
  }

  /// Discard the active session if it is pristine (nothing sent, no
  /// scenario, no word context) — used when leaving it for another
  /// session, so untouched sessions don't pile up.
  void _discardPristineActive({ChatSession? except}) {
    if (_active.isPristine && _active != except) {
      _sessions.remove(_active);
    }
  }

  void _stopStream() {
    _streamGeneration++;
    _isStreaming = false;
  }

  /// Start a fresh conversation and switch to it.
  void newSession() {
    _stopStream();
    _discardPristineActive();
    _activate(_createSession());
    _persistSessions();
    _notify();
  }

  void switchSession(String id) {
    if (id == _active.id) return;
    final target = _sessions.where((s) => s.id == id).toList();
    if (target.isEmpty) return;
    _stopStream();
    _discardPristineActive(except: target.first);
    _activate(target.first);
    _persistSessions();
    _notify();
  }

  void deleteSession(String id) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final wasActive = _sessions[index] == _active;
    _deleteMessageImages(_sessions[index].messages);
    _sessions.removeAt(index);
    if (wasActive) {
      _stopStream();
      _activate(_sessions.isEmpty ? _createSession() : _mostRecent());
    }
    _persistSessions();
    _notify();
  }

  void clearChat() {
    _stopStream();
    _deleteMessageImages(_active.messages);
    _active.messages.clear();
    _active.scenarioId = null;
    _scenario = null;
    _persistSessions();
    _notify();
  }

  // --- Persistence ------------------------------------------------------

  static const _sessionsKey = "chatSessions";
  static const _activeSessionKey = "chatActiveSessionId";
  static const _legacyHistoryKey = "chatHistory";
  static const _maxPersistedMessages = 100;
  static const _maxSessions = 30;

  void _persistSessions() {
    try {
      _active.updatedAt = DateTime.now().millisecondsSinceEpoch;
      // Cap the stored count, dropping the least recently updated
      // non-active sessions first.
      if (_sessions.length > _maxSessions) {
        final byRecency = List<ChatSession>.of(_sessions)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final keep = byRecency.take(_maxSessions).toSet();
        keep.add(_active);
        for (final session in _sessions.where((s) => !keep.contains(s))) {
          _deleteMessageImages(session.messages);
        }
        _sessions.removeWhere((s) => !keep.contains(s));
      }
      final data = [
        for (final session in _sessions)
          {
            ...session.toJson(),
            // Cap per-session history and drop empty streaming
            // placeholders.
            "messages": _cleanMessages(session.messages)
                .map((m) => m.toJson())
                .toList(),
          },
      ];
      prefs.setString(_sessionsKey, json.encode(data));
      prefs.setString(_activeSessionKey, _active.id);
    } catch (_) {}
  }

  List<ChatMessage> _cleanMessages(List<ChatMessage> messages) {
    final capped = messages.length > _maxPersistedMessages
        ? messages.sublist(messages.length - _maxPersistedMessages)
        : messages;
    // Drop empty streaming placeholders, but keep generated-image
    // messages (empty text, image attached).
    return capped
        .where((m) => !(m.text.isEmpty && !m.isUser && m.imagePaths.isEmpty))
        .toList();
  }

  void _loadSessions() {
    try {
      final raw = prefs.getString(_sessionsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = json.decode(raw) as List;
        for (final item in list) {
          try {
            final session = ChatSession.fromJson(item as Map<String, dynamic>);
            if (session.id.isNotEmpty) _sessions.add(session);
          } catch (_) {
            // One corrupt session must not take the rest down.
          }
        }
        if (_sessions.isNotEmpty) return;
      }
      _migrateLegacyHistory();
    } catch (_) {}
  }

  /// The pre-multi-session storage kept exactly one conversation in
  /// `chatHistory`; wrap it as the first session.
  void _migrateLegacyHistory() {
    try {
      final raw = prefs.getString(_legacyHistoryKey);
      if (raw == null || raw.isEmpty) return;
      final data = json.decode(raw) as Map<String, dynamic>;
      final messagesJson = data["messages"] as List?;
      if (messagesJson == null || messagesJson.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      _sessions.add(
        ChatSession(
          id: "legacy",
          createdAt: now,
          updatedAt: now,
          initialContext: data["initialContext"] as String?,
          scenarioId: data["scenarioId"] as String?,
          messages: [
            for (final m in messagesJson)
              if (m is Map<String, dynamic>) ChatMessage.fromJson(m),
          ],
        ),
      );
    } catch (_) {}
  }

  // --- Chat actions -----------------------------------------------------

  @override
  void dispose() {
    _disposed = true;
    _streamGeneration++;
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Write a streaming chunk into the placeholder at [index] of the
  /// active session, unless the stream's generation is stale (chat
  /// switched/cleared/disposed) or the placeholder is gone.
  bool _writeStreamChunk(int generation, int index, String text) {
    if (_disposed || generation != _streamGeneration) return false;
    if (index < 0 || index >= _active.messages.length) return false;
    _active.messages[index] = ChatMessage(text: text, isUser: false);
    notifyListeners();
    return true;
  }

  /// Start a roleplay scenario in its own new session.
  void startScenario(ChatScenario scenario) {
    _stopStream();
    _discardPristineActive();
    _activate(_createSession(scenarioId: scenario.id));
    _persistSessions();
    _notify();
    // Send an opening message from the AI.
    _sendScenarioOpener();
  }

  String _buildScenarioSystemPrompt() {
    final template = AIPrompts().scenarioPrompt;
    return template
        .replaceAll(r"$scenarioTitle", _scenario!.promptTitle)
        .replaceAll(r"$scenarioDescription", _scenario!.systemPrompt);
  }

  Future<void> _sendScenarioOpener() async {
    if (!aiConfigured) {
      // The configuration banner explains; don't add a dead
      // streaming placeholder.
      _notify();
      return;
    }
    final generation = _streamGeneration;
    _active.messages.add(const ChatMessage(text: "", isUser: false));
    final index = _active.messages.length - 1;
    _isStreaming = true;
    _notify();

    final systemPrompt = _buildScenarioSystemPrompt();

    final buffer = StringBuffer();
    try {
      await for (final chunk in _ai.requestStreamWithHistory(
        "Start the roleplay. Greet the user and set the scene in one or two sentences.",
        history: [ChatTurn.system(systemPrompt)],
      )) {
        buffer.write(chunk);
        if (!_writeStreamChunk(generation, index, buffer.toString())) return;
      }
      if (buffer.isEmpty) {
        throw Exception("The AI provider returned an empty response.");
      }
    } catch (e) {
      _writeStreamChunk(generation, index, "Error: $e");
    } finally {
      if (generation == _streamGeneration) {
        _isStreaming = false;
        _persistSessions();
        _notify();
      }
    }
  }

  /// Extract vocabulary words from a message using AI.
  /// Returns a list of words worth learning.
  Future<List<String>> extractVocabulary(String messageText) async {
    if (!aiConfigured) {
      // Surface the configuration problem via the banner instead
      // of pretending no words were found.
      _notify();
      return [];
    }
    final count = prefs.getInt("vocabularyExtractCount") ?? 10;
    final difficulty =
        prefs.getString("vocabularyDifficulty") ??
        "uncommon, academic, or idiomatic";

    final template = AIPrompts().vocabularyPrompt;
    final prompt = template
        .replaceAll(r"$count", count.toString())
        .replaceAll(r"$difficulty", difficulty)
        .replaceAll(r"$text", messageText);

    try {
      final response = await _ai.request(prompt);
      var jsonStr = response.trim();
      if (jsonStr.startsWith("```")) {
        final start = jsonStr.indexOf("\n") + 1;
        final end = jsonStr.lastIndexOf("```");
        jsonStr = jsonStr.substring(start, end).trim();
      }
      final list = json.decode(jsonStr) as List;
      // Materialize eagerly: AI output often drifts from plain
      // strings ({"word": ...} objects, numbers). A lazy cast would
      // throw later, inside the dialog's build.
      return [
        for (final e in list)
          if (e is String && e.trim().isNotEmpty)
            e.trim()
          else if (e is Map && e["word"] != null)
            e["word"].toString(),
      ];
    } catch (e) {
      return [];
    }
  }

  /// Save a word to the wordbook.
  Future<bool> saveWordToWordbook(String word) async {
    try {
      final dao = WordbookDao(mainDatabase);
      await dao.addWord(word);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Images -----------------------------------------------------------

  final List<String> _pendingImagePaths = [];

  /// Images attached to the message being composed.
  List<String> get pendingImagePaths => List.unmodifiable(_pendingImagePaths);

  Future<Directory> _chatImagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory("${docs.path}/chat_images");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copy a picked image into app storage and attach it to the
  /// message being composed. False when the copy failed.
  Future<bool> addPendingImage(String sourcePath) async {
    try {
      final dir = await _chatImagesDir();
      final dot = sourcePath.lastIndexOf(".");
      final ext = dot >= 0 ? sourcePath.substring(dot) : ".jpg";
      final name = "${DateTime.now().microsecondsSinceEpoch}$ext";
      final dest = "${dir.path}/$name";
      await File(sourcePath).copy(dest);
      _pendingImagePaths.add(dest);
      _notify();
      return true;
    } catch (_) {
      return false;
    }
  }

  void removePendingImage(String path) {
    _pendingImagePaths.remove(path);
    _notify();
    unawaited(_deleteFile(path));
  }

  Future<void> _deleteFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  void _deleteMessageImages(Iterable<ChatMessage> messages) {
    for (final message in messages) {
      for (final path in message.imagePaths) {
        unawaited(_deleteFile(path));
      }
    }
  }

  /// Encode an image file as a base64 data URL for the AI request.
  /// Null when the file is gone or unreadable.
  Future<String?> _imageDataUrl(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final lower = path.toLowerCase();
      final contentType = lower.endsWith(".png")
          ? "image/png"
          : lower.endsWith(".webp")
          ? "image/webp"
          : lower.endsWith(".gif")
          ? "image/gif"
          : "image/jpeg";
      return "data:$contentType;base64,${base64Encode(bytes)}";
    } catch (_) {
      return null;
    }
  }

  /// Whether the current provider can generate images at all.
  bool get imageGenerationSupported =>
      ModelProviderManager.supportsImageGeneration(settings.aiProvider);

  /// The image model that generation will use: the one saved for
  /// the provider, else its first known image model, else "".
  String get currentImageModel {
    final saved =
        settings
            .getAiProviderConfig(settings.aiProvider)["imageModel"]
            ?.toString()
            .trim() ??
        "";
    if (saved.isNotEmpty) return saved;
    final known = ModelProviderManager.getImageModels(settings.aiProvider);
    return known.isNotEmpty ? known.first.originName : "";
  }

  Future<void> setImageModel(String model) async {
    await settings.saveAiProviderImageModel(settings.aiProvider, model);
    _notify();
  }

  /// Write a generated image into the placeholder at [index],
  /// under the same staleness rules as streamed text.
  bool _writeGeneratedImage(int generation, int index, String path) {
    if (_disposed || generation != _streamGeneration) return false;
    if (index < 0 || index >= _active.messages.length) return false;
    _active.messages[index] = ChatMessage(
      text: "",
      isUser: false,
      imagePaths: [path],
    );
    notifyListeners();
    return true;
  }

  /// Generate an image from the typed prompt with the current
  /// provider's image model. The result lands as an AI message
  /// holding the saved image file.
  Future<void> generateImage() async {
    final prompt = textController.text.trim();
    if (prompt.isEmpty || _isStreaming) {
      return;
    }
    final provider = settings.aiProvider;
    final config = settings.getAiProviderConfig(provider);
    final imageModel = currentImageModel;
    final apiKey = config["apiKey"]?.toString() ?? "";
    if (!imageGenerationSupported ||
        imageModel.isEmpty ||
        (!keylessAiProviders.contains(provider) && apiKey.trim().isEmpty)) {
      // The image-mode bar in the UI explains what is missing;
      // keep the typed prompt and do nothing.
      _notify();
      return;
    }

    final generation = _streamGeneration;
    textController.clear();
    _active.messages.add(ChatMessage(text: prompt, isUser: true));
    _active.messages.add(const ChatMessage(text: "", isUser: false));
    final index = _active.messages.length - 1;
    _isStreaming = true;
    notifyListeners();

    try {
      final bytes = await AiImageGenerator.generate(
        provider: provider,
        model: imageModel,
        prompt: prompt,
        apiKey: apiKey,
        customApiUrl: settings.aiAPIUrl,
      );
      final dir = await _chatImagesDir();
      final path = "${dir.path}/${DateTime.now().microsecondsSinceEpoch}.png";
      await File(path).writeAsBytes(bytes);
      _writeGeneratedImage(generation, index, path);
    } catch (e) {
      _writeStreamChunk(generation, index, "Error: $e");
    } finally {
      if (generation == _streamGeneration) {
        _isStreaming = false;
        _persistSessions();
        _notify();
      }
    }
  }

  Future<void> sendMessage() async {
    final text = textController.text.trim();
    if ((text.isEmpty && _pendingImagePaths.isEmpty) || _isStreaming) {
      return;
    }
    if (!aiConfigured) {
      // Keep the typed text, change nothing, and let the rebuild
      // show the configuration banner — a silent no-op here is how
      // a missing model/key used to look like a dead feature.
      _notify();
      return;
    }

    final generation = _streamGeneration;
    final session = _active;
    final attachedPaths = List<String>.of(_pendingImagePaths);
    _pendingImagePaths.clear();
    textController.clear();

    // Encode attachments before adding messages, so a slow read
    // cannot interleave with the placeholder bookkeeping.
    final imageDataUrls = <String>[];
    for (final path in attachedPaths) {
      final dataUrl = await _imageDataUrl(path);
      if (dataUrl != null) imageDataUrls.add(dataUrl);
    }
    if (generation != _streamGeneration) return;

    session.messages.add(
      ChatMessage(text: text, isUser: true, imagePaths: attachedPaths),
    );
    // Placeholder for the streaming AI response.
    session.messages.add(const ChatMessage(text: "", isUser: false));
    final index = session.messages.length - 1;
    _isStreaming = true;
    notifyListeners();

    // Build history from prior turns (excluding the placeholder).
    // If there's initial context (e.g. a word), prepend it as a system hint.
    // If in a scenario, prepend the scenario system prompt from the template.
    // History is text-only: attached images are sent with the turn
    // they belong to, not re-uploaded on every later turn.
    // The word context lives in history (not inlined into the first
    // prompt) so every round's message list is a strict prefix-extension
    // of the previous round's — the shape prefix caching needs.
    final history = [
      if (_scenario != null) ChatTurn.system(_buildScenarioSystemPrompt()),
      if (session.initialContext != null)
        ChatTurn.system(
          "The user is asking about the word \"${session.initialContext}\".",
        ),
      for (final m in session.messages.sublist(0, session.messages.length - 2))
        ChatTurn(m.text, m.isUser),
    ];

    final effectivePrompt = text.isEmpty && imageDataUrls.isNotEmpty
        ? "Describe this image."
        : text;

    final buffer = StringBuffer();
    try {
      await for (final chunk in _ai.requestStreamWithHistory(
        effectivePrompt,
        history: history,
        promptImages: imageDataUrls,
      )) {
        buffer.write(chunk);
        if (!_writeStreamChunk(generation, index, buffer.toString())) return;
      }
      if (buffer.isEmpty) {
        throw Exception("The AI provider returned an empty response.");
      }
    } catch (e) {
      _writeStreamChunk(generation, index, "Error: $e");
    } finally {
      if (generation == _streamGeneration) {
        _isStreaming = false;
        _persistSessions();
        _notify();
      }
    }
  }
}
