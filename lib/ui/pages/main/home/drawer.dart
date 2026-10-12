import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(elevation: 10, child: HomeDrawerList(isDrawer: true));
  }
}

class HomeDrawerList extends ConsumerWidget {
  final bool isDrawer;

  const HomeDrawerList({super.key, this.isDrawer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dictManagerModel = ref.watch(dictManagerModelProvider);
    final groupId = dictManagerModel.groupId;
    final isSwitchingGroup = dictManagerModel.isSwitchingGroup;

    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.collections_bookmark_rounded,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.dictionaryGroups,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            for (final group in dictManager.groups)
              Card(
                color: group.id == groupId
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : theme.colorScheme.surfaceContainerLow,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: group.id == groupId
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                  ),
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(
                    group.id == groupId
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: group.id == groupId
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(
                    group.name == "Default"
                        ? AppLocalizations.of(context)!.default_
                        : group.name,
                    style: TextStyle(
                      fontWeight: group.id == groupId
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: isSwitchingGroup
                      ? null
                      : () async {
                          if (isDrawer) {
                            context.pop();
                          }
                          if (group.id != groupId) {
                            await ref
                                .read(dictManagerModelProvider)
                                .setCurrentGroup(group.id);
                          }
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
