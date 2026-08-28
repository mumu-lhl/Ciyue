import "package:ciyue/viewModels/settings/about_view_model.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

class AboutPageListTile extends StatelessWidget {
  const AboutPageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AboutViewModel>(context, listen: false);
    return AboutListTile(
      icon: const Icon(Icons.info),
      applicationName: viewModel.applicationName,
      applicationVersion: viewModel.applicationVersion,
      applicationLegalese: viewModel.applicationLegalese,
    );
  }
}
