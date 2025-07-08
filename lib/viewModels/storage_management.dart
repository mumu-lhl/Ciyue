import "dart:io";
import "package:flutter/foundation.dart";
import "package:path_provider/path_provider.dart";
import "package:path/path.dart" as p;

class StorageManagementViewModel extends ChangeNotifier {
  Directory? _baseDirectory;
  Directory? _currentDirectory;
  List<FileSystemEntity> _entities = [];
  bool _isLoading = false;
  String? _errorMessage;

  Directory? get currentDirectory => _currentDirectory;
  List<FileSystemEntity> get entities => _entities;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAtBaseDirectory => _currentDirectory?.path == _baseDirectory?.path;

  StorageManagementViewModel() {
    _initializeDirectory();
  }

  Future<void> _initializeDirectory() async {
    _isLoading = true;
    notifyListeners();
    try {
      _baseDirectory = await getApplicationSupportDirectory();
      _currentDirectory = _baseDirectory;
      await _loadEntities();
    } catch (e) {
      _errorMessage = "Failed to initialize directory: $e";
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadEntities() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    if (_currentDirectory == null) {
      _errorMessage = "Current directory is not set.";
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final entities = await _currentDirectory!.list().toList();
      final filteredEntities = entities.where((entity) {
        final name = p.basename(entity.path);
        if (isAtBaseDirectory) {
          return name != "datastore" && name != "profileInstalled";
        }
        return true;
      }).toList();

      filteredEntities.sort((a, b) {
        if (a is Directory && b is! Directory) return -1;
        if (a is! Directory && b is Directory) return 1;
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });
      _entities = filteredEntities;
    } catch (e) {
      _errorMessage = "Error loading entities: $e";
      _entities = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void navigateToDirectory(Directory directory) {
    _currentDirectory = directory;
    _loadEntities();
  }

  void navigateBack() {
    if (_currentDirectory != null &&
        _baseDirectory != null &&
        _currentDirectory!.path != _baseDirectory!.path) {
      _currentDirectory = _currentDirectory!.parent;
      _loadEntities();
    }
  }

  Future<bool> deleteEntity(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
      await _loadEntities(); // Reload the list after deletion
      return true;
    } catch (e) {
      _errorMessage = "Error deleting entity: $e";
      notifyListeners();
      return false;
    }
  }
}
