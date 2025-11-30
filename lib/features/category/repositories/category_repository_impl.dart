import 'dart:io';

import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/storage/objectbox_storage.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';
import 'package:ikuyo_finance/features/category/models/create_category_params.dart';
import 'package:ikuyo_finance/features/category/models/get_categories_params.dart';
import 'package:ikuyo_finance/features/category/models/update_category_params.dart';
import 'package:ikuyo_finance/features/category/repositories/category_repository.dart';
import 'package:ikuyo_finance/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:ulid/ulid.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final ObjectBoxStorage _storage;

  const CategoryRepositoryImpl(this._storage);

  Box<Category> get _box => _storage.box<Category>();

  // * Copy icon file ke app storage dan return path baru
  Future<String?> _saveIconToAppStorage(String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;

    // * Skip jika sudah merupakan asset path (bukan file dari device)
    if (sourcePath.startsWith('assets/')) return sourcePath;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      logError('Icon file not found', sourcePath, StackTrace.current);
      return null;
    }

    try {
      // * Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final iconsDir = Directory(p.join(appDir.path, 'category_icons'));

      // * Create directory jika belum ada
      if (!await iconsDir.exists()) {
        await iconsDir.create(recursive: true);
      }

      // * Generate unique filename dengan ULID
      final extension = p.extension(sourcePath);
      final newFileName = '${Ulid().toString()}$extension';
      final newPath = p.join(iconsDir.path, newFileName);

      // * Copy file ke app storage
      await sourceFile.copy(newPath);
      logInfo('Icon saved to app storage: $newPath');

      return newPath;
    } catch (e, s) {
      logError('Failed to save icon to app storage', e, s);
      return null;
    }
  }

  // * Delete old icon file from app storage
  Future<void> _deleteIconFromAppStorage(String? iconPath) async {
    if (iconPath == null || iconPath.isEmpty) return;

    // * Skip jika merupakan asset path
    if (iconPath.startsWith('assets/')) return;

    try {
      final file = File(iconPath);
      if (await file.exists()) {
        await file.delete();
        logInfo('Old icon deleted: $iconPath');
      }
    } catch (e, s) {
      logError('Failed to delete old icon', e, s);
    }
  }

  @override
  TaskEither<Failure, Success<Category>> createCategory(
    CreateCategoryParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Create category', params.name);

        // * Save icon to app storage
        final savedIconPath = await _saveIconToAppStorage(params.icon);

        final category = Category(
          name: params.name,
          type: params.type.index,
          icon: savedIconPath,
          color: params.color,
        );

        // * Set parent jika ada
        if (params.parentUlid != null) {
          final parent = _box
              .query(Category_.ulid.equals(params.parentUlid!))
              .build()
              .findFirst();

          if (parent == null) {
            throw Exception('Parent category not found');
          }

          category.parent.target = parent;
        }

        _box.put(category);
        logInfo('Category created successfully');

        return Success(message: 'Category created', data: category);
      },
      (error, stackTrace) {
        logError('Create category failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? error.toString()
              : 'Failed to create category. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, SuccessCursor<Category>> getCategories(
    GetCategoriesParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Get categories',
          'cursor: ${params.cursor}, limit: ${params.limit}',
        );

        var query = _box.query();

        // * Filter by type jika ada
        if (params.type != null) {
          query = _box.query(Category_.type.equals(params.type!.index));
        }

        // * Pagination dengan cursor (offset-based)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;
        query = query..order(Category_.createdAt, flags: Order.descending);

        final builtQuery = query.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Manual offset & limit
        final startIndex = offset < allResults.length
            ? offset
            : allResults.length;
        final endIndex = (startIndex + params.limit + 1) < allResults.length
            ? startIndex + params.limit + 1
            : allResults.length;
        final results = allResults.sublist(startIndex, endIndex);

        final hasMore = results.length > params.limit;
        final categories = hasMore ? results.sublist(0, params.limit) : results;

        final cursorInfo = CursorInfo(
          nextCursor: hasMore ? (offset + params.limit).toString() : '',
          hasNextPage: hasMore,
          perPage: params.limit,
        );

        logInfo('Categories retrieved: ${categories.length}');

        return SuccessCursor(
          message: 'Categories retrieved',
          data: categories,
          cursor: cursorInfo,
        );
      },
      (error, stackTrace) {
        logError('Get categories failed', error, stackTrace);
        return Failure(
          message: 'Failed to retrieve categories. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Category>> getCategoryById({
    required String ulid,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService('Get category by id', ulid);

        final category = _box
            .query(Category_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (category == null) {
          throw Exception('Category not found');
        }

        logInfo('Category retrieved');
        return Success(message: 'Category retrieved', data: category);
      },
      (error, stackTrace) {
        logError('Get category by id failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Category not found'
              : 'Failed to retrieve category. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<Category>> updateCategory(
    UpdateCategoryParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Update category', params.ulid);

        final category = _box
            .query(Category_.ulid.equals(params.ulid))
            .build()
            .findFirst();

        if (category == null) {
          throw Exception('Category not found');
        }

        // * Update fields jika ada
        if (params.name != null) category.name = params.name!;
        if (params.type != null) category.type = params.type!.index;
        if (params.color != null) category.color = params.color;

        // * Handle icon update - save new and delete old
        if (params.icon != null && params.icon != category.icon) {
          final oldIconPath = category.icon;
          final savedIconPath = await _saveIconToAppStorage(params.icon);
          category.icon = savedIconPath;

          // * Delete old icon setelah save berhasil
          if (savedIconPath != null) {
            await _deleteIconFromAppStorage(oldIconPath);
          }
        }

        // * Update parent jika ada
        if (params.parentUlid != null) {
          if (params.parentUlid == params.ulid) {
            throw Exception('Category cannot be its own parent');
          }

          final parent = _box
              .query(Category_.ulid.equals(params.parentUlid!))
              .build()
              .findFirst();

          if (parent == null) {
            throw Exception('Parent category not found');
          }

          category.parent.target = parent;
        }

        category.updatedAt = DateTime.now();
        _box.put(category);

        logInfo('Category updated successfully');
        return Success(message: 'Category updated', data: category);
      },
      (error, stackTrace) {
        logError('Update category failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? error.toString()
              : error.toString().contains('own parent')
              ? error.toString()
              : 'Failed to update category. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> deleteCategory({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Delete category', ulid);

        final category = _box
            .query(Category_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (category == null) {
          throw Exception('Category not found');
        }

        // * Check jika ada child categories
        final hasChildren = _box.query().build().find().any(
          (cat) => cat.parent.target?.ulid == ulid,
        );

        if (hasChildren) {
          throw Exception('Cannot delete category with subcategories');
        }

        // * Delete icon file from app storage
        await _deleteIconFromAppStorage(category.icon);

        _box.remove(category.id);
        logInfo('Category deleted successfully');

        return const ActionSuccess(message: 'Category deleted');
      },
      (error, stackTrace) {
        logError('Delete category failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('not found')
              ? 'Category not found'
              : error.toString().contains('subcategories')
              ? 'Cannot delete category with subcategories'
              : 'Failed to delete category. Please try again.',
        );
      },
    );
  }
}
