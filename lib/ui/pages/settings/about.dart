import "package:ciyue/main.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.about),
      ),
      body: ListView(
        children: const [
          FeedbackUrl(),
          GithubUrl(),
          DiscordUrl(),
          SponsorUrl(),
          TermsOfServicePageListTile(),
          PrivacyPolicyPageListTile(),
          AboutPageListTile()
        ],
      ),
    );
  }
}

class FeedbackUrl extends StatelessWidget {
  static const feedbackUri = "https://github.com/mumu-lhl/Ciyue/issues";

  const FeedbackUrl({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(AppLocalizations.of(context)!.feedback),
        subtitle: const Text(feedbackUri),
        leading: const Icon(Icons.feedback),
        onTap: () => launchUrl(Uri.parse(feedbackUri)),
        onLongPress: () => addToClipboard(context, feedbackUri));
  }
}

class GithubUrl extends StatelessWidget {
  static const githubUri = "https://github.com/mumu-lhl/Ciyue";

  const GithubUrl({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: const Text("Github"),
        subtitle: const Text(githubUri),
        leading: const Icon(Icons.public),
        onTap: () => launchUrl(Uri.parse(githubUri)),
        onLongPress: () => addToClipboard(context, githubUri));
  }
}

class DiscordUrl extends StatelessWidget {
  static const discordUri = "https://discord.gg/BazBZuvKZG";

  const DiscordUrl({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: const Text("Discord"),
        subtitle: const Text(discordUri),
        leading: const Icon(Icons.discord),
        onTap: () => launchUrl(Uri.parse(discordUri)),
        onLongPress: () => addToClipboard(context, discordUri));
  }
}

class SponsorUrl extends StatelessWidget {
  static const sponsorUri = "https://afdian.com/a/mumulhl";

  const SponsorUrl({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(AppLocalizations.of(context)!.sponsor),
        subtitle: const Text(sponsorUri),
        leading: const Icon(Icons.favorite),
        onTap: () => launchUrl(Uri.parse(sponsorUri)),
        onLongPress: () => addToClipboard(context, sponsorUri));
  }
}

class TermsOfServicePageListTile extends StatelessWidget {
  const TermsOfServicePageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.article),
      title: Text(AppLocalizations.of(context)!.termsOfService),
      onTap: () => context.push("/settings/terms_of_service"),
    );
  }
}

class PrivacyPolicyPageListTile extends StatelessWidget {
  const PrivacyPolicyPageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.security),
      title: Text(AppLocalizations.of(context)!.privacyPolicy),
      onTap: () => context.push("/settings/privacy_policy"),
    );
  }
}

class AboutPageListTile extends StatelessWidget {
  const AboutPageListTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AboutListTile(
      icon: const Icon(Icons.info),
      applicationName: packageInfo.appName,
      applicationVersion: "${packageInfo.version} (${packageInfo.buildNumber})",
      applicationLegalese: "\u{a9} 2024-2025 Mumulhl and contributors",
    );
  }
}
