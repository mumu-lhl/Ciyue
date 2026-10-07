import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/dictionary_properties_view_model.dart";
import "package:material_ui/material_ui.dart";

class PropertiesDictionaryPage extends StatefulWidget {
  final String path;
  final int id;

  const PropertiesDictionaryPage({
    super.key,
    required this.path,
    required this.id,
  });

  @override
  State<PropertiesDictionaryPage> createState() =>
      _PropertiesDictionaryPageState();
}

class _PropertiesDictionaryPageState extends State<PropertiesDictionaryPage> {
  late final DictionaryPropertiesViewModel _model;

  @override
  void initState() {
    super.initState();
    _model = DictionaryPropertiesViewModel()
      ..fetchProperties(widget.path, widget.id);
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListenableBuilder(
        listenable: _model,
        builder: (context, child) {
          if (_model.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              children: [
                ListTile(
                  title: Text(AppLocalizations.of(context)!.title),
                  subtitle: Text(_model.title),
                ),
                ListTile(
                  title: Text(
                    AppLocalizations.of(context)!.totalNumberOfEntries,
                  ),
                  subtitle: Text(_model.entriesTotal.toString()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
