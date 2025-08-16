import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/utils.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "package:ciyue/viewModels/settings/about_view_model.dart"; // For the URIs

void showAppSponsorSheet(BuildContext context) {
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
                    .withAlpha(77),
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
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _SponsorLinkCard(
                iconData: Icons.volunteer_activism,
                title: "爱发电 Afdian",
                uri: AboutViewModel.sponsorUri,
              ),
              const SizedBox(height: 12),
              const _SponsorLinkCard(
                iconData: Icons.public,
                title: "引力圈 Unifans (Global)",
                uri: AboutViewModel.unifansSponsorUri,
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

class _SponsorLinkCard extends StatelessWidget {
  final IconData iconData;
  final String title;
  final String uri;

  const _SponsorLinkCard({
    required this.iconData,
    required this.title,
    required this.uri,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final localizations = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                    iconData,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        uri,
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
                    Uri.parse(uri),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(localizations.openLink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => addToClipboard(context, uri),
                icon: const Icon(Icons.copy_rounded),
                label: Text(localizations.copyLink),
              ),
            ),
          ],
        ),
      ],
    );
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
