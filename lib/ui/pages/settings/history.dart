import "package:ciyue/core/providers.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";

class ClearHistory extends ConsumerWidget {
  const ClearHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context);

    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.delete, color: theme.colorScheme.error),
      title: Text(
        locale!.clearHistory,
        style: TextStyle(color: theme.colorScheme.error),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(locale.clearHistory),
          content: Text(locale.clearHistoryConfirm),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(locale.close),
            ),
            TextButton(
              onPressed: () async {
                ref.read(historyModelProvider).clearHistory();
                context.pop(context);
              },
              child: Text(locale.confirm),
            ),
          ],
        ),
      ),
    );
  }
}

class HistorySettingsPage extends StatelessWidget {
  const HistorySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.history)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: const [
              SettingsGroupCard(children: [HistorySwitch(), ClearHistory()]),
            ],
          ),
        ),
      ),
    );
  }
}

class HistorySwitch extends ConsumerWidget {
  const HistorySwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(historyModelProvider);
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(AppLocalizations.of(context)!.enableHistory),
      trailing: Switch(
        value: model.enableHistory,
        onChanged: (value) {
          model.setEnableHistory(value);
        },
      ),
    );
  }
}
