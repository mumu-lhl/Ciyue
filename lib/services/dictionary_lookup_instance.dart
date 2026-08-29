import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup.dart";
import "package:ciyue/services/hunspell.dart";

final dictionaryLookup = DictionaryLookup(
  dictionaries: () =>
      [for (final id in dictManager.dictIds) dictManager.dicts[id]]
          .whereType<DictionarySource>()
          .toList(growable: false),
  morphology: hunspellManager,
  morphologyEnabled: () => settings.enableHunspellMorphology,
  lookupMode: () => settings.hunspellLookupMode,
);
