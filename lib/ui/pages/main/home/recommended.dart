import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

class RecommendedDictionaries extends StatelessWidget {
  const RecommendedDictionaries({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(locale!.addDictionary),
          const SizedBox(height: 16),
          ElevatedButton(
            child: Text(locale.recommendedDictionaries),
            onPressed: () async {
              await launchUrl(Uri.parse(
                  "https://github.com/mumu-lhl/Ciyue/wiki#recommended-dictionaries"));
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            child: const Text("FreeMDict Cloud"),
            onPressed: () async {
              await launchUrl(Uri.parse(
                  "https://cloud.freemdict.com/index.php/s/pgKcDcbSDTCzXCs"));
            },
          ),
        ],
      ),
    );
  }
}
