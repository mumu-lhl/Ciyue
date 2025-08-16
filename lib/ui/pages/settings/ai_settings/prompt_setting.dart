import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/title_text.dart";
import "package:flutter/material.dart";

class PromptSetting extends StatelessWidget {
  const PromptSetting({
    super.key,
    required this.title,
    required this.initialValue,
    required this.helperText,
    required this.onChanged,
    required this.onReset,
  });

  final String title;
  final String initialValue;
  final String helperText;
  final Future<void> Function(String) onChanged;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleText(title),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(initialValue),
          initialValue: initialValue,
          maxLines: null,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            helperText: helperText,
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onReset,
            child: Text(AppLocalizations.of(context)!.resetToDefault),
          ),
        ),
      ],
    );
  }
}
