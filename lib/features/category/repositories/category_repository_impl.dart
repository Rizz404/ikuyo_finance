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
        logService('Buat kategori', params.name);

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
          // * Parent boleh punya banyak children, tapi children tidak boleh punya children lagi
          if (parent.parent.target != null) {
            throw Exception(
              'Tidak dapat menambahkan sub-kategori ke sub-kategori lain',
            );
          }

          category.parent.target = parent;
        }

        _box.put(category);
        logInfo('Kategori berhasil dibuat');

        return Success(message: 'Kategori berhasil dibuat', data: category);
      },
      (error, stackTrace) {
        logError('Gagal membuat kategori', error, stackTrace);
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
          'Ambil kategori',
          'cursor: ${params.cursor}, limit: ${params.limit}, cari: ${params.searchQuery}, urutkan: ${params.sortBy}',
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

        logInfo('Kategori diambil: ${categories.length}, adaLagi: $hasMore');

        return SuccessCursor(
          message: 'Kategori berhasil diambil',
          data: categories,
          cursor: cursorInfo,
        );
      },
      (error, stackTrace) {
        logError('Gagal mengambil kategori', error, stackTrace);
        return Failure(message: 'Gagal mengambil kategori. Silakan coba lagi.');
      },
    );
  }

  @override
  TaskEither<Failure, Success<Category>> getCategoryById({
    required String ulid,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService('Ambil kategori berdasarkan id', ulid);

        final category = _box
            .query(Category_.ulid.equals(ulid))
            .build()
            .findFirst();

        if (category == null) {
          throw Exception('Kategori tidak ditemukan');
        }

        logInfo('Kategori berhasil diambil');
        return Success(message: 'Kategori berhasil diambil', data: category);
      },
      (error, stackTrace) {
        logError('Gagal mengambil kategori berdasarkan id', error, stackTrace);
        return Failure(
          message: error.toString().contains('tidak ditemukan')
              ? 'Kategori tidak ditemukan'
              : 'Gagal mengambil kategori. Silakan coba lagi.',
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
        logService('Perbarui kategori', params.ulid);

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

        logInfo('Kategori berhasil diperbarui');
        return Success(message: 'Kategori berhasil diperbarui', data: category);
      },
      (error, stackTrace) {
        logError('Gagal memperbarui kategori', error, stackTrace);
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
        logService('Hapus kategori', ulid);

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
        logInfo('Kategori berhasil dihapus');

        return const ActionSuccess(message: 'Kategori berhasil dihapus');
      },
      (error, stackTrace) {
        logError('Gagal menghapus kategori', error, stackTrace);
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
          'Ambil kategori induk yang valid',
          'tipe: ${type.name}, kecualiUlid: $excludeUlid',
        );

        // * Get all categories with the same type
        final allCategories = _box
            .query(Category_.type.equals(type.index))
            .build()
            .find();

        // * Filter valid parents:
        // * 1. Must be root (no parent) - children tidak boleh punya children lagi
        // * 2. Must not be the category being edited
        // * Parent boleh punya banyak children, jadi tidak perlu cek hasNoChildren
        final validParents = allCategories.where((cat) {
          final isRoot = cat.parent.target == null;
          final isNotSelf = excludeUlid == null || cat.ulid != excludeUlid;
          return isRoot && isNotSelf;
        }).toList();

        logInfo('Kategori induk yang valid: ${validParents.length}');
        return Success(
          message: 'Kategori induk yang valid berhasil diambil',
          data: validParents,
        );
      },
      (error, stackTrace) {
        logError(
          'Gagal mengambil kategori induk yang valid',
          error,
          stackTrace,
        );
        return Failure(
          message: 'Gagal mengambil kategori induk. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<bool>> hasChildren({required String ulid}) {
    return TaskEither.tryCatch(
      () async {
        logService('Cek kategori memiliki anak', ulid);

        final allCategories = _box.query().build().find();
        final hasChildren = allCategories.any(
          (cat) => cat.parent.target?.ulid == ulid,
        );

        logInfo('Kategori memiliki anak: $hasChildren');
        return Success(message: 'Pengecekan selesai', data: hasChildren);
      },
      (error, stackTrace) {
        logError('Gagal mengecek anak kategori', error, stackTrace);
        return Failure(message: 'Gagal mengecek anak kategori.');
      },
    );
  }
}
