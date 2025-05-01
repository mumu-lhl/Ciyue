import "package:ciyue/services/dictionary.dart";
import "package:flutter/material.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:go_router/go_router.dart";

class PropertiesDictionary extends StatelessWidget {
  final String path;

  const PropertiesDictionary({
    super.key,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final dict = Mdict(path: path);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder(
        future: dict.initOnlyMetadata(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context)!.title),
                subtitle: Text(dict.title),
              ),
              ListTile(
                title: Text(AppLocalizations.of(context)!.totalNumberOfEntries),
                subtitle: Text(dict.entriesTotal.toString()),
              ),
            ],
          );
        },
      ),
    );
  }
}
