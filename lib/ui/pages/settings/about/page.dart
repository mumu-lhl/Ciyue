import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:material_ui/material_ui.dart";

import "about_tile.dart";
import "changelog_tile.dart";
import "discord_tile.dart";
import "documentation_tile.dart";
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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.about)),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: const [
              SettingsGroupCard(
                children: [
                  DocumentationTile(),
                  FeedbackTile(),
                  GithubTile(),
                  DiscordTile(),
                  QQGroupTile(),
                  SponsorListTile(),
                ],
              ),
              SizedBox(height: 16),
              SettingsGroupCard(
                children: [
                  TermsOfServicePageListTile(),
                  PrivacyPolicyPageListTile(),
                  ChangelogPageListTile(),
                  AboutPageListTile(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
