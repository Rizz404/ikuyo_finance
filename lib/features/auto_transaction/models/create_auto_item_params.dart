class CreateAutoItemParams {
  final String groupUlid;
  final String transactionUlid;
  final int sortOrder;

  const CreateAutoItemParams({
    required this.groupUlid,
    required this.transactionUlid,
    required this.sortOrder,
  });
}
