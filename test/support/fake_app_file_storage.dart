import 'package:ikuyo_finance/core/service/app_file_storage.dart';

/// In-memory stand-in for [AppFileStorage] — no real disk I/O, so repository
/// tests stay hermetic. Mirrors the "asset path is passed through" and
/// "save produces a new path" semantics of [AppFileStorageImpl] closely
/// enough for repository-level behavior to be exercised.
class FakeAppFileStorage implements AppFileStorage {
  final List<String> savedPaths = [];
  final List<String> deletedPaths = [];
  int _counter = 0;

  @override
  bool isAssetPath(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('assets/');
  }

  @override
  Future<String?> saveFile(String? sourcePath, {required String subFolder}) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    if (isAssetPath(sourcePath)) return sourcePath;

    final newPath = 'fake_storage/$subFolder/file_${_counter++}';
    savedPaths.add(newPath);
    return newPath;
  }

  @override
  Future<void> deleteFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    if (isAssetPath(filePath)) return;
    deletedPaths.add(filePath);
  }

  @override
  Future<String?> updateFile({
    required String? newPath,
    required String? oldPath,
    required String subFolder,
  }) async {
    if (newPath == oldPath) return oldPath;

    final savedPath = await saveFile(newPath, subFolder: subFolder);
    if (savedPath != null && oldPath != null) {
      await deleteFile(oldPath);
    }
    return savedPath;
  }
}
