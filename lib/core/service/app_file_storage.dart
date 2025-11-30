import 'dart:io';

import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:ulid/ulid.dart';

/// * Universal file storage service for managing files in app storage
/// * Can be used for icons, images, documents, etc.
abstract class AppFileStorage {
  /// * Save file to app storage and return the new path
  /// * Returns null if save fails
  /// * [sourcePath] - Original file path (from device or asset)
  /// * [subFolder] - Subfolder in app documents (e.g., 'category_icons', 'asset_icons')
  Future<String?> saveFile(String? sourcePath, {required String subFolder});

  /// * Delete file from app storage
  /// * [filePath] - Path to file to delete
  Future<void> deleteFile(String? filePath);

  /// * Check if path is an asset path (not user file)
  bool isAssetPath(String? path);

  /// * Update file - save new and delete old
  /// * Returns new file path or null if save fails
  Future<String?> updateFile({
    required String? newPath,
    required String? oldPath,
    required String subFolder,
  });
}

class AppFileStorageImpl implements AppFileStorage {
  const AppFileStorageImpl();

  @override
  bool isAssetPath(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('assets/');
  }

  @override
  Future<String?> saveFile(
    String? sourcePath, {
    required String subFolder,
  }) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;

    // * Skip if already an asset path
    if (isAssetPath(sourcePath)) return sourcePath;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      logError('Source file not found', sourcePath, StackTrace.current);
      return null;
    }

    try {
      // * Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(appDir.path, subFolder));

      // * Create directory if not exists
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // * Generate unique filename with ULID
      final extension = p.extension(sourcePath);
      final newFileName = '${Ulid().toString()}$extension';
      final newPath = p.join(targetDir.path, newFileName);

      // * Copy file to app storage
      await sourceFile.copy(newPath);
      logInfo('File saved to app storage: $newPath');

      return newPath;
    } catch (e, s) {
      logError('Failed to save file to app storage', e, s);
      return null;
    }
  }

  @override
  Future<void> deleteFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;

    // * Skip if asset path
    if (isAssetPath(filePath)) return;

    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        logInfo('File deleted: $filePath');
      }
    } catch (e, s) {
      logError('Failed to delete file', e, s);
    }
  }

  @override
  Future<String?> updateFile({
    required String? newPath,
    required String? oldPath,
    required String subFolder,
  }) async {
    // * Skip if same path
    if (newPath == oldPath) return oldPath;

    // * Save new file
    final savedPath = await saveFile(newPath, subFolder: subFolder);

    // * Delete old file only if new save succeeded
    if (savedPath != null && oldPath != null) {
      await deleteFile(oldPath);
    }

    return savedPath;
  }
}
