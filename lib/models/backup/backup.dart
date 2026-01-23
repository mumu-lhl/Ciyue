import "dart:convert";

import "package:ciyue/database/app/app.dart";

class BackupData {
  final int version;
  final List<WordbookData> wordbookWords;
  final List<WordbookTag> wordbookTags;
  final List<String> history;

  BackupData({
    required this.version,
    required this.wordbookWords,
    required this.wordbookTags,
    this.history = const [],
  });

  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      version: json["version"] as int,
      wordbookWords: (json["wordbookWords"] as List<dynamic>)
          .map((e) => WordbookData.fromJson(e as Map<String, dynamic>))
          .toList(),
      wordbookTags: (json["wordbookTags"] as List<dynamic>)
          .map((e) => WordbookTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      history: (json["history"] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  String toJson() {
    return jsonEncode({
      "version": version,
      "wordbookWords": wordbookWords.map((e) => e.toJson()).toList(),
      "wordbookTags": wordbookTags.map((e) => e.toJson()).toList(),
      "history": history,
    });
  }
}

