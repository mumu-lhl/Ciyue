import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/changelog.dart";
import "package:ciyue/ui/core/changelog_dialog.dart";
import "package:ciyue/ui/pages/settings/about/sponsor_sheet.dart";
import "package:ciyue/utils.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "package:url_launcher/url_launcher.dart";

class AboutViewModel extends ChangeNotifier {
  // URIs and other constants
  static const feedbackUri = "https://github.com/mumu-lhl/Ciyue/issues";
  static const githubUri = "https://github.com/mumu-lhl/Ciyue";
  static const discordUri = "https://discord.gg/BazBZuvKZG";
  static const sponsorUri = "https://afdian.com/a/mumulhl";
  static const unifansSponsorUri = "https://app.unifans.io/c/mumulhl";
  static const qqGroupNumber = "1057888678";

  void launchUri(String uri) {
    launchUrl(Uri.parse(uri));
  }

  void copyToClipboard(BuildContext context, String text) {
    addToClipboard(context, text);
  }

  void openTermsOfService(BuildContext context) {
    context.push("/settings/terms_of_service");
  }

  void openPrivacyPolicy(BuildContext context) {
    context.push("/settings/privacy_policy");
  }

  Future<void> showChangelog(BuildContext context) async {
    final changelogContent = await ChangelogService.getChangelogContent(
        Localizations.localeOf(context));

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => ChangelogDialog(
        changelogContent: changelogContent,
      ),
    );
  }

  void showSponsorSheet(BuildContext context) {
    showAppSponsorSheet(context);
  }

  String get applicationVersion {
    final isDev = const bool.hasEnvironment("DEV");
    if (isDev) {
      final commitHash = const String.fromEnvironment("GIT_COMMIT_HASH");
      final timestampString = const String.fromEnvironment("BUILD_TIMESTAMP");

      if (timestampString.isNotEmpty) {
        final timestamp = int.tryParse(timestampString);
        if (timestamp != null) {
          final date =
              DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true)
                  .toLocal();
          return "${packageInfo.version} Dev ($commitHash) ${DateFormat("yyyy-MM-dd-HH:mm:ss").format(date)}";
        }
      }

      return "${packageInfo.version} Dev ($commitHash)";
    }

    return "${packageInfo.version} (${packageInfo.buildNumber})";
  }

  String get applicationName => packageInfo.appName;
  String get applicationLegalese => "\u{a9} 2024-2025 Mumulhl and contributors";
}
