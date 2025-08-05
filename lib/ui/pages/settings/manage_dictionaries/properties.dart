import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/dictionary_properties_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class PropertiesDictionaryPage extends StatelessWidget {
  final String path;
  final int id;

  const PropertiesDictionaryPage({
    super.key,
    required this.path,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DictionaryPropertiesViewModel()..fetchProperties(path, id),
      child: Scaffold(
        appBar: AppBar(),
        body: Consumer<DictionaryPropertiesViewModel>(
          builder: (context, model, child) {
            if (model.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Container(
              constraints: BoxConstraints(
                maxWidth: 500,
              ),
              child: ListView(
                children: [
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.title),
                    subtitle: Text(model.title),
                  ),
                  ListTile(
                    title: Text(
                        AppLocalizations.of(context)!.totalNumberOfEntries),
                    subtitle: Text(model.entriesTotal.toString()),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
