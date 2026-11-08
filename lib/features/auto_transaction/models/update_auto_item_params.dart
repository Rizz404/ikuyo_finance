class UpdateAutoItemParams {
  final String ulid;
  final int? sortOrder;
  final bool? isActive;
  final String? transactionUlid;

  const UpdateAutoItemParams({
    required this.ulid,
    this.sortOrder,
    this.isActive,
    this.transactionUlid,
  });
}
