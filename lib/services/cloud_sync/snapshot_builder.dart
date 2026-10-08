import "dart:convert";

import "package:ciyue/models/backup/backup.dart";
import "package:ciyue/services/cloud_sync/sync_models.dart";
import "package:crypto/crypto.dart";

/// Converts the existing local wordbook and FSRS backup data into stable,
/// versioned sync records. Pass the previous local snapshot to retain history
/// and express local deletions as tombstones.
class CloudSyncSnapshotBuilder {
  const CloudSyncSnapshotBuilder();

  SyncSnapshot capture({
    required BackupData data,
    required String spaceId,
    required String deviceId,
    SyncSnapshot? previous,
  }) {
    if (previous != null && previous.spaceId != spaceId) {
      throw ArgumentError("Previous snapshot belongs to another sync space.");
    }

    final current = _currentEntities(data);
    final records = [...?previous?.records];
    final previousGroups = <String, List<SyncRecord>>{};
    for (final record in records) {
      if (!_managedEntityTypes.contains(record.entityType)) continue;
      previousGroups
          .putIfAbsent(_key(record.entityType, record.entityId), () => [])
          .add(record);
    }

    for (final entity in current.values) {
      final key = _key(entity.entityType, entity.entityId);
      final versions = previousGroups[key] ?? const <SyncRecord>[];
      final heads = _heads(versions);
      if (heads.isEmpty) {
        records.add(_createVersion(entity, const [], null));
        continue;
      }

      if (heads.length > 1) {
        final maxParentTime = heads
            .map((head) => head.modifiedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        records.add(_createVersion(entity, heads, maxParentTime));
        continue;
      }

      final head = heads.single;
      if (!head.deleted && _sameJson(head.data, entity.data)) continue;
      records.add(_createVersion(entity, [head], head.modifiedAt));
    }

    for (final entry in previousGroups.entries) {
      if (current.containsKey(entry.key)) continue;
      final heads = _heads(entry.value);
      if (heads.isEmpty || heads.every((head) => head.deleted)) continue;
      if (heads.length > 1) {
        final maxParentTime = heads
            .map((head) => head.modifiedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        records.add(
          _createVersion(
            _SyncEntity(
              entityType: entry.value.first.entityType,
              entityId: entry.value.first.entityId,
              data: null,
              sourceTime: maxParentTime,
            ),
            heads,
            maxParentTime,
          ),
        );
        continue;
      }
      final head = heads.single;
      if (head.deleted) continue;
      records.add(
        _createVersion(
          _SyncEntity(
            entityType: head.entityType,
            entityId: head.entityId,
            data: null,
            sourceTime: head.modifiedAt,
          ),
          [head],
          head.modifiedAt,
        ),
      );
    }

    return SyncSnapshot(
      spaceId: spaceId,
      deviceId: deviceId,
      records: _sortRecords(records),
    );
  }

  Map<String, _SyncEntity> _currentEntities(BackupData data) {
    final tagsById = <int, String>{};
    for (final tag in data.wordbookTags) {
      final existing = tagsById[tag.id];
      if (existing != null && existing != tag.tag) {
        throw FormatException("Duplicate wordbook tag ID ${tag.id}.");
      }
      tagsById[tag.id] = tag.tag;
    }

    final result = <String, _SyncEntity>{};
    void add(_SyncEntity entity) {
      final key = _key(entity.entityType, entity.entityId);
      final existing = result[key];
      if (existing == null) {
        result[key] = entity;
      } else if (entity.entityType == "wordbook-entry") {
        final existingTime = DateTime.parse(
          existing.data!["createdAt"]! as String,
        );
        final candidateTime = DateTime.parse(
          entity.data!["createdAt"]! as String,
        );
        if (candidateTime.isBefore(existingTime)) {
          result[key] = entity;
        }
      } else if (!_sameJson(existing.data, entity.data)) {
        throw FormatException(
          "Local data contains conflicting '${entity.entityType}' records.",
        );
      }
    }

    for (final tag in data.wordbookTags) {
      final entityId = _stableId("wordbook-tag", tag.tag);
      add(
        _SyncEntity(
          entityType: "wordbook-tag",
          entityId: entityId,
          data: {"name": tag.tag},
          sourceTime: DateTime.utc(1970),
        ),
      );
    }

    for (final word in data.wordbookWords) {
      final tagName = word.tag == null ? null : tagsById[word.tag];
      if (word.tag != null && tagName == null) {
        throw FormatException(
          "Word '${word.word}' references missing wordbook tag ${word.tag}.",
        );
      }
      final identity = jsonEncode([word.word, tagName]);
      add(
        _SyncEntity(
          entityType: "wordbook-entry",
          entityId: _stableId("wordbook-entry", identity),
          data: {
            "word": word.word,
            "tagName": tagName,
            "createdAt": word.createdAt.toUtc().toIso8601String(),
          },
          sourceTime: word.createdAt.toUtc(),
        ),
      );
    }

    for (final card in data.flashcards) {
      add(
        _SyncEntity(
          entityType: "flashcard",
          entityId: _stableId("flashcard", card.word),
          data: {
            "word": card.word,
            "state": card.state,
            "step": card.step,
            "stability": card.stability,
            "difficulty": card.difficulty,
            "due": card.due.toUtc().toIso8601String(),
            "lastReview": card.lastReview?.toUtc().toIso8601String(),
            "introducedAt": card.introducedAt.toUtc().toIso8601String(),
          },
          sourceTime: card.lastReview?.toUtc() ?? card.introducedAt.toUtc(),
        ),
      );
    }

    for (final log in data.flashcardReviewLogs) {
      final event = {
        "word": log.word,
        "rating": log.rating,
        "reviewedAt": log.reviewedAt.toUtc().toIso8601String(),
        "durationMs": log.durationMs,
      };
      add(
        _SyncEntity(
          entityType: "flashcard-review-log",
          entityId: _stableId("flashcard-review-log", _canonicalJson(event)),
          data: event,
          sourceTime: log.reviewedAt.toUtc(),
        ),
      );
    }

    return result;
  }

  SyncRecord _createVersion(
    _SyncEntity entity,
    List<SyncRecord> parents,
    DateTime? parentTime,
  ) {
    final parentIds = parents.map((parent) => parent.versionId).toList()
      ..sort();
    final modifiedAt = parentTime == null
        ? entity.sourceTime
        : parentTime.add(const Duration(microseconds: 1));
    final content = {
      "entityType": entity.entityType,
      "entityId": entity.entityId,
      "parentVersionIds": parentIds,
      "data": entity.data,
      "deleted": entity.data == null,
    };
    final versionId = sha256
        .convert(utf8.encode(_canonicalJson(content)))
        .toString();
    return SyncRecord(
      entityType: entity.entityType,
      entityId: entity.entityId,
      versionId: versionId,
      parentVersionIds: parentIds,
      modifiedAt: modifiedAt,
      data: entity.data,
      deleted: entity.data == null,
    );
  }
}

const _managedEntityTypes = {
  "wordbook-tag",
  "wordbook-entry",
  "flashcard",
  "flashcard-review-log",
};

class _SyncEntity {
  final String entityType;
  final String entityId;
  final Map<String, Object?>? data;
  final DateTime sourceTime;

  const _SyncEntity({
    required this.entityType,
    required this.entityId,
    required this.data,
    required this.sourceTime,
  });
}

String _key(String type, String id) => "$type\u0000$id";

String _stableId(String type, String value) =>
    sha256.convert(utf8.encode("$type\u0000$value")).toString();

List<SyncRecord> _heads(List<SyncRecord> versions) {
  final parentIds = versions
      .expand((record) => record.parentVersionIds)
      .toSet();
  return versions
      .where((record) => !parentIds.contains(record.versionId))
      .toList(growable: false);
}

List<SyncRecord> _sortRecords(List<SyncRecord> records) {
  records.sort((a, b) {
    final typeOrder = a.entityType.compareTo(b.entityType);
    if (typeOrder != 0) return typeOrder;
    final entityOrder = a.entityId.compareTo(b.entityId);
    if (entityOrder != 0) return entityOrder;
    final timeOrder = a.modifiedAt.compareTo(b.modifiedAt);
    return timeOrder != 0 ? timeOrder : a.versionId.compareTo(b.versionId);
  });
  return records;
}

bool _sameJson(Object? first, Object? second) =>
    _canonicalJson(first) == _canonicalJson(second);

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key as String).toList()..sort();
    return {for (final key in keys) key: _canonicalize(value[key])};
  }
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
