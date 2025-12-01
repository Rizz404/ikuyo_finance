import 'package:equatable/equatable.dart';
import 'package:ikuyo_finance/features/category/models/category.dart';

/// * Params untuk mengambil data statistik
class GetStatisticParams extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final CategoryType? categoryType; // * Filter berdasarkan income/expense

  const GetStatisticParams({
    required this.startDate,
    required this.endDate,
    this.categoryType,
  });

  @override
  List<Object?> get props => [startDate, endDate, categoryType];
}
