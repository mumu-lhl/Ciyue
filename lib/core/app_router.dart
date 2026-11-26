import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/store.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/chat/chat.dart";
import "package:ciyue/ui/pages/quiz/quiz_page.dart";
import "package:ciyue/ui/pages/writing_check/writing_check.dart";
import "package:ciyue/ui/pages/writing_check/writing_check_history.dart";
import "package:ciyue/ui/pages/writing_check/writing_check_settings.dart";
import "package:ciyue/ui/core/word_display.dart";
import "package:ciyue/utils.dart";
import "package:ciyue/ui/pages/main/main.dart";
import "package:ciyue/ui/pages/settings/about.dart";
import "package:ciyue/ui/pages/settings/ai_settings.dart";
import "package:ciyue/ui/pages/settings/appearance.dart";
import "package:ciyue/ui/pages/settings/audio.dart";
import "package:ciyue/ui/pages/settings/auto_export.dart";
import "package:ciyue/ui/pages/settings/backup.dart";
import "package:ciyue/ui/pages/settings/cloud_sync.dart";
import "package:ciyue/ui/pages/settings/history.dart";
import "package:ciyue/ui/pages/settings/hunspell.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/full_text_index_overview.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/properties.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/settings_dictionary.dart";
import "package:ciyue/ui/pages/settings/personal_dictionary/personal_dictionary_entries_page.dart";
import "package:ciyue/ui/pages/settings/personal_dictionary/personal_dictionary_entry_editor_page.dart";
import "package:ciyue/ui/pages/settings/other.dart";
import "package:ciyue/ui/pages/settings/privacy_policy.dart";
import "package:ciyue/ui/pages/settings/terms_of_service.dart";
import "package:ciyue/ui/pages/settings/update.dart";
import "package:ciyue/ui/pages/settings/web_service.dart";
import "package:ciyue/ui/pages/settings/logs.dart";
import "package:ciyue/ui/pages/settings/wordbook_stats.dart";
import "package:ciyue/ui/pages/store/store_page.dart";
import "package:ciyue/ui/core/ai_explanation_edit_page.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";
import "package:go_router/go_router.dart";
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/ui/pages/settings/file_manager.dart";
import "package:ciyue/ui/pages/settings/storage_management.dart";
import "package:ciyue/ui/pages/flashcards/settings.dart";
import "package:ciyue/ui/pages/flashcards/study_page.dart";
import "package:ciyue/ui/pages/full_text_search_page.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:talker_flutter/talker_flutter.dart";

final navigatorKey = GlobalKey<NavigatorState>();

/// Parses a route id, or null when the link carries a non-numeric value:
/// a malformed deep link must land on the not-found page, not throw a
/// [FormatException] inside the route builder.
int? _tryParseRouteId(String? raw) => int.tryParse(raw ?? "");

final router = GoRouter(
  navigatorKey: navigatorKey,
  observers: [TalkerRouteObserver(talker), FlutterSmartDialog.observer],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context)!.notFound)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          AppLocalizations.of(context)!.notFound,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  ),
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) {
        return const Home();
      },
    ),
    GoRoute(
      path: "/word/:word",
      builder: (context, state) {
        final word = state.pathParameters["word"];
        final extra = state.extra;

        if (extra is WordListContext && extra.words.isNotEmpty) {
          return WordDisplayPager(
            words: extra.words,
            initialIndex: extra.initialIndex,
          );
        }

        unawaited(
          ProviderScope.containerOf(
            navigatorKey.currentContext!,
            listen: false,
          ).read(openRecordsRepositoryProvider).add(word!),
        );

        final dictIdParam = state.uri.queryParameters["dictId"];
        final initialDictId = dictIdParam != null
            ? int.tryParse(dictIdParam)
            : null;

        if (!isLargeScreen(context)) {
          return MobileWordBrowser(
            initialWord: word,
            initialDictId: initialDictId,
          );
        }

        return WordDisplay(
          word: word,
          initialDictId: initialDictId,
          syncSelectionOnOpen: true,
        );
      },
    ),
    GoRoute(
      path: "/full-text-search",
      builder: (context, state) {
        final query = state.uri.queryParameters["query"] ?? "";
        return FullTextSearchPage(initialQuery: query);
      },
    ),
    GoRoute(
      path: "/edit_ai_explanation",
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return AIExplanationEditPage(
          word: extra["word"]! as String,
          initialExplanation: extra["initialExplanation"]! as String,
          aiExplanationModel: extra["aiExplanationModel"] as AIExplanationModel,
        );
      },
    ),
    GoRoute(
      path: "/description/:dictId",
      builder: (context, state) => WebviewDisplayDescription(
        dictId: int.parse(state.pathParameters["dictId"]!),
      ),
    ),
    GoRoute(
      path: "/settings/autoExport",
      builder: (context, state) => const AutoExportSettingsPage(),
    ),
    GoRoute(
      path: "/settings/dictionaries",
      builder: (context, state) => const ManageDictionariesPage(),
    ),
    GoRoute(
      path: "/settings/personal_dictionary/:dictionaryId",
      builder: (context, state) {
        final extra = state.extra;
        final title = extra is Map<String, dynamic>
            ? extra["title"] as String?
            : null;
        final dictionaryId = _tryParseRouteId(
          state.pathParameters["dictionaryId"],
        );
        if (dictionaryId == null) {
          return const PersonalDictionaryNotFoundPage();
        }
        return PersonalDictionaryEntriesPage(
          dictionaryId: dictionaryId,
          title: title,
        );
      },
    ),
    GoRoute(
      path: "/settings/personal_dictionary/:dictionaryId/entry/new",
      builder: (context, state) {
        final dictionaryId = _tryParseRouteId(
          state.pathParameters["dictionaryId"],
        );
        if (dictionaryId == null) {
          return const PersonalDictionaryNotFoundPage();
        }
        return PersonalDictionaryEntryEditorPage(dictionaryId: dictionaryId);
      },
    ),
    GoRoute(
      path: "/settings/personal_dictionary/:dictionaryId/entry/:articleId",
      builder: (context, state) {
        final dictionaryId = _tryParseRouteId(
          state.pathParameters["dictionaryId"],
        );
        final articleId = _tryParseRouteId(state.pathParameters["articleId"]);
        if (dictionaryId == null || articleId == null) {
          return const PersonalDictionaryNotFoundPage();
        }
        return PersonalDictionaryEntryEditorPage(
          dictionaryId: dictionaryId,
          articleId: articleId,
        );
      },
    ),
    GoRoute(
      path: "/settings/ai_settings",
      builder: (context, state) => const AiSettingsPage(),
    ),
    GoRoute(
      path: "/settings/ai_settings/prompts",
      builder: (context, state) => const AiPromptsPage(),
    ),
    GoRoute(
      path: "/settings/terms_of_service",
      builder: (context, state) => const TermsOfServicePage(),
    ),
    GoRoute(
      path: "/settings/privacy_policy",
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
    GoRoute(
      path: "/settings/audio",
      builder: (context, state) => const AudioSettingsPage(),
    ),
    GoRoute(
      path: "/settings/appearance",
      builder: (context, state) => const AppearanceSettingsPage(),
    ),
    GoRoute(
      path: "/settings/backup",
      builder: (context, state) => const BackupSettingsPage(),
    ),
    GoRoute(
      path: "/settings/cloud_sync",
      builder: (context, state) => const CloudSyncSettingsPage(),
    ),
    GoRoute(
      path: "/settings/web_service",
      builder: (context, state) => const WebServiceSettingsPage(),
    ),
    GoRoute(
      path: "/settings/update",
      builder: (context, state) => const UpdateSettingsPage(),
    ),
    GoRoute(
      path: "/settings/other",
      builder: (context, state) => const OtherSettingsPage(),
    ),
    GoRoute(
      path: "/settings/hunspell",
      builder: (context, state) => const HunspellSettingsPage(),
    ),
    GoRoute(
      path: "/store",
      builder: (context, state) => StorePage(
        initialType: StoreItemType.tryParse(state.uri.queryParameters["type"]),
      ),
    ),
    GoRoute(
      path: "/settings/about",
      builder: (context, state) => const AboutSettingsPage(),
    ),
    GoRoute(
      path: "/settings/history",
      builder: (context, state) => const HistorySettingsPage(),
    ),
    GoRoute(
      path: "/settings/dictionary/:dictId",
      builder: (context, state) => SettingsDictionaryPage(
        dictId: int.parse(state.pathParameters["dictId"]!),
      ),
    ),
    GoRoute(
      path: "/settings/storage_management",
      builder: (context, state) => const StorageManagementPage(),
    ),
    GoRoute(
      path: "/settings/storage_management/file_manager",
      builder: (context, state) => const FileManagerPage(),
    ),
    GoRoute(
      path: "/properties",
      builder: (context, state) => PropertiesDictionaryPage(
        path: (state.extra as Map<String, dynamic>)["path"],
        id: (state.extra as Map<String, dynamic>)["id"],
      ),
    ),
    GoRoute(
      path: "/full-text-index-overview",
      builder: (context, state) => const FullTextIndexOverviewPage(),
    ),
    GoRoute(
      path: "/writing_check",
      builder: (context, state) => const WritingCheckPage(),
    ),
    GoRoute(
      path: "/writing_check/history",
      builder: (context, state) => const WritingCheckHistoryPage(),
    ),
    GoRoute(
      path: "/writing_check/settings",
      builder: (context, state) => const WritingCheckSettingsPage(),
    ),
    GoRoute(
      path: "/settings/logs",
      builder: (context, state) => const LogsPage(),
    ),
    GoRoute(
      path: "/chat",
      builder: (context, state) {
        final word = state.uri.queryParameters["word"];
        return ChatPage(initialContext: word);
      },
    ),
    GoRoute(path: "/quiz", builder: (context, state) => const QuizPage()),
    GoRoute(
      path: "/settings/wordbook_stats",
      builder: (context, state) => const WordbookStatsPage(),
    ),
    GoRoute(
      path: "/flashcards/review",
      builder: (context, state) => FlashcardStudyPage(
        tag: int.tryParse(state.uri.queryParameters["tag"] ?? ""),
      ),
    ),
    GoRoute(
      path: "/settings/flashcards",
      builder: (context, state) => const FlashcardSettingsPage(),
    ),
  ],
);
