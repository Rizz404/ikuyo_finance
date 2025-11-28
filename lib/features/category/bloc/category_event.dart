part of 'category_bloc.dart';

sealed class CategoryEvent {
  const CategoryEvent();
}

// * Read Events
final class CategoryFetched extends CategoryEvent {
  const CategoryFetched({this.type});

  final CategoryType? type;
}

final class CategoryFetchedMore extends CategoryEvent {
  const CategoryFetchedMore();
}

final class CategoryRefreshed extends CategoryEvent {
  const CategoryRefreshed();
}

// * Write Events
final class CategoryCreated extends CategoryEvent {
  final CreateCategoryParams params;

  const CategoryCreated({required this.params});
}

final class CategoryUpdated extends CategoryEvent {
  final UpdateCategoryParams params;

  const CategoryUpdated({required this.params});
}

final class CategoryDeleted extends CategoryEvent {
  const CategoryDeleted({required this.ulid});

  final String ulid;
}

// * Reset write status setelah UI handle
final class CategoryWriteStatusReset extends CategoryEvent {
  const CategoryWriteStatusReset();
}
