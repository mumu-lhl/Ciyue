import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

class HomeGroupSwitcher extends StatelessWidget {
  const HomeGroupSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    final (groupId, isSwitching, pendingGroupId, _) = context
        .select<DictManagerModel, (int, bool, int?, int)>(
          (model) => (
            model.groupId,
            model.isSwitchingGroup,
            model.pendingGroupId,
            model.state,
          ),
        );
    final displayedGroupId = isSwitching ? pendingGroupId ?? groupId : groupId;

    var groupName = locale.default_;
    for (final group in dictManager.groups) {
      if (group.id == displayedGroupId) {
        groupName = group.name == "Default" ? locale.default_ : group.name;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PopupMenuButton<int>(
              tooltip: locale.dictionaryGroups,
              enabled: !isSwitching && dictManager.groups.isNotEmpty,
              onSelected: (id) {
                context.read<DictManagerModel>().setCurrentGroup(id);
              },
              itemBuilder: (context) => [
                for (final group in dictManager.groups)
                  PopupMenuItem<int>(
                    value: group.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          group.id == groupId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            group.name == "Default"
                                ? locale.default_
                                : group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSwitching)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.library_books_outlined, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isSwitching
                            ? locale.switchingToDictionaryGroup(groupName)
                            : locale.currentDictionaryGroup(groupName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          if (isSwitching) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
