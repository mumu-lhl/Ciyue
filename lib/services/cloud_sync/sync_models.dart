import "dart:convert";

/// One immutable version of a logical record in the shared Ciyue sync space.
///
/// Updates and deletions create new versions that name the versions they
/// replace. Keeping versions append-only lets clients detect concurrent edits
/// instead of silently overwriting one device with another.
class SyncRecord {
  final String entityType;
  final String entityId;
  final String versionId;
  final List<String> parentVersionIds;
  final DateTime modifiedAt;
  final Map<String, Object?>? data;
  final bool deleted;

  SyncRecord({
    required this.entityType,
    required this.entityId,
    required this.versionId,
    required List<String> parentVersionIds,
    required this.modifiedAt,
    required Map<String, Object?>? data,
    required this.deleted,
  }) : parentVersionIds = List.unmodifiable(parentVersionIds),
       data = data == null ? null : Map.unmodifiable(data) {
    if (entityType.isEmpty || entityId.isEmpty || versionId.isEmpty) {
      throw ArgumentError("Sync record identity fields must not be empty.");
    }
    if (this.parentVersionIds.contains(versionId)) {
      throw ArgumentError("A sync record cannot be its own parent.");
    }
    if (deleted != (data == null)) {
      throw ArgumentError(
        "Deleted records must have no data; live records must have data.",
      );
    }
  }

  Map<String, Object?> toJson() => {
    "entityType": entityType,
    "entityId": entityId,
    "versionId": versionId,
    "parentVersionIds": parentVersionIds,
    "modifiedAt": modifiedAt.toUtc().toIso8601String(),
    "data": data,
    "deleted": deleted,
  };

  factory SyncRecord.fromJson(Map<String, Object?> json) {
    final rawParents = json["parentVersionIds"];
    final rawData = json["data"];
    return SyncRecord(
      entityType: json["entityType"]! as String,
      entityId: json["entityId"]! as String,
      versionId: json["versionId"]! as String,
      parentVersionIds: (rawParents! as List<Object?>).cast<String>(),
      modifiedAt: DateTime.parse(json["modifiedAt"]! as String),
      data: rawData == null ? null : Map<String, Object?>.from(rawData as Map),
      deleted: json["deleted"]! as bool,
    );
  }
}

/// A complete versioned sync payload for one Ciyue cloud folder.
class SyncSnapshot {
  static const currentFormatVersion = 1;

  final int formatVersion;
  final String spaceId;
  final String deviceId;
  final List<SyncRecord> records;

  SyncSnapshot({
    this.formatVersion = currentFormatVersion,
    required this.spaceId,
    required this.deviceId,
    required List<SyncRecord> records,
  }) : records = List.unmodifiable(records) {
    if (formatVersion != currentFormatVersion) {
      throw ArgumentError.value(formatVersion, "formatVersion", "Unsupported");
    }
    if (spaceId.isEmpty || deviceId.isEmpty) {
      throw ArgumentError("Sync space and device IDs must not be empty.");
    }
  }

  /// Returns the unshadowed versions of each record, including conflict heads.
  List<SyncRecord> get latestRecords {
    final groups = _groupRecords(records);
    final heads = <SyncRecord>[];
    for (final versions in groups.values) {
      final parentIds = versions
          .expand((record) => record.parentVersionIds)
          .toSet();
      heads.addAll(
        versions.where((record) => !parentIds.contains(record.versionId)),
      );
    }
    return _sortRecords(heads);
  }

  Map<String, Object?> toJson() => {
    "formatVersion": formatVersion,
    "spaceId": spaceId,
    "deviceId": deviceId,
    "records": records.map((record) => record.toJson()).toList(),
  };

  factory SyncSnapshot.fromJson(Map<String, Object?> json) {
    final version = json["formatVersion"]! as int;
    if (version != currentFormatVersion) {
      throw FormatException("Unsupported Ciyue sync format version: $version");
    }
    return SyncSnapshot(
      formatVersion: version,
      spaceId: json["spaceId"]! as String,
      deviceId: json["deviceId"]! as String,
      records: (json["records"]! as List<Object?>)
          .map(
            (record) =>
                SyncRecord.fromJson(Map<String, Object?>.from(record as Map)),
          )
          .toList(growable: false),
    );
  }

  factory SyncSnapshot.decode(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException("Ciyue sync snapshot must be a JSON object.");
    }
    return SyncSnapshot.fromJson(Map<String, Object?>.from(decoded));
  }

  String encode() => jsonEncode(toJson());
}

class SyncConflict {
  final String entityType;
  final String entityId;
  final List<SyncRecord> versions;

  SyncConflict({
    required this.entityType,
    required this.entityId,
    required List<SyncRecord> versions,
  }) : versions = List.unmodifiable(versions);
}

class SyncMergeResult {
  final SyncSnapshot snapshot;
  final List<SyncConflict> conflicts;

  SyncMergeResult({
    required this.snapshot,
    required List<SyncConflict> conflicts,
  }) : conflicts = List.unmodifiable(conflicts);
}

/// Merges two snapshots without discarding a divergent edit or deletion.
class CloudSyncEngine {
  const CloudSyncEngine();

  SyncMergeResult merge(SyncSnapshot local, SyncSnapshot remote) {
    if (local.spaceId != remote.spaceId) {
      throw ArgumentError(
        "Cannot merge Ciyue sync spaces '${local.spaceId}' and '${remote.spaceId}'.",
      );
    }

    final recordsByVersion = <String, SyncRecord>{};
    for (final record in [...local.records, ...remote.records]) {
      final key = _versionKey(record);
      final existing = recordsByVersion[key];
      if (existing != null && !_sameRecord(existing, record)) {
        throw FormatException(
          "Conflicting payloads use the same sync version ID '${record.versionId}'.",
        );
      }
      recordsByVersion[key] = record;
    }

    final records = _sortRecords(recordsByVersion.values.toList());
    final groups = _groupRecords(records);
    final conflicts = <SyncConflict>[];
    for (final versions in groups.values) {
      final parentIds = versions
          .expand((record) => record.parentVersionIds)
          .toSet();
      final heads = _sortRecords(
        versions
            .where((record) => !parentIds.contains(record.versionId))
            .toList(),
      );
      if (heads.length > 1) {
        conflicts.add(
          SyncConflict(
            entityType: heads.first.entityType,
            entityId: heads.first.entityId,
            versions: heads,
          ),
        );
      }
    }
    conflicts.sort((a, b) {
      final typeOrder = a.entityType.compareTo(b.entityType);
      return typeOrder != 0 ? typeOrder : a.entityId.compareTo(b.entityId);
    });

    return SyncMergeResult(
      snapshot: SyncSnapshot(
        spaceId: local.spaceId,
        deviceId: local.deviceId,
        records: records,
      ),
      conflicts: conflicts,
    );
  }
}

Map<String, List<SyncRecord>> _groupRecords(Iterable<SyncRecord> records) {
  final groups = <String, List<SyncRecord>>{};
  for (final record in records) {
    groups.putIfAbsent(_entityKey(record), () => []).add(record);
  }
  return groups;
}

String _entityKey(SyncRecord record) =>
    "${record.entityType}\u0000${record.entityId}";

String _versionKey(SyncRecord record) =>
    "${_entityKey(record)}\u0000${record.versionId}";

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

bool _sameRecord(SyncRecord a, SyncRecord b) =>
    jsonEncode(_canonicalize(a.toJson())) ==
    jsonEncode(_canonicalize(b.toJson()));

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
