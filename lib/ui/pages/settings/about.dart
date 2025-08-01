import "package:ciyue/core/app_globals.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";
import "package:ciyue/services/changelog.dart";
import "package:ciyue/ui/core/changelog_dialog.dart";

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.about),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            children: const [
              FeedbackUrl(),
              GithubUrl(),
              DiscordUrl(),
              SponsorListTile(),
              TermsOfServicePageListTile(),
              PrivacyPolicyPageListTile(),
              ChangelogPageListTile(),
              AboutPageListTile(),
            ],
          ),
        ),
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

class SponsorListTile extends StatelessWidget {
  static const sponsorUri = "https://afdian.com/a/mumulhl";

  const SponsorListTile({
    super.key,
  });

  void _showSponsorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.sponsor,
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.sponsorSupportTip,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.volunteer_activism,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "爱发电 Afdian",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                SponsorListTile.sponsorUri,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          launchUrl(
                            Uri.parse(SponsorListTile.sponsorUri),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: Text(AppLocalizations.of(context)!.openLink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          addToClipboard(context, SponsorListTile.sponsorUri);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      AppLocalizations.of(context)!.copied)),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(AppLocalizations.of(context)!.copyLink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  AppLocalizations.of(context)!.sponsorCodes,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _SponsorQrCard(
                        imagePath: "assets/wechat_pay.webp",
                        colorScheme: cs,
                        label: AppLocalizations.of(context)!.wechat,
                        labelStyle: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(AppLocalizations.of(context)!.sponsor),
        leading: const Icon(Icons.favorite),
        onTap: () => _showSponsorSheet(context),
        onLongPress: () => addToClipboard(context, sponsorUri));
  }
}

class _SponsorQrCard extends StatelessWidget {
  final String imagePath;
  final ColorScheme colorScheme;
  final String? label;
  final TextStyle? labelStyle;

  const _SponsorQrCard({
    required this.imagePath,
    required this.colorScheme,
    this.label,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final card = AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );

    if (label == null) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: card,
      );
    }

    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label!, style: labelStyle),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(4),
            child: card,
          ),
        ],
      ),
    );
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

class ChangelogPageListTile extends StatelessWidget {
  const ChangelogPageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(AppLocalizations.of(context)!.changelog),
      onTap: () async {
        final changelogContent = await ChangelogService.getChangelogContent(
            Localizations.localeOf(context));

        if (!context.mounted) return;

        showDialog(
          context: context,
          builder: (context) => ChangelogDialog(
            changelogContent: changelogContent,
          ),
        );
      },
    );
  }
}
