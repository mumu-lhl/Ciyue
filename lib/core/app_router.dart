import "package:ciyue/ui/pages/writing_check/writing_check.dart";
import "package:ciyue/ui/pages/writing_check/writing_check_history.dart";
import "package:ciyue/ui/core/word_display.dart";
import "package:ciyue/ui/pages/main/main.dart";
import "package:ciyue/ui/pages/settings/about.dart";
import "package:ciyue/ui/pages/settings/ai_settings.dart";
import "package:ciyue/ui/pages/settings/appearance.dart";
import "package:ciyue/ui/pages/settings/audio.dart";
import "package:ciyue/ui/pages/settings/auto_export.dart";
import "package:ciyue/ui/pages/settings/backup.dart";
import "package:ciyue/ui/pages/settings/history.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/properties.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/settings_dictionary.dart";
import "package:ciyue/ui/pages/settings/other.dart";
import "package:ciyue/ui/pages/settings/privacy_policy.dart";
import "package:ciyue/ui/pages/settings/terms_of_service.dart";
import "package:ciyue/ui/pages/settings/update.dart";
import "package:ciyue/ui/pages/settings/logger.dart";
import "package:ciyue/ui/core/ai_explanation_edit_page.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:ciyue/ui/pages/settings/storage_management.dart";
import "package:ciyue/viewModels/storage_management.dart";
import "package:provider/provider.dart";

final navigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: navigatorKey,
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) {
        return const Home();
      },
    ),
    GoRoute(
      path: "/word",
      builder: (context, state) {
        final extra = state.extra as Map<String, String>;
        return WordDisplay(word: extra["word"]!);
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
            )),
    GoRoute(
      path: "/settings/autoExport",
      builder: (context, state) => const AutoExportSettingsPage(),
    ),
    GoRoute(
      path: "/settings/dictionaries",
      builder: (context, state) => const ManageDictionariesPage(),
    ),
    GoRoute(
      path: "/settings/ai_settings",
      builder: (context, state) => const AiSettingsPage(),
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
      path: "/settings/update",
      builder: (context, state) => const UpdateSettingsPage(),
    ),
    GoRoute(
      path: "/settings/other",
      builder: (context, state) => const OtherSettingsPage(),
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
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => StorageManagementViewModel(),
        child: const StorageManagementPage(),
      ),
    ),
    GoRoute(
        path: "/properties",
        builder: (context, state) => PropertiesDictionaryPage(
              path: (state.extra as Map<String, dynamic>)["path"],
              id: (state.extra as Map<String, dynamic>)["id"],
            )),
    GoRoute(
      path: "/writing_check",
      builder: (context, state) => const WritingCheckPage(),
    ),
    GoRoute(
      path: "/writing_check/history",
      builder: (context, state) => const WritingCheckHistoryPage(),
    ),
    GoRoute(
      path: "/settings/logs",
      builder: (context, state) => const LogsPage(),
    ),
  ],
);
