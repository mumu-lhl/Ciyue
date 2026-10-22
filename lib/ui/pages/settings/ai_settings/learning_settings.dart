import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/quiz_view_model.dart";
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
  late Set<String> _questionTypes;

  static const List<String> difficulties = [
    "uncommon, academic, or idiomatic",
    "academic",
    "idiomatic",
    "advanced",
  ];

  @override
  void initState() {
    super.initState();
    _quizCount = prefs.getInt("quizQuestionCount") ?? 20;
    _vocabCount = prefs.getInt("vocabularyExtractCount") ?? 10;
    _difficulty = prefs.getString("vocabularyDifficulty") ?? difficulties[0];
    _questionTypes = _loadQuestionTypes();
  }

  Set<String> _loadQuestionTypes() {
    try {
      final raw = prefs.getString("quizQuestionTypes");
      if (raw == null) return Set.of(QuizQuestionType.all);
      final list = (json.decode(raw) as List).cast<String>();
      final valid = list.where((t) => QuizQuestionType.all.contains(t)).toSet();
      return valid.isEmpty ? Set.of(QuizQuestionType.all) : valid;
    } catch (_) {
      return Set.of(QuizQuestionType.all);
    }
  }

  String _typeLabel(AppLocalizations locale, String type) {
    switch (type) {
      case QuizQuestionType.choice:
        return locale.questionTypeChoice;
      case QuizQuestionType.spelling:
        return locale.questionTypeSpelling;
      case QuizQuestionType.cloze:
        return locale.questionTypeCloze;
      default:
        return type;
    }
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
            max: 50,
            divisions: 47,
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
          title: Text(locale.questionTypes),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final type in QuizQuestionType.all)
                  FilterChip(
                    label: Text(_typeLabel(locale, type)),
                    selected: _questionTypes.contains(type),
                    onSelected: (selected) async {
                      setState(() {
                        if (selected) {
                          _questionTypes.add(type);
                        } else {
                          // Keep at least one type enabled.
                          if (_questionTypes.length > 1) {
                            _questionTypes.remove(type);
                          }
                        }
                      });
                      await prefs.setString(
                        "quizQuestionTypes",
                        json.encode(_questionTypes.toList()),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const Divider(),
        ListTile(
          title: Text(locale.vocabularyExtractCount),
          subtitle: Slider(
            value: _vocabCount.toDouble(),
            min: 5,
            max: 50,
            divisions: 45,
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
          // The difficulty values are long English phrases; as a trailing
          // dropdown they get squeezed into a vertical strip on phones.
          // Full width in the subtitle lets them lay out horizontally.
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: DropdownButton<String>(
              value: _difficulty,
              isExpanded: true,
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
        ),
      ],
    );
  }
}
