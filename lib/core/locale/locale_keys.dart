// * Locale keys for easy_localization
// * Usage: LocaleKeys.someKey.tr()
// * Keys map to dot-notation paths in assets/translations/*.json
// * Run `dart run tools/merge_translations.dart` to rebuild assets/translations/
abstract class LocaleKeys {
  // * SharedWidgets — ColorPicker
  static const sharedWidgetsColorPickerCustomColorLabel =
      'sharedWidgets.colorPicker.customColorLabel';

  // * SharedWidgets — DetailActionButtons
  static const sharedWidgetsDetailActionsDelete =
      'sharedWidgets.detailActions.delete';
  static const sharedWidgetsDetailActionsEdit =
      'sharedWidgets.detailActions.edit';

  // * SharedWidgets — Dropdown
  static const sharedWidgetsDropdownSelectOption =
      'sharedWidgets.dropdown.selectOption';

  // * SharedWidgets — FilePicker
  static const sharedWidgetsFilePickerMaxFilesError =
      'sharedWidgets.filePicker.maxFilesError';
  static const sharedWidgetsFilePickerFileSizeError =
      'sharedWidgets.filePicker.fileSizeError';
  static const sharedWidgetsFilePickerFileSizeErrorDesc =
      'sharedWidgets.filePicker.fileSizeErrorDesc';
  static const sharedWidgetsFilePickerPickFailed =
      'sharedWidgets.filePicker.pickFailed';
  static const sharedWidgetsFilePickerChooseFiles =
      'sharedWidgets.filePicker.chooseFiles';
  static const sharedWidgetsFilePickerImagePreviewError =
      'sharedWidgets.filePicker.imagePreviewError';
  static const sharedWidgetsFilePickerVideoPreviewNotImpl =
      'sharedWidgets.filePicker.videoPreviewNotImpl';
  static const sharedWidgetsFilePickerPreviewNotAvailable =
      'sharedWidgets.filePicker.previewNotAvailable';

  // * SharedWidgets — ListBottomSheet
  static const sharedWidgetsListBottomSheetCreateTitle =
      'sharedWidgets.listBottomSheet.createTitle';
  static const sharedWidgetsListBottomSheetCreateSubtitle =
      'sharedWidgets.listBottomSheet.createSubtitle';
  static const sharedWidgetsListBottomSheetSelectManyTitle =
      'sharedWidgets.listBottomSheet.selectManyTitle';
  static const sharedWidgetsListBottomSheetSelectManySubtitle =
      'sharedWidgets.listBottomSheet.selectManySubtitle';
  static const sharedWidgetsListBottomSheetFilterSortTitle =
      'sharedWidgets.listBottomSheet.filterSortTitle';
  static const sharedWidgetsListBottomSheetFilterSortSubtitle =
      'sharedWidgets.listBottomSheet.filterSortSubtitle';
  static const sharedWidgetsListBottomSheetExportTitle =
      'sharedWidgets.listBottomSheet.exportTitle';
  static const sharedWidgetsListBottomSheetExportSubtitle =
      'sharedWidgets.listBottomSheet.exportSubtitle';
  static const sharedWidgetsListBottomSheetOptionsHeader =
      'sharedWidgets.listBottomSheet.optionsHeader';

  // * SharedWidgets — MultiSelectDropdown
  static const sharedWidgetsMultiSelectDropdownSearchHint =
      'sharedWidgets.multiSelectDropdown.searchHint';
  static const sharedWidgetsMultiSelectDropdownNoData =
      'sharedWidgets.multiSelectDropdown.noData';
  static const sharedWidgetsMultiSelectDropdownSelectHint =
      'sharedWidgets.multiSelectDropdown.selectHint';
  static const sharedWidgetsMultiSelectDropdownItemsSelected =
      'sharedWidgets.multiSelectDropdown.itemsSelected';
  static const sharedWidgetsMultiSelectDropdownClearAll =
      'sharedWidgets.multiSelectDropdown.clearAll';
  static const sharedWidgetsMultiSelectDropdownDone =
      'sharedWidgets.multiSelectDropdown.done';

  // * SharedWidgets — SearchField
  static const sharedWidgetsSearchFieldNoResultFound =
      'sharedWidgets.searchField.noResultFound';
  static const sharedWidgetsSearchFieldSearchHint =
      'sharedWidgets.searchField.searchHint';
  static const sharedWidgetsSearchFieldClear =
      'sharedWidgets.searchField.clear';

  // * SharedWidgets — SearchableDropdown
  static const sharedWidgetsSearchableDropdownSearchHint =
      'sharedWidgets.searchableDropdown.searchHint';
  static const sharedWidgetsSearchableDropdownNoResults =
      'sharedWidgets.searchableDropdown.noResults';
  static const sharedWidgetsSearchableDropdownSelectOption =
      'sharedWidgets.searchableDropdown.selectOption';
  static const sharedWidgetsSearchableDropdownNoMoreData =
      'sharedWidgets.searchableDropdown.noMoreData';

  // * SharedWidgets — CurrencyMigration
  static const sharedWidgetsCurrencyMigrationStarting =
      'sharedWidgets.currencyMigration.starting';
  static const sharedWidgetsCurrencyMigrationSuccess =
      'sharedWidgets.currencyMigration.success';
  static const sharedWidgetsCurrencyMigrationFailed =
      'sharedWidgets.currencyMigration.failed';
  static const sharedWidgetsCurrencyMigrationTitle =
      'sharedWidgets.currencyMigration.title';
  static const sharedWidgetsCurrencyMigrationConfirmTitle =
      'sharedWidgets.currencyMigration.confirmTitle';
  static const sharedWidgetsCurrencyMigrationSuccessDesc =
      'sharedWidgets.currencyMigration.successDesc';
  static const sharedWidgetsCurrencyMigrationErrorDesc =
      'sharedWidgets.currencyMigration.errorDesc';
  static const sharedWidgetsCurrencyMigrationWarningDesc =
      'sharedWidgets.currencyMigration.warningDesc';
  static const sharedWidgetsCurrencyMigrationIrreversibleWarning =
      'sharedWidgets.currencyMigration.irreversibleWarning';
  static const sharedWidgetsCurrencyMigrationAssets =
      'sharedWidgets.currencyMigration.assets';
  static const sharedWidgetsCurrencyMigrationTransactions =
      'sharedWidgets.currencyMigration.transactions';
  static const sharedWidgetsCurrencyMigrationBudgets =
      'sharedWidgets.currencyMigration.budgets';
  static const sharedWidgetsCurrencyMigrationTotal =
      'sharedWidgets.currencyMigration.total';
  static const sharedWidgetsCurrencyMigrationDuration =
      'sharedWidgets.currencyMigration.duration';
  static const sharedWidgetsCurrencyMigrationRecords =
      'sharedWidgets.currencyMigration.records';
  static const sharedWidgetsCurrencyMigrationClose =
      'sharedWidgets.currencyMigration.close';
  static const sharedWidgetsCurrencyMigrationCancel =
      'sharedWidgets.currencyMigration.cancel';
  static const sharedWidgetsCurrencyMigrationProceed =
      'sharedWidgets.currencyMigration.proceed';

  // * SharedWidgets — ThemeToggle
  static const sharedWidgetsThemeToggleSwitchToLight =
      'sharedWidgets.themeToggle.switchToLight';
  static const sharedWidgetsThemeToggleSwitchToDark =
      'sharedWidgets.themeToggle.switchToDark';
  static const sharedWidgetsThemeToggleLight =
      'sharedWidgets.themeToggle.light';
  static const sharedWidgetsThemeToggleDark = 'sharedWidgets.themeToggle.dark';
  static const sharedWidgetsThemeToggleSystem =
      'sharedWidgets.themeToggle.system';

  // * SharedWidgets — UserShell
  static const sharedWidgetsUserShellBackToExit =
      'sharedWidgets.userShell.backToExit';
  static const sharedWidgetsUserShellTransactions =
      'sharedWidgets.userShell.transactions';
  static const sharedWidgetsUserShellStatistics =
      'sharedWidgets.userShell.statistics';
  static const sharedWidgetsUserShellAssets = 'sharedWidgets.userShell.assets';
  static const sharedWidgetsUserShellSettings =
      'sharedWidgets.userShell.settings';

  // ──────────────────────────────────────────────
  // * Asset — Validator
  // ──────────────────────────────────────────────
  static const assetValidatorNameRequired = 'asset.validator.nameRequired';
  static const assetValidatorNameMinLength = 'asset.validator.nameMinLength';
  static const assetValidatorNameMaxLength = 'asset.validator.nameMaxLength';
  static const assetValidatorTypeRequired = 'asset.validator.typeRequired';
  static const assetValidatorBalanceInvalid = 'asset.validator.balanceInvalid';
  static const assetValidatorBalanceNegative =
      'asset.validator.balanceNegative';
  static const assetValidatorUlidRequired = 'asset.validator.ulidRequired';

  // * Asset — Screen
  static const assetScreenTitle = 'asset.screen.title';
  static const assetScreenTabList = 'asset.screen.tabList';
  static const assetScreenTabStatistic = 'asset.screen.tabStatistic';
  static const assetScreenErrorOccurred = 'asset.screen.errorOccurred';
  static const assetScreenEmptyTitle = 'asset.screen.emptyTitle';
  static const assetScreenEmptySubtitle = 'asset.screen.emptySubtitle';
  static const assetScreenStatisticTitle = 'asset.screen.statisticTitle';
  static const assetScreenComingSoon = 'asset.screen.comingSoon';
  static const assetScreenFeatureInDevelopment =
      'asset.screen.featureInDevelopment';

  // * Asset — Search
  static const assetSearchHint = 'asset.search.hint';
  static const assetSearchTitle = 'asset.search.title';
  static const assetSearchSubtitle = 'asset.search.subtitle';
  static const assetSearchNoResults = 'asset.search.noResults';
  static const assetSearchNoResultsFor = 'asset.search.noResultsFor';

  // * Asset — Upsert
  static const assetUpsertAddTitle = 'asset.upsert.addTitle';
  static const assetUpsertEditTitle = 'asset.upsert.editTitle';
  static const assetUpsertSuccess = 'asset.upsert.success';
  static const assetUpsertErrorOccurred = 'asset.upsert.errorOccurred';
  static const assetUpsertDeleteTitle = 'asset.upsert.deleteTitle';
  static const assetUpsertDeleteConfirm = 'asset.upsert.deleteConfirm';
  static const assetUpsertCancel = 'asset.upsert.cancel';
  static const assetUpsertDelete = 'asset.upsert.delete';
  static const assetUpsertTypeLabel = 'asset.upsert.typeLabel';
  static const assetUpsertTypeHint = 'asset.upsert.typeHint';
  static const assetUpsertTypeCash = 'asset.upsert.typeCash';
  static const assetUpsertTypeBank = 'asset.upsert.typeBank';
  static const assetUpsertTypeEWallet = 'asset.upsert.typeEWallet';
  static const assetUpsertTypeStock = 'asset.upsert.typeStock';
  static const assetUpsertTypeCrypto = 'asset.upsert.typeCrypto';
  static const assetUpsertNameLabel = 'asset.upsert.nameLabel';
  static const assetUpsertNamePlaceholder = 'asset.upsert.namePlaceholder';
  static const assetUpsertBalanceLabel = 'asset.upsert.balanceLabel';
  static const assetUpsertCurrentIconLabel = 'asset.upsert.currentIconLabel';
  static const assetUpsertChangeIcon = 'asset.upsert.changeIcon';
  static const assetUpsertIconLabel = 'asset.upsert.iconLabel';
  static const assetUpsertIconHint = 'asset.upsert.iconHint';
  static const assetUpsertSaveChanges = 'asset.upsert.saveChanges';
  static const assetUpsertAddAsset = 'asset.upsert.addAsset';
  static const assetUpsertDeleteAsset = 'asset.upsert.deleteAsset';

  // ──────────────────────────────────────────────
  // * Auth
  // ──────────────────────────────────────────────
  static const authSignInTitle = 'auth.signIn.title';
  static const authSignUpTitle = 'auth.signUp.title';

  // ──────────────────────────────────────────────
  // * Backup — Screen
  // ──────────────────────────────────────────────
  static const backupScreenTitle = 'backup.screen.title';
  static const backupScreenInfoDescription = 'backup.screen.infoDescription';
  static const backupScreenCurrentData = 'backup.screen.currentData';
  static const backupScreenCategories = 'backup.screen.categories';
  static const backupScreenAssets = 'backup.screen.assets';
  static const backupScreenTransactions = 'backup.screen.transactions';
  static const backupScreenBudgets = 'backup.screen.budgets';
  static const backupScreenTotal = 'backup.screen.total';
  static const backupScreenTotalItems = 'backup.screen.totalItems';
  static const backupScreenExportTitle = 'backup.screen.exportTitle';
  static const backupScreenExportDescription =
      'backup.screen.exportDescription';
  static const backupScreenExportButton = 'backup.screen.exportButton';
  static const backupScreenImportTitle = 'backup.screen.importTitle';
  static const backupScreenImportDescription =
      'backup.screen.importDescription';
  static const backupScreenImportButton = 'backup.screen.importButton';
  static const backupScreenImportConfirmTitle =
      'backup.screen.importConfirmTitle';
  static const backupScreenImportDataLabel = 'backup.screen.importDataLabel';
  static const backupScreenImportWarning = 'backup.screen.importWarning';
  static const backupScreenImportCancel = 'backup.screen.importCancel';
  static const backupScreenImportConfirmButton =
      'backup.screen.importConfirmButton';
  static const backupScreenSaveDialogTitle = 'backup.screen.saveDialogTitle';
  static const backupScreenSuccess = 'backup.screen.success';
  static const backupScreenBackupSavedTo = 'backup.screen.backupSavedTo';
  static const backupScreenImportSuccess = 'backup.screen.importSuccess';
  static const backupScreenError = 'backup.screen.error';
  static const backupScreenErrorOccurred = 'backup.screen.errorOccurred';
  static const backupScreenReadBackupFailed = 'backup.screen.readBackupFailed';
  static const backupScreenSaveFileFailed = 'backup.screen.saveFileFailed';

  // ──────────────────────────────────────────────
  // * Budget — Validator
  // ──────────────────────────────────────────────
  static const budgetValidatorCategoryRequired =
      'budget.validator.categoryRequired';
  static const budgetValidatorAmountLimitRequired =
      'budget.validator.amountLimitRequired';
  static const budgetValidatorAmountLimitInvalid =
      'budget.validator.amountLimitInvalid';
  static const budgetValidatorAmountLimitPositive =
      'budget.validator.amountLimitPositive';
  static const budgetValidatorPeriodRequired =
      'budget.validator.periodRequired';
  static const budgetValidatorUlidRequired = 'budget.validator.ulidRequired';

  // * Budget — Screen
  static const budgetScreenTitle = 'budget.screen.title';
  static const budgetScreenTabAll = 'budget.screen.tabAll';
  static const budgetScreenTabMonthly = 'budget.screen.tabMonthly';
  static const budgetScreenTabWeekly = 'budget.screen.tabWeekly';
  static const budgetScreenTabYearly = 'budget.screen.tabYearly';
  static const budgetScreenTabCustom = 'budget.screen.tabCustom';
  static const budgetScreenErrorOccurred = 'budget.screen.errorOccurred';
  static const budgetScreenEmptyTitle = 'budget.screen.emptyTitle';
  static const budgetScreenEmptySubtitle = 'budget.screen.emptySubtitle';

  // * Budget — Search
  static const budgetSearchHint = 'budget.search.hint';
  static const budgetSearchTitle = 'budget.search.title';
  static const budgetSearchSubtitle = 'budget.search.subtitle';
  static const budgetSearchNoResults = 'budget.search.noResults';
  static const budgetSearchNoResultsFor = 'budget.search.noResultsFor';

  // * Budget — Upsert
  static const budgetUpsertAddTitle = 'budget.upsert.addTitle';
  static const budgetUpsertEditTitle = 'budget.upsert.editTitle';
  static const budgetUpsertSuccess = 'budget.upsert.success';
  static const budgetUpsertErrorOccurred = 'budget.upsert.errorOccurred';
  static const budgetUpsertDeleteTitle = 'budget.upsert.deleteTitle';
  static const budgetUpsertDeleteConfirm = 'budget.upsert.deleteConfirm';
  static const budgetUpsertCancel = 'budget.upsert.cancel';
  static const budgetUpsertDelete = 'budget.upsert.delete';
  static const budgetUpsertCategoryLabel = 'budget.upsert.categoryLabel';
  static const budgetUpsertCategoryHint = 'budget.upsert.categoryHint';
  static const budgetUpsertAmountLimitLabel = 'budget.upsert.amountLimitLabel';
  static const budgetUpsertAmountLimitPlaceholder =
      'budget.upsert.amountLimitPlaceholder';
  static const budgetUpsertPeriodLabel = 'budget.upsert.periodLabel';
  static const budgetUpsertPeriodHint = 'budget.upsert.periodHint';
  static const budgetUpsertPeriodMonthly = 'budget.upsert.periodMonthly';
  static const budgetUpsertPeriodWeekly = 'budget.upsert.periodWeekly';
  static const budgetUpsertPeriodYearly = 'budget.upsert.periodYearly';
  static const budgetUpsertPeriodCustom = 'budget.upsert.periodCustom';
  static const budgetUpsertStartDateLabel = 'budget.upsert.startDateLabel';
  static const budgetUpsertStartDateHint = 'budget.upsert.startDateHint';
  static const budgetUpsertEndDateLabel = 'budget.upsert.endDateLabel';
  static const budgetUpsertEndDateHint = 'budget.upsert.endDateHint';
  static const budgetUpsertSaveChanges = 'budget.upsert.saveChanges';
  static const budgetUpsertAddBudget = 'budget.upsert.addBudget';
  static const budgetUpsertDeleteBudget = 'budget.upsert.deleteBudget';

  // ──────────────────────────────────────────────
  // * Category — Validator
  // ──────────────────────────────────────────────
  static const categoryValidatorNameRequired =
      'category.validator.nameRequired';
  static const categoryValidatorNameMinLength =
      'category.validator.nameMinLength';
  static const categoryValidatorNameMaxLength =
      'category.validator.nameMaxLength';
  static const categoryValidatorTypeRequired =
      'category.validator.typeRequired';
  static const categoryValidatorUlidRequired =
      'category.validator.ulidRequired';

  // * Category — Screen
  static const categoryScreenTitle = 'category.screen.title';
  static const categoryScreenTabAll = 'category.screen.tabAll';
  static const categoryScreenTabExpense = 'category.screen.tabExpense';
  static const categoryScreenTabIncome = 'category.screen.tabIncome';
  static const categoryScreenErrorOccurred = 'category.screen.errorOccurred';
  static const categoryScreenEmptyTitle = 'category.screen.emptyTitle';
  static const categoryScreenEmptySubtitle = 'category.screen.emptySubtitle';

  // * Category — Search
  static const categorySearchHint = 'category.search.hint';
  static const categorySearchTitle = 'category.search.title';
  static const categorySearchSubtitle = 'category.search.subtitle';
  static const categorySearchNoResults = 'category.search.noResults';
  static const categorySearchNoResultsFor = 'category.search.noResultsFor';

  // * Category — Upsert
  static const categoryUpsertAddTitle = 'category.upsert.addTitle';
  static const categoryUpsertEditTitle = 'category.upsert.editTitle';
  static const categoryUpsertSuccess = 'category.upsert.success';
  static const categoryUpsertErrorOccurred = 'category.upsert.errorOccurred';
  static const categoryUpsertDeleteTitle = 'category.upsert.deleteTitle';
  static const categoryUpsertDeleteConfirm = 'category.upsert.deleteConfirm';
  static const categoryUpsertCancel = 'category.upsert.cancel';
  static const categoryUpsertDelete = 'category.upsert.delete';
  static const categoryUpsertTypeLabel = 'category.upsert.typeLabel';
  static const categoryUpsertTypeHint = 'category.upsert.typeHint';
  static const categoryUpsertTypeExpense = 'category.upsert.typeExpense';
  static const categoryUpsertTypeIncome = 'category.upsert.typeIncome';
  static const categoryUpsertParentLabel = 'category.upsert.parentLabel';
  static const categoryUpsertParentHint = 'category.upsert.parentHint';
  static const categoryUpsertParentCantBeChild =
      'category.upsert.parentCantBeChild';
  static const categoryUpsertSubCategoryOf = 'category.upsert.subCategoryOf';
  static const categoryUpsertParentCategoryLabel =
      'category.upsert.parentCategoryLabel';
  static const categoryUpsertMainCategoryDesc =
      'category.upsert.mainCategoryDesc';
  static const categoryUpsertNameLabel = 'category.upsert.nameLabel';
  static const categoryUpsertNamePlaceholder =
      'category.upsert.namePlaceholder';
  static const categoryUpsertCurrentIconLabel =
      'category.upsert.currentIconLabel';
  static const categoryUpsertChangeIcon = 'category.upsert.changeIcon';
  static const categoryUpsertIconLabel = 'category.upsert.iconLabel';
  static const categoryUpsertIconHint = 'category.upsert.iconHint';
  static const categoryUpsertColorLabel = 'category.upsert.colorLabel';
  static const categoryUpsertSaveChanges = 'category.upsert.saveChanges';
  static const categoryUpsertAddCategory = 'category.upsert.addCategory';
  static const categoryUpsertDeleteCategory = 'category.upsert.deleteCategory';

  // ──────────────────────────────────────────────
  // * Other — Screen
  // ──────────────────────────────────────────────
  static const otherScreenTitle = 'other.screen.title';
  static const otherScreenComingSoon = 'other.screen.comingSoon';
  static const otherScreenFeatureInDevelopment =
      'other.screen.featureInDevelopment';
  static const otherScreenSettings = 'other.screen.settings';
  static const otherScreenManageAssets = 'other.screen.manageAssets';
  static const otherScreenManageCategories = 'other.screen.manageCategories';
  static const otherScreenPassword = 'other.screen.password';
  static const otherScreenBackup = 'other.screen.backup';
  static const otherScreenHelp = 'other.screen.help';

  // * Other — Setting
  static const otherSettingTitle = 'other.setting.title';
  static const otherSettingAppearance = 'other.setting.appearance';
  static const otherSettingCurrency = 'other.setting.currency';
  static const otherSettingCurrencyChangeSuccess =
      'other.setting.currencyChangeSuccess';

  // ──────────────────────────────────────────────
  // * Statistic — Screen
  // ──────────────────────────────────────────────
  static const statisticScreenTabExpense = 'statistic.screen.tabExpense';
  static const statisticScreenTabIncome = 'statistic.screen.tabIncome';
  static const statisticScreenErrorOccurred = 'statistic.screen.errorOccurred';
  static const statisticScreenTryAgain = 'statistic.screen.tryAgain';

  // ──────────────────────────────────────────────
  // * Transaction — Validator
  // ──────────────────────────────────────────────
  static const transactionValidatorAmountRequired =
      'transaction.validator.amountRequired';
  static const transactionValidatorAmountPositive =
      'transaction.validator.amountPositive';
  static const transactionValidatorAssetRequired =
      'transaction.validator.assetRequired';
  static const transactionValidatorDescriptionMaxLength =
      'transaction.validator.descriptionMaxLength';
  static const transactionValidatorUlidRequired =
      'transaction.validator.ulidRequired';

  // * Transaction — Screen
  static const transactionScreenTabDaily = 'transaction.screen.tabDaily';
  static const transactionScreenTabMonthly = 'transaction.screen.tabMonthly';
  static const transactionScreenTabCalendar = 'transaction.screen.tabCalendar';
  static const transactionScreenErrorOccurred =
      'transaction.screen.errorOccurred';

  // * Transaction — Search
  static const transactionSearchHint = 'transaction.search.hint';
  static const transactionSearchTitle = 'transaction.search.title';
  static const transactionSearchSubtitle = 'transaction.search.subtitle';
  static const transactionSearchNoResults = 'transaction.search.noResults';
  static const transactionSearchNoResultsFor =
      'transaction.search.noResultsFor';

  // * Transaction — Upsert
  static const transactionUpsertAddTitle = 'transaction.upsert.addTitle';
  static const transactionUpsertEditTitle = 'transaction.upsert.editTitle';
  static const transactionUpsertSuccess = 'transaction.upsert.success';
  static const transactionUpsertErrorOccurred =
      'transaction.upsert.errorOccurred';
  static const transactionUpsertDeleteTitle = 'transaction.upsert.deleteTitle';
  static const transactionUpsertDeleteConfirm =
      'transaction.upsert.deleteConfirm';
  static const transactionUpsertCancel = 'transaction.upsert.cancel';
  static const transactionUpsertDelete = 'transaction.upsert.delete';
  static const transactionUpsertTypeExpense = 'transaction.upsert.typeExpense';
  static const transactionUpsertTypeIncome = 'transaction.upsert.typeIncome';
  static const transactionUpsertAmountLabel = 'transaction.upsert.amountLabel';
  static const transactionUpsertAmountRequired =
      'transaction.upsert.amountRequired';
  static const transactionUpsertAmountMustBePositive =
      'transaction.upsert.amountMustBePositive';
  static const transactionUpsertAssetLabel = 'transaction.upsert.assetLabel';
  static const transactionUpsertAssetHint = 'transaction.upsert.assetHint';
  static const transactionUpsertAssetRequired =
      'transaction.upsert.assetRequired';
  static const transactionUpsertAddAsset = 'transaction.upsert.addAsset';
  static const transactionUpsertCategoryLabel =
      'transaction.upsert.categoryLabel';
  static const transactionUpsertCategoryHint =
      'transaction.upsert.categoryHint';
  static const transactionUpsertAddCategory = 'transaction.upsert.addCategory';
  static const transactionUpsertMainCategory =
      'transaction.upsert.mainCategory';
  static const transactionUpsertSubCategoryOf =
      'transaction.upsert.subCategoryOf';
  static const transactionUpsertDateTimeLabel =
      'transaction.upsert.dateTimeLabel';
  static const transactionUpsertDescriptionLabel =
      'transaction.upsert.descriptionLabel';
  static const transactionUpsertDescriptionPlaceholder =
      'transaction.upsert.descriptionPlaceholder';
  static const transactionUpsertSaveChanges = 'transaction.upsert.saveChanges';
  static const transactionUpsertAddTransaction =
      'transaction.upsert.addTransaction';
  static const transactionUpsertDeleteTransaction =
      'transaction.upsert.deleteTransaction';

  // * Transaction — BulkCopy
  static const transactionBulkCopyTitle = 'transaction.bulkCopy.title';
  static const transactionBulkCopyCopyFromLabel =
      'transaction.bulkCopy.copyFromLabel';
  static const transactionBulkCopyCopyFromHint =
      'transaction.bulkCopy.copyFromHint';
  static const transactionBulkCopySearchHint =
      'transaction.bulkCopy.searchHint';
  static const transactionBulkCopyNoDescription =
      'transaction.bulkCopy.noDescription';
  static const transactionBulkCopyNoCategory =
      'transaction.bulkCopy.noCategory';
  static const transactionBulkCopyNoTransactions =
      'transaction.bulkCopy.noTransactions';
  static const transactionBulkCopyTransactionsSelected =
      'transaction.bulkCopy.transactionsSelected';
  static const transactionBulkCopyClearAll = 'transaction.bulkCopy.clearAll';
  static const transactionBulkCopySelectToCopy =
      'transaction.bulkCopy.selectToCopy';
  static const transactionBulkCopyTransactionType =
      'transaction.bulkCopy.transactionType';
  static const transactionBulkCopyOriginal = 'transaction.bulkCopy.original';
  static const transactionBulkCopyRemove = 'transaction.bulkCopy.remove';
  static const transactionBulkCopySaveCount = 'transaction.bulkCopy.saveCount';
  static const transactionBulkCopySuccessCount =
      'transaction.bulkCopy.successCount';
  static const transactionBulkCopyPartialSuccess =
      'transaction.bulkCopy.partialSuccess';
  static const transactionBulkCopyCheckInvalidData =
      'transaction.bulkCopy.checkInvalidData';
  static const transactionBulkCopyAmountLabel =
      'transaction.bulkCopy.amountLabel';
  static const transactionBulkCopyAmountRequired =
      'transaction.bulkCopy.amountRequired';
  static const transactionBulkCopyAmountMustBePositive =
      'transaction.bulkCopy.amountMustBePositive';
  static const transactionBulkCopyAssetLabel =
      'transaction.bulkCopy.assetLabel';
  static const transactionBulkCopyAssetHint = 'transaction.bulkCopy.assetHint';
  static const transactionBulkCopyAssetRequired =
      'transaction.bulkCopy.assetRequired';
  static const transactionBulkCopyCategoryLabel =
      'transaction.bulkCopy.categoryLabel';
  static const transactionBulkCopyCategoryHint =
      'transaction.bulkCopy.categoryHint';
  static const transactionBulkCopyMainCategory =
      'transaction.bulkCopy.mainCategory';
  static const transactionBulkCopySubCategoryOf =
      'transaction.bulkCopy.subCategoryOf';
  static const transactionBulkCopyDateLabel = 'transaction.bulkCopy.dateLabel';
  static const transactionBulkCopyDescriptionLabel =
      'transaction.bulkCopy.descriptionLabel';
  static const transactionBulkCopyDescriptionPlaceholder =
      'transaction.bulkCopy.descriptionPlaceholder';
  static const transactionBulkCopyTypeExpense =
      'transaction.bulkCopy.typeExpense';
  static const transactionBulkCopyTypeIncome =
      'transaction.bulkCopy.typeIncome';
}
