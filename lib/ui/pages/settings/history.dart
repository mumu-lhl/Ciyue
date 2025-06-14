import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";

class ClearHistory extends StatelessWidget {
  const ClearHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.delete),
      title: Text(locale!.clearHistory),
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
                if (context.mounted) {
                  context.read<HistoryModel>().clearHistory();
                  context.pop(context);
                }
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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.about),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: const [
              HistorySwitch(),
              ClearHistory(),
            ],
          ),
        ),
      ),
    );
  }
}

class HistorySwitch extends StatelessWidget {
  const HistorySwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryModel>(builder: (context, model, child) {
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
    });
  }
}
