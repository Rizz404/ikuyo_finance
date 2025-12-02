import 'package:fpdart/fpdart.dart' hide Order;
import 'package:ikuyo_finance/core/service/app_file_storage.dart';
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

// * Subfolder for category icons in app storage
const _kCategoryIconsFolder = 'category_icons';

class CategoryRepositoryImpl implements CategoryRepository {
  final ObjectBoxStorage _storage;
  final AppFileStorage _fileStorage;

  const CategoryRepositoryImpl(this._storage, this._fileStorage);

  Box<Category> get _box => _storage.box<Category>();

  @override
  TaskEither<Failure, Success<Category>> createCategory(
    CreateCategoryParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Create category', params.name);

        // * Save icon to app storage
        final savedIconPath = await _fileStorage.saveFile(
          params.icon,
          subFolder: _kCategoryIconsFolder,
        );

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
            throw Exception('Kategori induk tidak ditemukan');
          }

          // * Validate: parent must not have a parent (only 1 level nesting)
          if (parent.parent.target != null) {
            throw Exception(
              'Tidak dapat menambahkan sub-kategori ke sub-kategori lain',
            );
          }

          // * Validate: parent must not already have children
          final allCategories = _box.query().build().find();
          final parentHasChildren = allCategories.any(
            (cat) => cat.parent.target?.ulid == parent.ulid,
          );
          if (parentHasChildren) {
            throw Exception(
              'Kategori "${parent.name}" sudah memiliki sub-kategori',
            );
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
          message: error.toString().contains('Exception:')
              ? error.toString().replaceFirst('Exception: ', '')
              : 'Gagal membuat kategori. Silakan coba lagi.',
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
          'cursor: ${params.cursor}, limit: ${params.limit}, search: ${params.searchQuery}, sortBy: ${params.sortBy}',
        );

        // * Build conditions list
        final List<Condition<Category>> conditions = [];

        // * Filter by type
        if (params.type != null) {
          conditions.add(Category_.type.equals(params.type!.index));
        }

        // * Case-insensitive search by name
        if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
          conditions.add(
            Category_.name.contains(params.searchQuery!, caseSensitive: false),
          );
        }

        // * Build query with conditions
        QueryBuilder<Category> queryBuilder;
        if (conditions.isNotEmpty) {
          Condition<Category> combinedCondition = conditions.first;
          for (int i = 1; i < conditions.length; i++) {
            combinedCondition = combinedCondition.and(conditions[i]);
          }
          queryBuilder = _box.query(combinedCondition);
        } else {
          queryBuilder = _box.query();
        }

        // * Apply sorting based on sortBy parameter
        final orderFlags = params.sortOrder == CategorySortOrder.descending
            ? Order.descending
            : 0;

        switch (params.sortBy) {
          case CategorySortBy.name:
            queryBuilder.order(Category_.name, flags: orderFlags);
            break;
          case CategorySortBy.createdAt:
            queryBuilder.order(Category_.createdAt, flags: orderFlags);
            break;
        }

        final builtQuery = queryBuilder.build();
        final allResults = builtQuery.find();
        builtQuery.close();

        // * Filter by parent (ObjectBox doesn't support ToOne query directly)
        var filteredResults = allResults;
        if (params.parentUlid != null) {
          filteredResults = filteredResults
              .where((c) => c.parent.target?.ulid == params.parentUlid)
              .toList();
        }

        // * Filter root only (no parent)
        if (params.isRootOnly == true) {
          filteredResults = filteredResults
              .where((c) => c.parent.target == null)
              .toList();
        }

        // * Cursor-based pagination (offset-based internally)
        final offset = params.cursor != null
            ? int.tryParse(params.cursor!) ?? 0
            : 0;

        final startIndex = offset < filteredResults.length
            ? offset
            : filteredResults.length;
        final endIndex =
            (startIndex + params.limit + 1) < filteredResults.length
            ? startIndex + params.limit + 1
            : filteredResults.length;
        final results = filteredResults.sublist(startIndex, endIndex);

        final hasMore = results.length > params.limit;
        final categories = hasMore ? results.sublist(0, params.limit) : results;

        final cursorInfo = CursorInfo(
          nextCursor: hasMore ? (offset + params.limit).toString() : '',
          hasNextPage: hasMore,
          perPage: params.limit,
        );

        logInfo(
          'Categories retrieved: ${categories.length}, hasMore: $hasMore',
        );

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
          throw Exception('Kategori tidak ditemukan');
        }

        // * Update fields jika ada
        if (params.name != null) category.name = params.name!;
        if (params.type != null) category.type = params.type!.index;
        if (params.color != null) category.color = params.color;

        // * Handle icon update - save new and delete old
        if (params.icon != null && params.icon != category.icon) {
          final savedIconPath = await _fileStorage.updateFile(
            newPath: params.icon,
            oldPath: category.icon,
            subFolder: _kCategoryIconsFolder,
          );
          category.icon = savedIconPath;
        }

        // * Update parent jika ada perubahan
        if (params.parentUlid != null) {
          if (params.parentUlid == params.ulid) {
            throw Exception(
              'Kategori tidak bisa menjadi induk dari dirinya sendiri',
            );
          }

          final parent = _box
              .query(Category_.ulid.equals(params.parentUlid!))
              .build()
              .findFirst();

          if (parent == null) {
            throw Exception('Kategori induk tidak ditemukan');
          }

          // * Validate: parent must not have a parent (only 1 level nesting)
          if (parent.parent.target != null) {
            throw Exception(
              'Tidak dapat menambahkan sub-kategori ke sub-kategori lain',
            );
          }

          // * Validate: category being edited must not have children
          final allCategories = _box.query().build().find();
          final categoryHasChildren = allCategories.any(
            (cat) => cat.parent.target?.ulid == category.ulid,
          );
          if (categoryHasChildren) {
            throw Exception(
              'Kategori yang memiliki sub-kategori tidak bisa menjadi sub-kategori',
            );
          }

          category.parent.target = parent;
        } else if (params.parentUlid == null &&
            category.parent.target != null) {
          // * Remove parent if explicitly set to null (promote to root)
          // * Only allow if we're tracking this - for now keep existing parent
        }

        category.updatedAt = DateTime.now();
        _box.put(category);

        logInfo('Category updated successfully');
        return Success(message: 'Category updated', data: category);
      },
      (error, stackTrace) {
        logError('Update category failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('Exception:')
              ? error.toString().replaceFirst('Exception: ', '')
              : 'Gagal memperbarui kategori. Silakan coba lagi.',
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
          throw Exception('Kategori tidak ditemukan');
        }

        // * Check jika ada child categories
        final hasChildren = _box.query().build().find().any(
          (cat) => cat.parent.target?.ulid == ulid,
        );

        if (hasChildren) {
          throw Exception(
            'Tidak dapat menghapus kategori yang memiliki sub-kategori',
          );
        }

        // * Delete icon file from app storage
        await _fileStorage.deleteFile(category.icon);

        _box.remove(category.id);
        logInfo('Category deleted successfully');

        return const ActionSuccess(message: 'Category deleted');
      },
      (error, stackTrace) {
        logError('Delete category failed', error, stackTrace);
        return Failure(
          message: error.toString().contains('Exception:')
              ? error.toString().replaceFirst('Exception: ', '')
              : 'Gagal menghapus kategori. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<List<Category>>> getValidParentCategories({
    required CategoryType type,
    String? excludeUlid,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService(
          'Get valid parent categories',
          'type: ${type.name}, excludeUlid: $excludeUlid',
        );

        // * Get all categories with the same type
        final allCategories = _box
            .query(Category_.type.equals(type.index))
            .build()
            .find();

        // * Get all category ulids that have children
        final categoriesWithChildren = <String>{};
        for (final cat in allCategories) {
          if (cat.parent.target != null) {
            categoriesWithChildren.add(cat.parent.target!.ulid);
          }
        }

        // * Filter valid parents:
        // * 1. Must be root (no parent)
        // * 2. Must not have children (can't nest deeper than 1 level)
        // * 3. Must not be the category being edited
        final validParents = allCategories.where((cat) {
          final isRoot = cat.parent.target == null;
          final hasNoChildren = !categoriesWithChildren.contains(cat.ulid);
          final isNotSelf = excludeUlid == null || cat.ulid != excludeUlid;
          return isRoot && hasNoChildren && isNotSelf;
        }).toList();

        logInfo('Valid parent categories: ${validParents.length}');
        return Success(
          message: 'Valid parent categories retrieved',
          data: validParents,
        );
      },
      (error, stackTrace) {
        logError('Get valid parent categories failed', error, stackTrace);
        return Failure(
          message: 'Failed to retrieve parent categories. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<bool>> hasChildren({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Check category has children', ulid);

        final allCategories = _box.query().build().find();
        final hasChildren = allCategories.any(
          (cat) => cat.parent.target?.ulid == ulid,
        );

        logInfo('Category has children: $hasChildren');
        return Success(message: 'Check completed', data: hasChildren);
      },
      (error, stackTrace) {
        logError('Check children failed', error, stackTrace);
        return Failure(message: 'Failed to check category children.');
      },
    );
  }
}
