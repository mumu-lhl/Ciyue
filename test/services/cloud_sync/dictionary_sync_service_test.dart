import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/cloud_sync/dictionary_sync.dart";
import "package:ciyue/services/cloud_sync/file_store.dart";
import "package:drift/drift.dart" show driftRuntimeOptions;
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase database;
  late Directory sourceDirectory;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    sourceDirectory = await Directory.systemTemp.createTemp(
      "dictionary-sync-source-",
    );
  });

  tearDown(() async {
    await database.close();
    await sourceDirectory.delete(recursive: true);
  });

  test("previews each local dictionary and its associated files", () async {
    final files = await _addLocalDictionary(database, sourceDirectory);
    final fileStore = _MemoryCloudFileStore();

    final preview = await DictionarySyncService(database: database).preview(
      fileStore: fileStore,
      remoteRoot: "Ciyue",
      remoteFolderExists: false,
    );

    expect(preview.items, hasLength(1));
    final item = preview.items.single;
    expect(item.title, "My lexicon");
    expect(item.fileCount, 6);
    expect(
      item.totalSizeBytes,
      files.values.fold<int>(0, (sum, value) => sum + value.length),
    );
    expect(item.availableLocally, isTrue);
    expect(item.availableRemotely, isFalse);
    expect(fileStore.operations, isEmpty);
  });

  test("uploads only explicitly selected local dictionary packages", () async {
    await _addLocalDictionary(database, sourceDirectory);
    final fileStore = _MemoryCloudFileStore();
    final service = DictionarySyncService(database: database);
    final preview = await service.preview(
      fileStore: fileStore,
      remoteRoot: "Ciyue",
      remoteFolderExists: false,
    );

    await service.transferSelected(
      fileStore: fileStore,
      remoteRoot: "Ciyue",
      preview: preview,
      selectedPackageIds: const {},
      dictionaryStorageDirectory: sourceDirectory,
    );
    expect(fileStore.files, isEmpty);

    final packageId = preview.items.single.packageId;
    await service.transferSelected(
      fileStore: fileStore,
      remoteRoot: "Ciyue",
      preview: preview,
      selectedPackageIds: {packageId},
      dictionaryStorageDirectory: sourceDirectory,
    );

    final packageRoot = "Ciyue/dictionaries/packages/$packageId";
    expect(
      utf8.decode(fileStore.files["$packageRoot/lexicon.mdx"]!),
      "mdx data",
    );
    expect(
      utf8.decode(fileStore.files["$packageRoot/lexicon.mdd"]!),
      "mdd data",
    );
    expect(
      utf8.decode(fileStore.files["$packageRoot/lexicon.1.mdd"]!),
      "second mdd",
    );
    expect(
      utf8.decode(fileStore.files["$packageRoot/lexicon.css"]!),
      "css data",
    );
    expect(utf8.decode(fileStore.files["$packageRoot/lexicon.js"]!), "js data");
    expect(
      utf8.decode(fileStore.files["$packageRoot/font/custom.woff2"]!),
      "font data",
    );
    expect(fileStore.files["$packageRoot/manifest.json"], isNotNull);
  });

  test("does not upload a dictionary changed after its preview", () async {
    await _addLocalDictionary(database, sourceDirectory);
    final fileStore = _MemoryCloudFileStore();
    final service = DictionarySyncService(database: database);
    final preview = await service.preview(
      fileStore: fileStore,
      remoteRoot: "Ciyue",
      remoteFolderExists: false,
    );
    await File("${sourceDirectory.path}/lexicon.mdx").writeAsString("changed");

    await expectLater(
      service.transferSelected(
        fileStore: fileStore,
        remoteRoot: "Ciyue",
        preview: preview,
        selectedPackageIds: {preview.items.single.packageId},
        dictionaryStorageDirectory: sourceDirectory,
      ),
      throwsA(isA<StateError>()),
    );
    expect(fileStore.files, isEmpty);
  });

  test(
    "rejects a selected download whose file fails checksum verification",
    () async {
      await _addLocalDictionary(database, sourceDirectory);
      final fileStore = _MemoryCloudFileStore();
      final uploadService = DictionarySyncService(database: database);
      final uploadPreview = await uploadService.preview(
        fileStore: fileStore,
        remoteRoot: "Ciyue",
        remoteFolderExists: false,
      );
      final packageId = uploadPreview.items.single.packageId;
      await uploadService.transferSelected(
        fileStore: fileStore,
        remoteRoot: "Ciyue",
        preview: uploadPreview,
        selectedPackageIds: {packageId},
        dictionaryStorageDirectory: sourceDirectory,
      );
      fileStore.files["Ciyue/dictionaries/packages/$packageId/lexicon.mdx"] =
          Uint8List.fromList(utf8.encode("tampered"));

      final secondDatabase = AppDatabase(NativeDatabase.memory());
      final secondStorage = await Directory.systemTemp.createTemp(
        "dictionary-sync-rejected-",
      );
      addTearDown(() async {
        await secondDatabase.close();
        await secondStorage.delete(recursive: true);
      });
      final service = DictionarySyncService(database: secondDatabase);
      final preview = await service.preview(
        fileStore: fileStore,
        remoteRoot: "Ciyue",
        remoteFolderExists: true,
      );

      await expectLater(
        service.transferSelected(
          fileStore: fileStore,
          remoteRoot: "Ciyue",
          preview: preview,
          selectedPackageIds: {packageId},
          dictionaryStorageDirectory: secondStorage,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await secondDatabase.dictionaryListDao.all(), isEmpty);
      expect(await secondStorage.list().isEmpty, isTrue);
    },
  );

  test("downloads a selected dictionary after checksum verification", () async {
    await _addLocalDictionary(database, sourceDirectory);
    final fileStore = _MemoryCloudFileStore();
    final uploadService = DictionarySyncService(database: database);
    final uploadPreview = await uploadService.preview(
      fileStore: fileStore,
      remoteRoot: "Ciyue",
      remoteFolderExists: false,
    );
    final packageId = uploadPreview.items.single.packageId;
    await uploadService.transferSelected(
      fileStore: fileStore,
      remoteRoot: "Ciyue",
      preview: uploadPreview,
      selectedPackageIds: {packageId},
      dictionaryStorageDirectory: sourceDirectory,
    );

    final secondDatabase = AppDatabase(NativeDatabase.memory());
    final secondStorage = await Directory.systemTemp.createTemp(
      "dictionary-sync-restored-",
    );
    addTearDown(() async {
      await secondDatabase.close();
      await secondStorage.delete(recursive: true);
    });
    final downloadService = DictionarySyncService(database: secondDatabase);
    final downloadPreview = await downloadService.preview(
      fileStore: fileStore,
      remoteRoot: "Ciyue",
      remoteFolderExists: true,
    );

    expect(downloadPreview.items, hasLength(1));
    final item = downloadPreview.items.single;
    expect(item.availableLocally, isFalse);
    expect(item.availableRemotely, isTrue);
    expect(item.packageId, packageId);

    await downloadService.transferSelected(
      fileStore: fileStore,
      remoteRoot: "Ciyue",
      preview: downloadPreview,
      selectedPackageIds: {packageId},
      dictionaryStorageDirectory: secondStorage,
    );

    final restored = (await secondDatabase.dictionaryListDao.all()).single;
    expect(restored.title, "My lexicon");
    expect(restored.path, "${secondStorage.path}/$packageId/lexicon");
    expect(await File("${restored.path}.mdx").readAsString(), "mdx data");
    expect(await File("${restored.path}.mdd").readAsString(), "mdd data");
    expect(await File("${restored.path}.1.mdd").readAsString(), "second mdd");
    expect(
      await File("${secondStorage.path}/$packageId/lexicon.css").readAsString(),
      "css data",
    );
    expect(
      await File("${secondStorage.path}/$packageId/lexicon.js").readAsString(),
      "js data",
    );
    expect(
      restored.fontPath,
      "${secondStorage.path}/$packageId/font/custom.woff2",
    );
    expect(await File(restored.fontPath!).readAsString(), "font data");
  });
}

Future<Map<String, String>> _addLocalDictionary(
  AppDatabase database,
  Directory directory,
) async {
  final basePath = "${directory.path}/lexicon";
  final files = <String, String>{
    "$basePath.mdx": "mdx data",
    "$basePath.mdd": "mdd data",
    "$basePath.1.mdd": "second mdd",
    "${directory.path}/lexicon.css": "css data",
    "${directory.path}/lexicon.js": "js data",
    "${directory.path}/custom.woff2": "font data",
  };
  for (final entry in files.entries) {
    await File(entry.key).writeAsString(entry.value);
  }
  final dictionaryId = await database.dictionaryListDao.add(
    basePath,
    "My lexicon",
  );
  await database.dictionaryListDao.updateFont(
    dictionaryId,
    "${directory.path}/custom.woff2",
  );
  return files;
}

class _MemoryCloudFileStore implements CloudFileStore {
  final List<String> operations = [];
  final Map<String, Uint8List> files = {};
  final Set<String> directories = {""};

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteFile(String remotePath) async {
    operations.add("delete:$remotePath");
    files.remove(remotePath);
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    File destination, {
    onReceiveProgress,
  }) async {
    operations.add("download:$remotePath");
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(files[remotePath]!);
  }

  @override
  Future<void> ensureDirectory(String remotePath) async {
    operations.add("mkdir:$remotePath");
    var current = "";
    for (final segment in remotePath.split("/")) {
      if (segment.isEmpty) continue;
      current = current.isEmpty ? segment : "$current/$segment";
      directories.add(current);
    }
  }

  @override
  Future<List<CloudFileEntry>> listDirectory(String remotePath) async {
    operations.add("list:$remotePath");
    final children = <String, CloudFileEntry>{};
    for (final directory in directories) {
      final parent = directory.contains("/")
          ? directory.substring(0, directory.lastIndexOf("/"))
          : "";
      if (parent != remotePath || directory == remotePath) continue;
      final name = directory.substring(directory.lastIndexOf("/") + 1);
      children[name] = CloudFileEntry(
        name: name,
        path: directory,
        isDirectory: true,
      );
    }
    for (final path in files.keys) {
      final parent = path.contains("/")
          ? path.substring(0, path.lastIndexOf("/"))
          : "";
      if (parent != remotePath) continue;
      final name = path.substring(path.lastIndexOf("/") + 1);
      children[name] = CloudFileEntry(
        name: name,
        path: path,
        isDirectory: false,
        sizeBytes: files[path]!.length,
      );
    }
    return children.values.toList();
  }

  @override
  Future<void> uploadFile(
    String remotePath,
    File source, {
    onSendProgress,
  }) async {
    operations.add("upload:$remotePath");
    files[remotePath] = Uint8List.fromList(await source.readAsBytes());
  }
}
