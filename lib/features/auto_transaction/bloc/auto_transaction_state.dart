part of 'auto_transaction_bloc.dart';

enum AutoTransactionStatus { initial, loading, success, failure }

enum AutoTransactionWriteStatus { initial, loading, success, failure }

enum AutoTransactionWriteAction {
  none,
  groupCreate,
  groupUpdate,
  groupDelete,
  groupBatchDelete,
  groupToggle,
  groupPause,
  groupResume,
  groupWithItemCreate,
  itemCreate,
  itemUpdate,
  itemDelete,
  itemBatchDelete,
  itemReorder,
  logBatchDelete,
}

final class AutoTransactionState extends Equatable {
  final AutoTransactionStatus status;
  final List<AutoTransactionGroup> groups;

  // * Items untuk grup yang sedang dibuka
  final List<AutoTransactionItem> currentItems;

  // * Logs untuk grup yang sedang dibuka
  final List<AutoTransactionLog> currentLogs;

  final AutoTransactionWriteStatus writeStatus;
  final AutoTransactionWriteAction writeAction;
  final String? errorMessage;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;

  const AutoTransactionState({
    this.status = AutoTransactionStatus.initial,
    this.groups = const [],
    this.currentItems = const [],
    this.currentLogs = const [],
    this.writeStatus = AutoTransactionWriteStatus.initial,
    this.writeAction = AutoTransactionWriteAction.none,
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
    AutoTransactionWriteAction? writeAction,
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
      writeAction: writeAction ?? this.writeAction,
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
    writeAction,
    errorMessage,
    writeSuccessMessage,
    writeErrorMessage,
  ];
}
