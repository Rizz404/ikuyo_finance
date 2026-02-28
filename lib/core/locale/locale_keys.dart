// * Locale keys for easy_localization
// * Usage: LocaleKeys.someKey.tr()
// * Keys map to dot-notation paths in assets/translations/*.json
// * Run `dart run tools/merge_translations.dart` to rebuild assets/translations/
abstract class LocaleKeys {
  // * SharedWidgets — ColorPicker
  static const sharedWidgetsColorPickerCustomColorLabel =
      'sharedWidgets.colorPicker.customColorLabel';

  // * SharedWidgets — DetailActionButtons
  static const sharedWidgetsDetailActionsDelete = 'sharedWidgets.detailActions.delete';
  static const sharedWidgetsDetailActionsEdit = 'sharedWidgets.detailActions.edit';

  // * SharedWidgets — Dropdown
  static const sharedWidgetsDropdownSelectOption = 'sharedWidgets.dropdown.selectOption';

  // * SharedWidgets — FilePicker
  static const sharedWidgetsFilePickerMaxFilesError =
      'sharedWidgets.filePicker.maxFilesError';
  static const sharedWidgetsFilePickerFileSizeError =
      'sharedWidgets.filePicker.fileSizeError';
  static const sharedWidgetsFilePickerFileSizeErrorDesc =
      'sharedWidgets.filePicker.fileSizeErrorDesc';
  static const sharedWidgetsFilePickerPickFailed = 'sharedWidgets.filePicker.pickFailed';
  static const sharedWidgetsFilePickerChooseFiles = 'sharedWidgets.filePicker.chooseFiles';
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
  static const sharedWidgetsSearchFieldSearchHint = 'sharedWidgets.searchField.searchHint';
  static const sharedWidgetsSearchFieldClear = 'sharedWidgets.searchField.clear';

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
  static const sharedWidgetsThemeToggleLight = 'sharedWidgets.themeToggle.light';
  static const sharedWidgetsThemeToggleDark = 'sharedWidgets.themeToggle.dark';
  static const sharedWidgetsThemeToggleSystem = 'sharedWidgets.themeToggle.system';

  // * SharedWidgets — UserShell
  static const sharedWidgetsUserShellBackToExit = 'sharedWidgets.userShell.backToExit';
  static const sharedWidgetsUserShellTransactions = 'sharedWidgets.userShell.transactions';
  static const sharedWidgetsUserShellStatistics = 'sharedWidgets.userShell.statistics';
  static const sharedWidgetsUserShellAssets = 'sharedWidgets.userShell.assets';
  static const sharedWidgetsUserShellSettings = 'sharedWidgets.userShell.settings';
}
