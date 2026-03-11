part of 'auto_transaction_bloc.dart';

enum AutoTransactionStatus { initial, loading, success, failure }

enum AutoTransactionWriteStatus { initial, loading, success, failure }

final class AutoTransactionState extends Equatable {
  final AutoTransactionStatus status;
  final List<AutoTransactionGroup> groups;

  // * Items untuk grup yang sedang dibuka
  final List<AutoTransactionItem> currentItems;

  // * Logs untuk grup yang sedang dibuka
  final List<AutoTransactionLog> currentLogs;

  final AutoTransactionWriteStatus writeStatus;
  final String? errorMessage;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;

  const AutoTransactionState({
    this.status = AutoTransactionStatus.initial,
    this.groups = const [],
    this.currentItems = const [],
    this.currentLogs = const [],
    this.writeStatus = AutoTransactionWriteStatus.initial,
    this.errorMessage,
    this.writeSuccessMessage,
    this.writeErrorMessage,
  });

  bool get isLoading => status == AutoTransactionStatus.loading;
  bool get isWriting => writeStatus == AutoTransactionWriteStatus.loading;

  AutoTransactionState copyWith({
    AutoTransactionStatus? status,
    List<AutoTransactionGroup>? groups,
    List<AutoTransactionItem>? currentItems,
    List<AutoTransactionLog>? currentLogs,
    AutoTransactionWriteStatus? writeStatus,
    String? Function()? errorMessage,
    String? Function()? writeSuccessMessage,
    String? Function()? writeErrorMessage,
  }) {
    return AutoTransactionState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      currentItems: currentItems ?? this.currentItems,
      currentLogs: currentLogs ?? this.currentLogs,
      writeStatus: writeStatus ?? this.writeStatus,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      writeSuccessMessage: writeSuccessMessage != null
          ? writeSuccessMessage()
          : this.writeSuccessMessage,
      writeErrorMessage: writeErrorMessage != null
          ? writeErrorMessage()
          : this.writeErrorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    groups,
    currentItems,
    currentLogs,
    writeStatus,
    errorMessage,
    writeSuccessMessage,
    writeErrorMessage,
  ];
}
