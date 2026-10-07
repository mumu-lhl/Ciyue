import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(elevation: 10, child: HomeDrawerList(isDrawer: true));
  }
}

class HomeDrawerList extends StatelessWidget {
  final bool isDrawer;

  const HomeDrawerList({super.key, this.isDrawer = false});

  @override
  Widget build(BuildContext context) {
    final (groupId, isSwitchingGroup, _) = context
        .select<DictManagerModel, (int, bool, int)>(
          (model) => (model.groupId, model.isSwitchingGroup, model.state),
        );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          DrawerHeader(
            child: Text(
              AppLocalizations.of(context)!.dictionaryGroups,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          for (final group in dictManager.groups)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: group.id == groupId
                    ? const Icon(Icons.radio_button_checked, size: 20)
                    : const Icon(Icons.radio_button_unchecked, size: 20),
                title: Text(
                  group.name == "Default"
                      ? AppLocalizations.of(context)!.default_
                      : group.name,
                ),
                onTap: isSwitchingGroup
                    ? null
                    : () async {
                        if (isDrawer) {
                          context.pop();
                        }
                        if (group.id != groupId) {
                          await context
                              .read<DictManagerModel>()
                              .setCurrentGroup(group.id);
                        }
                      },
              ),
            ),
        ],
      ),
    );
  }
}
