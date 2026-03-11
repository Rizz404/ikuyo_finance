class UpdateAutoItemParams {
  final String ulid;
  final int? sortOrder;
  final bool? isActive;

  const UpdateAutoItemParams({
    required this.ulid,
    this.sortOrder,
    this.isActive,
  });
}
