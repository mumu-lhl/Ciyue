import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "about_tile.dart";
import "changelog_tile.dart";
import "discord_tile.dart";
import "feedback_tile.dart";
import "github_tile.dart";
import "privacy_policy_tile.dart";
import "qq_group_tile.dart";
import "sponsor_tile.dart";
import "terms_of_service_tile.dart";

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AboutViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.about),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              children: const [
                FeedbackTile(),
                GithubTile(),
                DiscordTile(),
                QQGroupTile(),
                SponsorListTile(),
                TermsOfServicePageListTile(),
                PrivacyPolicyPageListTile(),
                ChangelogPageListTile(),
                AboutPageListTile(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
