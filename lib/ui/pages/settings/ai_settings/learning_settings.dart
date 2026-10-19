import "package:ciyue/core/app_globals.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class LearningSettings extends ConsumerStatefulWidget {
  const LearningSettings({super.key});

  @override
  ConsumerState<LearningSettings> createState() => _LearningSettingsState();
}

class _LearningSettingsState extends ConsumerState<LearningSettings> {
  late int _quizCount;
  late int _vocabCount;
  late String _difficulty;

  static const List<String> difficulties = [
    "uncommon, academic, or idiomatic",
    "academic",
    "idiomatic",
    "advanced",
  ];

  @override
  void initState() {
    super.initState();
    _quizCount = prefs.getInt("quizQuestionCount") ?? 5;
    _vocabCount = prefs.getInt("vocabularyExtractCount") ?? 10;
    _difficulty =
        prefs.getString("vocabularyDifficulty") ?? difficulties[0];
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Column(
      children: [
        ListTile(
          title: Text(locale.quizQuestionCount),
          subtitle: Slider(
            value: _quizCount.toDouble(),
            min: 3,
            max: 20,
            divisions: 17,
            label: _quizCount.toString(),
            onChanged: (v) async {
              setState(() => _quizCount = v.round());
              await prefs.setInt("quizQuestionCount", _quizCount);
            },
          ),
          trailing: Text(_quizCount.toString()),
        ),
        const Divider(),
        ListTile(
          title: Text(locale.vocabularyExtractCount),
          subtitle: Slider(
            value: _vocabCount.toDouble(),
            min: 5,
            max: 20,
            divisions: 15,
            label: _vocabCount.toString(),
            onChanged: (v) async {
              setState(() => _vocabCount = v.round());
              await prefs.setInt("vocabularyExtractCount", _vocabCount);
            },
          ),
          trailing: Text(_vocabCount.toString()),
        ),
        const Divider(),
        ListTile(
          title: Text(locale.vocabularyDifficulty),
          trailing: DropdownButton<String>(
            value: _difficulty,
            items: [
              for (final d in difficulties)
                DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: (v) async {
              if (v != null) {
                setState(() => _difficulty = v);
                await prefs.setString("vocabularyDifficulty", v);
              }
            },
          ),
        ),
      ],
    );
  }
}
