// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navReports => 'Reports';

  @override
  String get navStock => 'Stock';

  @override
  String get appName => 'TelePOS';

  @override
  String get globalOk => 'OK';

  @override
  String get globalCancel => 'Cancel';

  @override
  String get globalYes => 'Yes';

  @override
  String get globalNo => 'No';

  @override
  String get globalSave => 'Save';

  @override
  String get globalNew => 'New';

  @override
  String get globalDelete => 'Delete';

  @override
  String get globalEdit => 'Edit';

  @override
  String get globalAdd => 'Add';

  @override
  String get globalSearch => 'Search';

  @override
  String get globalClose => 'Close';

  @override
  String get globalBack => 'Back';

  @override
  String get globalNext => 'Next';

  @override
  String get globalDone => 'Done';

  @override
  String get globalLoading => 'Loading...';

  @override
  String get globalError => 'Error';

  @override
  String get globalSuccess => 'Success';

  @override
  String get globalWarning => 'Warning';

  @override
  String get globalInfo => 'Info';

  @override
  String get globalConfirm => 'Confirm';

  @override
  String get globalClear => 'Clear';

  @override
  String get globalSelect => 'Select';

  @override
  String get globalAll => 'All';

  @override
  String get globalNone => 'None';

  @override
  String get globalTotal => 'Total';

  @override
  String get globalAmount => 'Amount';

  @override
  String get globalQuantity => 'Quantity';

  @override
  String get globalPrice => 'Price';

  @override
  String get globalDiscount => 'Discount';

  @override
  String get globalDate => 'Date';

  @override
  String get globalTime => 'Time';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginPin => 'Enter PIN';

  @override
  String get loginPinHint => '4 digits';

  @override
  String get loginEnter => 'Enter';

  @override
  String get loginSelectUser => 'Select user';

  @override
  String get loginNoUsers => 'No users';

  @override
  String get loginWrongPin => 'Wrong PIN';

  @override
  String get loginBlocked => 'User blocked';

  @override
  String get loginSessionExpired => 'Session expired';

  @override
  String get loginShiftRequired => 'Open shift to login';

  @override
  String get loginCashier => 'Cashier';

  @override
  String get loginAdmin => 'Administrator';

  @override
  String get loginManager => 'Manager';

  @override
  String get loginLogout => 'Logout';

  @override
  String get loginSwitchUser => 'Switch user';

  @override
  String get saleTitle => 'Sale';

  @override
  String get saleNewSale => 'New sale';

  @override
  String get saleAddProduct => 'Add product';

  @override
  String get saleScanBarcode => 'Scan barcode';

  @override
  String get saleEnterBarcode => 'Enter barcode';

  @override
  String get saleProductNotFound => 'Product not found';

  @override
  String get saleEmptyCart => 'Cart is empty';

  @override
  String get saleSubtotal => 'Subtotal';

  @override
  String get saleTax => 'Tax';

  @override
  String get saleTotalDiscount => 'Discount';

  @override
  String get saleToPay => 'To pay';

  @override
  String saleItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get saleRemoveItem => 'Remove item';

  @override
  String get saleClearCart => 'Clear cart';

  @override
  String get saleConfirmClear => 'Clear cart?';

  @override
  String get saleProceedPayment => 'Proceed to payment';

  @override
  String get saleHold => 'Hold';

  @override
  String get saleRecall => 'Recall';

  @override
  String get saleHeldSales => 'Held sales';

  @override
  String get saleNoHeldSales => 'No held sales';

  @override
  String get saleProductSearch => 'Search products';

  @override
  String get saleByCategory => 'By category';

  @override
  String get saleByName => 'By name';

  @override
  String get saleByBarcode => 'By barcode';

  @override
  String get saleWeight => 'Weight';

  @override
  String saleWeightKg(String weight) {
    return 'Weight: $weight kg';
  }

  @override
  String get saleEnterWeight => 'Enter weight';

  @override
  String get saleEnterQuantity => 'Enter quantity';

  @override
  String get saleEnterPrice => 'Enter price';

  @override
  String get saleFreePrice => 'Free price';

  @override
  String saleMaxDiscount(String percent) {
    return 'Max discount: $percent%';
  }

  @override
  String get refundTitle => 'Refund';

  @override
  String get refundNewRefund => 'New refund';

  @override
  String get refundByReceipt => 'By receipt';

  @override
  String get refundWithoutReceipt => 'Without receipt';

  @override
  String get refundEnterReceipt => 'Enter receipt number';

  @override
  String get refundReceiptNotFound => 'Receipt not found';

  @override
  String get refundSelectItems => 'Select items to refund';

  @override
  String get refundReason => 'Refund reason';

  @override
  String get refundConfirm => 'Confirm refund';

  @override
  String get refundAmount => 'Refund amount';

  @override
  String get refundComplete => 'Refund complete';

  @override
  String get refundCash => 'Cash refund';

  @override
  String get refundCard => 'Card refund';

  @override
  String get refundNoItems => 'No items to refund';

  @override
  String get refundAlreadyRefunded => 'Item already refunded';

  @override
  String get refundPartial => 'Partial refund';

  @override
  String get shiftTitle => 'Shift';

  @override
  String get shiftOpen => 'Open shift';

  @override
  String get shiftClose => 'Close shift';

  @override
  String get shiftCurrent => 'Current shift';

  @override
  String shiftNumber(int number) {
    return 'Shift #: $number';
  }

  @override
  String shiftOpenedAt(String time) {
    return 'Opened: $time';
  }

  @override
  String shiftCashier(String name) {
    return 'Cashier: $name';
  }

  @override
  String shiftSalesCount(int count) {
    return 'Sales: $count';
  }

  @override
  String shiftRefundsCount(int count) {
    return 'Refunds: $count';
  }

  @override
  String get shiftTotalSales => 'Total sales';

  @override
  String get shiftTotalRefunds => 'Total refunds';

  @override
  String get shiftCashInDrawer => 'Cash in drawer';

  @override
  String get shiftExpected => 'Expected';

  @override
  String get shiftActual => 'Actual';

  @override
  String get shiftDifference => 'Difference';

  @override
  String get shiftXReport => 'X-report';

  @override
  String get shiftZReport => 'Z-report';

  @override
  String get shiftConfirmClose => 'Close shift?';

  @override
  String get shiftAlreadyOpen => 'Shift already open';

  @override
  String get shiftNotOpen => 'Shift not open';

  @override
  String get shiftOpenFirst => 'Open shift first';

  @override
  String get paymentTitle => 'Payment';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentCard => 'Card';

  @override
  String get paymentKaspi => 'Kaspi QR';

  @override
  String get paymentBonus => 'Bonus';

  @override
  String get paymentDebt => 'Debt';

  @override
  String get paymentMixed => 'Mixed';

  @override
  String get paymentEnterAmount => 'Enter amount';

  @override
  String paymentRemaining(String amount) {
    return 'Remaining: $amount';
  }

  @override
  String paymentChange(String amount) {
    return 'Change: $amount';
  }

  @override
  String get paymentComplete => 'Payment complete';

  @override
  String get paymentFailed => 'Payment failed';

  @override
  String get paymentWaitingCard => 'Waiting for card...';

  @override
  String get paymentWaitingQr => 'Waiting for QR...';

  @override
  String get paymentInsertCard => 'Insert card';

  @override
  String get paymentScanQr => 'Scan QR';

  @override
  String get paymentApproved => 'Approved';

  @override
  String get paymentDeclined => 'Declined';

  @override
  String get paymentReceipt => 'Print receipt';

  @override
  String get paymentNoReceipt => 'No receipt';

  @override
  String get paymentEmail => 'Send email';

  @override
  String get paymentSms => 'Send SMS';

  @override
  String get historyTitle => 'History';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String get historyThisWeek => 'This week';

  @override
  String get historyThisMonth => 'This month';

  @override
  String get historyDateRange => 'Select period';

  @override
  String get historyNoSales => 'No sales for period';

  @override
  String historyReceipt(String number) {
    return 'Receipt #$number';
  }

  @override
  String get historyReprint => 'Reprint';

  @override
  String get historyDetails => 'Details';

  @override
  String get historySale => 'Sale';

  @override
  String get historyRefund => 'Refund';

  @override
  String get historyFilter => 'Filter';

  @override
  String get agentTitle => 'Agents';

  @override
  String get agentClients => 'Clients';

  @override
  String get agentSuppliers => 'Suppliers';

  @override
  String get agentSearch => 'Search agent';

  @override
  String get agentAdd => 'Add agent';

  @override
  String get agentEdit => 'Edit';

  @override
  String get agentName => 'Name';

  @override
  String get agentPhone => 'Phone';

  @override
  String get agentEmail => 'Email';

  @override
  String get agentIin => 'IIN/BIN';

  @override
  String get agentAddress => 'Address';

  @override
  String get agentBalance => 'Balance';

  @override
  String get agentBonusBalance => 'Bonus balance';

  @override
  String get agentDebt => 'Debt';

  @override
  String get agentNoAgents => 'No agents';

  @override
  String get agentSaveSuccess => 'Agent saved';

  @override
  String get agentDeleteConfirm => 'Delete agent?';

  @override
  String get cashTitle => 'Cash';

  @override
  String get cashInvestment => 'Cash in';

  @override
  String get cashExpense => 'Cash out';

  @override
  String get cashBalance => 'Cash balance';

  @override
  String get cashEnterAmount => 'Enter amount';

  @override
  String get cashReason => 'Reason';

  @override
  String get cashReasonPlaceholder => 'Enter reason';

  @override
  String get cashSuccess => 'Operation complete';

  @override
  String get cashExpenseTypes => 'Expense type';

  @override
  String get cashSalary => 'Salary';

  @override
  String get cashRent => 'Rent';

  @override
  String get cashUtilities => 'Utilities';

  @override
  String get cashSupplies => 'Supplies';

  @override
  String get cashOther => 'Other';

  @override
  String get discountTitle => 'Discount';

  @override
  String get discountPercent => 'Percent';

  @override
  String get discountFixed => 'Fixed';

  @override
  String get discountEnterValue => 'Enter value';

  @override
  String get discountApply => 'Apply';

  @override
  String get discountRemove => 'Remove discount';

  @override
  String get discountOnItem => 'Item discount';

  @override
  String get discountOnTotal => 'Total discount';

  @override
  String get discountMaxExceeded => 'Maximum discount exceeded';

  @override
  String get quickProductTitle => 'Quick products';

  @override
  String get quickProductAdd => 'Add product';

  @override
  String get quickProductName => 'Name';

  @override
  String get quickProductPrice => 'Price';

  @override
  String get quickProductCategory => 'Category';

  @override
  String get quickProductSave => 'Save';

  @override
  String get quickProductDelete => 'Delete';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncStatus => 'Sync status';

  @override
  String syncLastSync(String time) {
    return 'Last sync: $time';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncInProgress => 'Syncing...';

  @override
  String get syncSuccess => 'Sync complete';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get syncProducts => 'Products';

  @override
  String get syncPrices => 'Prices';

  @override
  String get syncAgents => 'Agents';

  @override
  String get syncSales => 'Sales';

  @override
  String syncPending(int count) {
    return 'Pending: $count';
  }

  @override
  String get syncOffline => 'Offline';

  @override
  String get syncOnline => 'Online';

  @override
  String get printerTitle => 'Printer';

  @override
  String get printerStatus => 'Printer status';

  @override
  String get printerConnected => 'Connected';

  @override
  String get printerDisconnected => 'Disconnected';

  @override
  String get printerError => 'Printer error';

  @override
  String get printerPaperOut => 'Paper out';

  @override
  String get printerConnect => 'Connect';

  @override
  String get printerDisconnect => 'Disconnect';

  @override
  String get printerTest => 'Test print';

  @override
  String get printerSettings => 'Printer settings';

  @override
  String get printerWidth => 'Receipt width';

  @override
  String get additionalTitle => 'Additional';

  @override
  String get additionalSettings => 'Settings';

  @override
  String get additionalReports => 'Reports';

  @override
  String get additionalInventory => 'Inventory';

  @override
  String get additionalSupply => 'Supply';

  @override
  String get additionalPriceChange => 'Price change';

  @override
  String get additionalBackup => 'Backup';

  @override
  String get additionalRestore => 'Restore';

  @override
  String get additionalUpdate => 'Update';

  @override
  String get additionalAbout => 'About';

  @override
  String get additionalLicense => 'License';

  @override
  String get additionalSupport => 'Support';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get receiptNumber => 'Receipt #';

  @override
  String get receiptDate => 'Date';

  @override
  String get receiptCashier => 'Cashier';

  @override
  String get receiptItems => 'Items';

  @override
  String get receiptSubtotal => 'Subtotal';

  @override
  String get receiptDiscount => 'Discount';

  @override
  String get receiptTax => 'Tax';

  @override
  String get receiptTotal => 'TOTAL';

  @override
  String get receiptCash => 'Cash';

  @override
  String get receiptCard => 'Card';

  @override
  String get receiptChange => 'Change';

  @override
  String get receiptThankYou => 'Thank you for your purchase!';

  @override
  String get receiptFiscalNumber => 'Fiscal number';

  @override
  String get receiptQrCode => 'QR for verification';

  @override
  String get receiptCopy => 'Receipt copy';

  @override
  String get errorUnknown => 'Unknown error';

  @override
  String get errorNetwork => 'Network error';

  @override
  String get errorServer => 'Server error';

  @override
  String get errorTimeout => 'Timeout';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get errorPermission => 'Permission denied';

  @override
  String get errorDatabase => 'Database error';

  @override
  String get errorValidation => 'Validation error';

  @override
  String get errorRequired => 'Required field';

  @override
  String get errorInvalidFormat => 'Invalid format';

  @override
  String errorMinLength(int min) {
    return 'Minimum $min characters';
  }

  @override
  String errorMaxLength(int max) {
    return 'Maximum $max characters';
  }

  @override
  String errorMinValue(String min) {
    return 'Minimum $min';
  }

  @override
  String errorMaxValue(String max) {
    return 'Maximum $max';
  }

  @override
  String get errorPrinter => 'Printer error';

  @override
  String get errorFiscal => 'Fiscal error';

  @override
  String get errorPayment => 'Payment error';

  @override
  String get errorSync => 'Sync error';

  @override
  String get errorNoInternet => 'No internet connection';

  @override
  String get errorTryAgain => 'Try again';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpTips => 'Tips';

  @override
  String get helpShortcuts => 'Keyboard shortcuts';

  @override
  String get helpRelatedScreens => 'Related sections';

  @override
  String get helpKey => 'Key';

  @override
  String get helpAction => 'Action';

  @override
  String get navSale => 'Sale';

  @override
  String get navRefund => 'Refund';

  @override
  String get navShift => 'Shift';

  @override
  String get navHistory => 'History';

  @override
  String get navTables => 'Tables';

  @override
  String get navOrders => 'Orders';

  @override
  String get navQueue => 'Queue';

  @override
  String get navIntake => 'Intake';

  @override
  String get navAgents => 'Agents';

  @override
  String get navSupply => 'Supply';

  @override
  String get navCash => 'Cash';

  @override
  String get navSettings => 'Settings';

  @override
  String get navSync => 'Sync';

  @override
  String get navMore => 'More';

  @override
  String get navAdditional => 'Additional';

  @override
  String get navLockScreen => 'Lock';

  @override
  String get navMain => 'Main';

  @override
  String get loginEnterSystem => 'Login';

  @override
  String get loginWithoutPin => 'Login without PIN';

  @override
  String get loginShiftOpen => 'Shift open';

  @override
  String get loginShiftClosed => 'Shift closed';

  @override
  String get saleQuickProducts => 'Quick products';

  @override
  String get saleIncrease => 'Increase';

  @override
  String get saleDecrease => 'Decrease';

  @override
  String get saleMark => 'Marking';

  @override
  String get saleDataMatrix => 'Marking (DataMatrix)';

  @override
  String get saleHeld => 'Sale held';

  @override
  String get saleNoDeferredSales => 'No deferred sales';

  @override
  String get saleReceiptNo => 'Receipt #';

  @override
  String get salePositions => 'Items';

  @override
  String get saleSearchHint => 'Search product (name or barcode)';

  @override
  String get refundWithReceipt => 'WITH RECEIPT';

  @override
  String get refundWithoutReceiptUpper => 'WITHOUT RECEIPT';

  @override
  String get refundLoadReceipt => 'Load receipt';

  @override
  String get refundSearchProducts => 'Search products';

  @override
  String get refundSelectAll => 'Select all';

  @override
  String get refundDeselectAll => 'Deselect all';

  @override
  String refundMaxQuantity(String max) {
    return 'Maximum: $max';
  }

  @override
  String get refundConfirmTitle => 'Confirm refund';

  @override
  String refundSelectedItems(int count) {
    return 'Selected items: $count';
  }

  @override
  String get refundSuccessMsg => 'Refund completed successfully';

  @override
  String get refundSearchHint => 'Search product for refund';

  @override
  String get paymentRefundTitle => 'Refund';

  @override
  String get paymentPayTitle => 'Payment';

  @override
  String get paymentRefundBtn => 'REFUND';

  @override
  String get paymentPayBtn => 'PAY';

  @override
  String get paymentChangeLabel => 'Change:';

  @override
  String get paymentSuccessRefund => 'Refund completed';

  @override
  String get paymentSuccessPay => 'Payment successful';

  @override
  String get paymentCardType => 'Card';

  @override
  String get paymentToPay => 'To pay';

  @override
  String get paymentBonusLabel => 'Bonuses';

  @override
  String get paymentTotalToPay => 'Total to pay';

  @override
  String get paymentByCard => 'By card';

  @override
  String get paymentRemainLabel => 'Remaining';

  @override
  String get shiftBills => 'Bills';

  @override
  String get shiftTotalAmount => 'Total amount';

  @override
  String get shiftOperations => 'Operations';

  @override
  String get shiftOpened => 'Shift opened';

  @override
  String get shiftClosed => 'Shift closed';

  @override
  String get shiftOverAgeTitle => 'Shift open for over 24 hours';

  @override
  String get shiftOverAgeMessage =>
      'Sale is blocked. Close the current shift and open a new one to continue.';

  @override
  String shiftSince(String time) {
    return 'since $time';
  }

  @override
  String get shiftSystem => 'System';

  @override
  String get shiftEntered => 'Entered';

  @override
  String get shiftRecounting => 'Bill recount';

  @override
  String get shiftManualEntry => 'Manual amount entry';

  @override
  String get shiftCashOps => 'Cash operations';

  @override
  String get shiftOpenAction => 'Opening shift';

  @override
  String get shiftCloseAction => 'Closing shift';

  @override
  String get historyOperations => 'Transaction history';

  @override
  String get historyResetFilters => 'Reset filters';

  @override
  String get historyRefresh => 'Refresh';

  @override
  String get historyNoRecords => 'No records';

  @override
  String get historyChangeFilters => 'Try changing filters';

  @override
  String get historyEmpty => 'No transaction history';

  @override
  String get historyFilterTitle => 'Filters';

  @override
  String get historyPeriod => 'Period';

  @override
  String get historyOpType => 'Operation type';

  @override
  String get historySearchHint => 'Receipt number, amount...';

  @override
  String historyType(String type) {
    return 'Type:';
  }

  @override
  String get historyPrint => 'Print receipt';

  @override
  String agentFound(int count) {
    return 'Found: $count';
  }

  @override
  String get agentWithDebt => 'With debt only';

  @override
  String get agentSearchHint => 'Search by name or phone...';

  @override
  String get agentNewClient => 'New client';

  @override
  String get agentNameRequired => 'Name *';

  @override
  String get agentEnterName => 'Enter client name';

  @override
  String get agentPhoneLabel => 'Phone';

  @override
  String get agentIinLabel => 'BIN/IIN';

  @override
  String get agentIinHint => '12 digits';

  @override
  String get agentDeleteQuestion => 'Delete client?';

  @override
  String agentDeleteConfirmMsg(String name) {
    return 'Are you sure you want to delete $name?';
  }

  @override
  String get agentDeleted => 'Client deleted';

  @override
  String get agentFoundExisting => 'Client found';

  @override
  String get supplyTitle => 'Supply receipt';

  @override
  String get supplySaved => 'Supply saved';

  @override
  String get supplySaveError => 'Save error';

  @override
  String get supplyCancelQuestion => 'Cancel supply?';

  @override
  String get supplyDataLost => 'All entered data will be lost.';

  @override
  String supplyProducts(int count) {
    return 'Products: $count';
  }

  @override
  String get supplyBarcodeHint => 'Barcode or article';

  @override
  String get supplyComment => 'Comment';

  @override
  String get supplyCommentHint => 'Enter comment...';

  @override
  String get supplyNotFound => 'Product not found';

  @override
  String get supplySelectSupplier => 'Select supplier';

  @override
  String get supplySelectAccount => 'Select account';

  @override
  String supplyBalance(String amount) {
    return 'Balance: $amount';
  }

  @override
  String get supplyPurchasePrice => 'Purchase price';

  @override
  String get supplySerialNumbers => 'Serial numbers';

  @override
  String get supplySerialHint => 'Enter or scan S/N';

  @override
  String supplySerialCount(int count, int expected) {
    return '$count of $expected';
  }

  @override
  String get supplySerialMismatch =>
      'Serial number count does not match quantity';

  @override
  String get supplyInvalidQty => 'Enter valid quantity';

  @override
  String get supplyInvalidPrice => 'Enter valid price';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get inventoryFullCount => 'Full inventory count';

  @override
  String get inventoryFullCountSubtitle =>
      'Zero out quantity of unscanned products';

  @override
  String get inventoryStart => 'Start';

  @override
  String get inventoryFinish => 'Finish';

  @override
  String get inventoryScanHint => 'Scan barcode';

  @override
  String get inventoryScanProducts => 'Scan products to count';

  @override
  String get inventoryPressStart => 'Press \"Start\" for inventory';

  @override
  String inventoryProductCount(int count) {
    return 'Products: $count';
  }

  @override
  String inventoryDiscrepancies(int count) {
    return 'Discrepancies: $count';
  }

  @override
  String get inventoryExpected => 'Expected:';

  @override
  String get inventoryActual => 'Actual:';

  @override
  String get inventoryProduct => 'Product';

  @override
  String get inventoryExpectedQty => 'Expected';

  @override
  String get inventoryActualQty => 'Actual';

  @override
  String get inventoryDiscrepancy => 'Discrepancy';

  @override
  String get inventoryActualLabel => 'Actual quantity';

  @override
  String get inventoryFinishQuestion => 'Finish inventory?';

  @override
  String get inventoryCompleted => 'Inventory completed';

  @override
  String get writeoffTitle => 'Write-off';

  @override
  String get writeoffReason => 'Reason';

  @override
  String get writeoffProduct => 'Product';

  @override
  String get writeoffScanHint => 'Scan barcode';

  @override
  String get writeoffCommentHint => 'Optional';

  @override
  String get writeoffReasonBreakage => 'Breakage';

  @override
  String get writeoffReasonExpired => 'Expired';

  @override
  String get writeoffReasonDamage => 'Damage';

  @override
  String get writeoffReasonLoss => 'Loss';

  @override
  String get writeoffReasonOther => 'Other';

  @override
  String get writeoffCancelQuestion => 'Cancel write-off?';

  @override
  String get writeoffSaved => 'Write-off saved';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPosInfo => 'POS info';

  @override
  String get settingsPosName => 'POS name';

  @override
  String get settingsCompany => 'Company';

  @override
  String get settingsIin => 'IIN/BIN';

  @override
  String get settingsPosId => 'POS ID';

  @override
  String get settingsStoreId => 'Store ID';

  @override
  String get settingsNotSpecified => 'Not specified';

  @override
  String get settingsAppVersion => 'App version';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsPlatform => 'Platform';

  @override
  String get settingsLanguage => 'Interface language';

  @override
  String get settingsLanguageChanged => 'Language changed';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsCurrencySymbol => 'Symbol';

  @override
  String get settingsCurrencyCode => 'Code';

  @override
  String get settingsCountry => 'Country';

  @override
  String get settingsAdditional => 'Additional settings';

  @override
  String get settingsTransport => 'Transport';

  @override
  String get settingsTransportDesc => 'Data sync settings';

  @override
  String get settingsPrinter => 'Printer';

  @override
  String get settingsPrinterDesc => 'Receipt print settings';

  @override
  String get settingsFiscal => 'Fiscalization';

  @override
  String get settingsFiscalDesc => 'WebKassa, OFD, VAT';

  @override
  String get settingsTelegram => 'Telegram';

  @override
  String get settingsTelegramDesc => 'Telegram integration and channels';

  @override
  String get settingsPermissions => 'Permissions';

  @override
  String get settingsPermissionsDesc => 'Cashier permissions';

  @override
  String get fiscalTitle => 'Fiscalization';

  @override
  String get fiscalOperator => 'Fiscal operator';

  @override
  String get fiscalWebkassa => 'WebKassa settings';

  @override
  String get fiscalTaxpayer => 'Taxpayer data';

  @override
  String get fiscalVatSettings => 'VAT settings';

  @override
  String get fiscalVatPayer => 'VAT payer';

  @override
  String get fiscalPrintVat => 'Print VAT on receipt';

  @override
  String get fiscalSaved => 'Settings saved';

  @override
  String get fiscalSaveError => 'Save error';

  @override
  String get printerSettingsTitle => 'Printer settings';

  @override
  String get printerConnectionType => 'Connection type';

  @override
  String get printerAddress => 'Printer address';

  @override
  String get printerPaperWidth => 'Paper width';

  @override
  String get printerTesting => 'Testing';

  @override
  String get printerReady => 'Ready';

  @override
  String get printerNotConnected => 'Not connected';

  @override
  String get printerPaperOut2 => 'No paper';

  @override
  String get printerCoverOpen => 'Cover open';

  @override
  String get printerPrinting => 'Printing...';

  @override
  String get printerCheckStatus => 'Checking...';

  @override
  String get printerPrintSuccess => 'Print successful';

  @override
  String get printerPrintError => 'Print error';

  @override
  String get printerCheckBtn => 'Check';

  @override
  String get printerTestReceipt => 'Test receipt';

  @override
  String get printerPort => 'Port';

  @override
  String get cashOperationTitle => 'Cash operation';

  @override
  String get cashWithdrawal => 'Withdrawal';

  @override
  String get cashCommentRequired => 'Comment *';

  @override
  String get cashCommentOptional => 'Comment';

  @override
  String get cashCommentHint => 'Enter comment...';

  @override
  String get cashEnterAmountMsg => 'Enter amount';

  @override
  String get cashPositiveOnly => 'Amount must be positive';

  @override
  String get cashInsufficient => 'Insufficient cash';

  @override
  String get cashInvalidAmount => 'Enter valid amount';

  @override
  String get cashInDrawer => 'Cash in drawer:';

  @override
  String get telegramTitle => 'Telegram Settings';

  @override
  String get telegramAuth => 'Authorization';

  @override
  String get telegramSync => 'Sync';

  @override
  String get telegramNotifications => 'Enable notifications';

  @override
  String get telegramAutoSync => 'Auto sync';

  @override
  String get telegramSyncData => 'Auto sync data';

  @override
  String get telegramSyncInterval => 'Sync interval';

  @override
  String get telegramForceSync => 'Force sync';

  @override
  String get telegramFullSync => 'Full sync';

  @override
  String get telegramRecreateChannels => 'Recreate channels';

  @override
  String get telegramLogout => 'Logout from Telegram';

  @override
  String get telegramSyncComplete => 'Sync complete';

  @override
  String get telegramSyncError => 'Sync error';

  @override
  String get telegramLogoutComplete => 'Logout complete';

  @override
  String get chatTitle => 'Staff chat';

  @override
  String chatParticipants(int count) {
    return '$count participants';
  }

  @override
  String get chatConnected => 'Connected';

  @override
  String get chatDisconnected => 'No connection';

  @override
  String get chatNoMessages => 'No messages';

  @override
  String get chatStartConversation => 'Start chatting with team';

  @override
  String get chatMessageHint => 'Message...';

  @override
  String get chatSearch => 'Search';

  @override
  String get chatSearchHint => 'Enter search text...';

  @override
  String get chatMembers => 'Members';

  @override
  String get chatLinkTelegram => 'Link Telegram';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatDeleteMsg => 'Delete message?';

  @override
  String get chatDeleteConfirm => 'Message will be deleted for all members.';

  @override
  String get chatPhoto => 'Photo';

  @override
  String get chatDocument => 'Document';

  @override
  String get chatLocation => 'Location';

  @override
  String get chatCamera => 'Camera';

  @override
  String get chatGallery => 'Gallery';

  @override
  String get chatSelectSource => 'Select source';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get updateInProgress => 'Updating...';

  @override
  String updateAutoIn(int seconds) {
    return 'Auto update in $seconds sec';
  }

  @override
  String get updateNowBtn => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkip => 'Skip';

  @override
  String get updateBtn => 'Update';

  @override
  String get storageWarningTitle => 'Low disk space';

  @override
  String get storageWarningMsg =>
      'Free at least 2 GB for stable POS operation.';

  @override
  String get storageUnderstood => 'Got it';

  @override
  String get errorCritical => 'Critical error';

  @override
  String get errorAppProblem => 'App encountered a problem';

  @override
  String get errorDescription => 'Error description:';

  @override
  String get errorTechnical => 'Technical details';

  @override
  String get errorRetry => 'Retry';

  @override
  String get errorOpenFolder => 'Open folder';

  @override
  String get errorOtherVersion => 'Other version';

  @override
  String get errorExit => 'Exit';

  @override
  String get switchOn => 'On';

  @override
  String get switchOff => 'Off';

  @override
  String get keyboardSpace => 'Space';

  @override
  String get keyboardHide => 'Hide keyboard';

  @override
  String get keyboardShow => 'Show keyboard';

  @override
  String get commentReceipt => 'Receipt comment';

  @override
  String get commentReceiptHint => 'Enter comment...';

  @override
  String get productNameLabel => 'Product name';

  @override
  String get productNameHint => 'Enter name...';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get datePlaceholder => 'DD.MM.YYYY';

  @override
  String get timePlaceholder => 'HH:MM';

  @override
  String get dateTimePlaceholder => 'DD.MM.YYYY HH:MM';

  @override
  String get selectPeriod => 'Select period';

  @override
  String get bonusProgram => 'Bonus program';

  @override
  String get enterPhone => 'Enter client phone number';

  @override
  String get enterSmsCode => 'Enter SMS code';

  @override
  String resendIn(int seconds) {
    return 'Resend in $seconds sec';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String get availableBonuses => 'Available bonuses:';

  @override
  String get useBonuses => 'Use bonuses';

  @override
  String get deferredSales => 'Held sales';

  @override
  String get noDeferredSales => 'No held sales';

  @override
  String get fiscalErrors => 'Fiscal errors';

  @override
  String get selectAllErrors => 'Select all';

  @override
  String get retrySelected => 'Retry';

  @override
  String receiptNo(String number) {
    return 'Receipt #$number';
  }

  @override
  String get dontAskAgain => 'Don\'t ask again';

  @override
  String get deleteTitle => 'Delete';

  @override
  String deleteItemConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get exitTitle => 'Exit';

  @override
  String get exitConfirm => 'Are you sure you want to exit?';

  @override
  String get exitBtn => 'Exit';

  @override
  String get valueCannotBeNegative => 'Value cannot be negative';

  @override
  String maxPercent(int percent) {
    return 'Maximum $percent%';
  }

  @override
  String maxAmount(String amount) {
    return 'Maximum $amount';
  }

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String get discountAmount => 'Discount amount:';

  @override
  String get sumLabel => 'Amount';

  @override
  String get enterAmount => 'Enter amount';

  @override
  String get amountMustBePositive => 'Amount must be positive';

  @override
  String get notEnoughCashInDrawer => 'Not enough cash in drawer';

  @override
  String get enterValidAmount => 'Enter a valid amount';

  @override
  String get inDrawer => 'In drawer:';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get operationReason => 'Reason for operation...';

  @override
  String get positions => 'items';

  @override
  String get enterWeight => 'Enter weight';

  @override
  String get weightMustBePositive => 'Weight must be positive';

  @override
  String maxWeightValue(String max, String unit) {
    return 'Maximum $max $unit';
  }

  @override
  String get unitPcs => 'pcs';

  @override
  String get unitKg => 'kg';

  @override
  String lowStorageTooltip(String gb) {
    return 'Low storage: $gb GB';
  }

  @override
  String storageFree(String gb) {
    return 'Free: $gb GB';
  }

  @override
  String get storageRecommendation =>
      'For stable operation, it is recommended to have at least 2 GB of free space.\n\nPlease free up disk space or contact administrator.';

  @override
  String lowStorageBanner(String gb) {
    return 'Low free space: $gb GB. Recommended to free at least 2 GB for stable operation.';
  }

  @override
  String lowStorageTooltipShort(String gb) {
    return 'Low disk space: $gb GB';
  }

  @override
  String get cashier => 'Cashier:';

  @override
  String get buyer => 'Customer:';

  @override
  String receiptHeader(int number) {
    return 'RECEIPT #$number';
  }

  @override
  String get receiptDiscountItem => 'Discount:';

  @override
  String get receiptSubtotalLabel => 'Subtotal';

  @override
  String get receiptPayment => 'Payment:';

  @override
  String get fiscalMark => 'FP:';

  @override
  String remainingStock(String qty) {
    return 'Stock: $qty';
  }

  @override
  String get tableHeaderName => 'Name';

  @override
  String get tableHeaderPrice => 'Price';

  @override
  String get tableHeaderQty => 'Qty';

  @override
  String get tableHeaderTotal => 'Total';

  @override
  String get emptyReceipt => 'Receipt is empty';

  @override
  String get addProductsViaSearch =>
      'Add products via search\nor scan a barcode';

  @override
  String get addProductsViaSearchShort => 'Add products via search';

  @override
  String get priceLabel => 'Price';

  @override
  String get receiptTotalLabel => 'Receipt total';

  @override
  String get positionsLabel => 'Items';

  @override
  String get toPayLabel => 'TO PAY';

  @override
  String get payBtn => 'PAY';

  @override
  String get totalLabel => 'Total:';

  @override
  String posAndQty(int positions, String qty) {
    return '$positions items / $qty pcs';
  }

  @override
  String get modeRetail => 'Retail';

  @override
  String get modeWholesale => 'WHOLESALE';

  @override
  String get quickProducts => 'Quick products';

  @override
  String get editProduct => 'Edit';

  @override
  String get labelComment => 'Comment';

  @override
  String get selectPackage => 'Select package';

  @override
  String packageQty(String qty) {
    return '$qty pcs';
  }

  @override
  String get allBreadcrumb => 'All';

  @override
  String productPrice(String price) {
    return '$price ₸';
  }

  @override
  String maxBonusPercent(int percent) {
    return 'Can use up to $percent% of receipt total';
  }

  @override
  String get insufficientBonuses => 'Insufficient bonuses';

  @override
  String get enterValidPhone => 'Enter a valid phone number';

  @override
  String errorsCount(int count) {
    return '$count errors';
  }

  @override
  String selectAllCount(int count) {
    return 'Select all ($count)';
  }

  @override
  String retryCount(int count) {
    return 'Retry ($count)';
  }

  @override
  String receiptHash(int number) {
    return 'Receipt #$number';
  }

  @override
  String get enterIntegerNumber => 'Enter an integer';

  @override
  String enterDigits(int length) {
    return 'Enter $length digits';
  }

  @override
  String get drawerPrimary => 'Main';

  @override
  String get drawerSecondary => 'Additional';

  @override
  String get tooltipMore => 'More';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusSyncing => 'Sync...';

  @override
  String get thankYouForPurchase => 'Thank you for your purchase!';

  @override
  String get searchProductHint => 'Search product (name or barcode)';

  @override
  String get actionDefer => 'Defer';

  @override
  String get actionDeferredList => 'Deferred';

  @override
  String get actionMark => 'Marking';

  @override
  String get actionWeigh => 'Scales';

  @override
  String get actionPrintLabel => 'Price tag';

  @override
  String get supplierRepayTitle => 'Repay supplier debt';

  @override
  String supplierRepayCurrentDebt(String amount) {
    return 'Current debt: $amount';
  }

  @override
  String get supplierRepayNoDebt => 'No debt to the supplier';

  @override
  String get supplierRepayAmountLabel => 'Payment amount';

  @override
  String get supplierRepayAmountError => 'Enter an amount greater than 0';

  @override
  String get supplierRepaySubmit => 'Pay supplier';

  @override
  String get supplierRepayDone => 'Supplier payment recorded';

  @override
  String get supplierRepayError => 'Failed to record the payment';

  @override
  String get actionIncrease => 'Increase';

  @override
  String get actionDecrease => 'Decrease';

  @override
  String get restaurantSettings => 'Restaurant Mode';

  @override
  String get restaurantSettingsDesc => 'Tables, zones, service charge';

  @override
  String get restaurantOperatingMode => 'Operating Mode';

  @override
  String get restaurantModeRetail => 'Retail';

  @override
  String get restaurantModeRetailDesc => 'Standard POS for stores';

  @override
  String get restaurantModeRestaurant => 'Restaurant';

  @override
  String get restaurantModeRestaurantDesc => 'Tables, orders, service charge';

  @override
  String get restaurantModeService => 'Service';

  @override
  String get restaurantModeServiceDesc => 'Service intake, queue';

  @override
  String get restaurantZoneManagement => 'Zone Management';

  @override
  String get restaurantZoneAdd => 'Add Zone';

  @override
  String get restaurantZoneRename => 'Rename';

  @override
  String get restaurantZonePresets => 'Presets';

  @override
  String get restaurantZoneHall => 'Hall';

  @override
  String get restaurantZoneTerrace => 'Terrace';

  @override
  String get restaurantZoneVip => 'VIP';

  @override
  String get restaurantZoneBar => 'Bar';

  @override
  String get restaurantZoneBooth => 'Booth';

  @override
  String get restaurantZoneKaraoke => 'Karaoke';

  @override
  String get restaurantZoneVeranda => 'Veranda';

  @override
  String get restaurantZonePrivate => 'Private Room';

  @override
  String get restaurantTableManagement => 'Table Management';

  @override
  String get restaurantTableAdd => 'Add Table';

  @override
  String get restaurantTableEdit => 'Edit Table';

  @override
  String get restaurantTableName => 'Table Name';

  @override
  String get restaurantTableCapacity => 'Capacity';

  @override
  String get restaurantTableZone => 'Zone';

  @override
  String get restaurantTableSortOrder => 'Sort Order';

  @override
  String get restaurantTableDeactivate => 'Deactivate Table';

  @override
  String restaurantTableDeactivateConfirm(String name) {
    return 'Deactivate table \"$name\"?';
  }

  @override
  String get restaurantServiceCharge => 'Service Charge';

  @override
  String get restaurantServiceChargeEnabled => 'Enable Service Charge';

  @override
  String get restaurantServiceChargePercent => 'Service Charge Percent';

  @override
  String get restaurantTableFree => 'Free';

  @override
  String get restaurantTableOccupied => 'Occupied';

  @override
  String get restaurantTableReserved => 'Reserved';

  @override
  String get restaurantTableDirty => 'Dirty';

  @override
  String get restaurantOrderDineIn => 'Dine In';

  @override
  String get restaurantOrderTakeout => 'Takeout';

  @override
  String get restaurantOrderDelivery => 'Delivery';

  @override
  String get restaurantAllZones => 'All Zones';

  @override
  String get restaurantNoTables => 'No Tables';

  @override
  String get restaurantNoTablesHint => 'Add tables in restaurant settings';

  @override
  String get restaurantGoToSettings => 'Go to Settings';

  @override
  String get restaurantOrdersEmpty => 'No active orders';

  @override
  String restaurantOrderItems(int count) {
    return '$count items';
  }

  @override
  String restaurantOrderGuests(int count) {
    return 'Guests: $count';
  }

  @override
  String restaurantOrderWaiter(String name) {
    return 'Waiter: $name';
  }

  @override
  String restaurantOrderElapsed(int minutes) {
    return '$minutes min';
  }

  @override
  String get restaurantNoOrder => 'No active order';

  @override
  String get restaurantOpenOrder => 'Open Order';

  @override
  String get restaurantCloseOrder => 'Close Order';

  @override
  String get restaurantAddItems => 'Add Items';

  @override
  String get restaurantGoToPayment => 'To Payment';

  @override
  String get restaurantTransfer => 'Transfer';

  @override
  String get restaurantSplitBill => 'Split Bill';

  @override
  String get restaurantChangeStatus => 'Change Status';

  @override
  String get restaurantSetFree => 'Free';

  @override
  String get restaurantSetReserved => 'Reserve';

  @override
  String get restaurantSetDirty => 'Needs Cleaning';

  @override
  String get restaurantCreateOrder => 'New Order';

  @override
  String get restaurantPartySize => 'Party Size';

  @override
  String get restaurantOrderType => 'Order Type';

  @override
  String get restaurantWaiter => 'Waiter';

  @override
  String get restaurantNote => 'Note';

  @override
  String get restaurantDeliveryAddress => 'Delivery Address';

  @override
  String get restaurantDeliveryPhone => 'Phone';

  @override
  String get restaurantTransferTitle => 'Transfer Order';

  @override
  String restaurantTransferCurrent(String table) {
    return 'Current: $table';
  }

  @override
  String get restaurantTransferSelectFree => 'Select a free table:';

  @override
  String get restaurantMergeTitle => 'Merge tables';

  @override
  String restaurantMergeTarget(String table) {
    return 'Into table: $table';
  }

  @override
  String get restaurantMergeSelectSources => 'Select tables to merge in:';

  @override
  String get restaurantMergeNoOpenTables => 'No other occupied tables';

  @override
  String restaurantMergeConfirm(int count) {
    return 'Merge ($count)';
  }

  @override
  String get restaurantMergeDone => 'Tables merged';

  @override
  String get restaurantMergeNeedTarget => 'The current table has no open order';

  @override
  String get restaurantSplitTitle => 'Split Bill';

  @override
  String get restaurantSplitEvenly => 'Evenly';

  @override
  String get restaurantSplitByItems => 'By Items';

  @override
  String get restaurantSplitGuestCount => 'Number of Guests';

  @override
  String restaurantSplitPerGuest(String amount) {
    return 'Per guest: $amount';
  }

  @override
  String restaurantSplitGuest(int number) {
    return 'Guest $number';
  }

  @override
  String get restaurantSplitApply => 'Apply';

  @override
  String get restaurantSplitPaymentTitle => 'Split payment by guest';

  @override
  String get restaurantSplitPaymentProceed => 'To payment';

  @override
  String get restaurantPreCheckPrinted => 'Pre-check sent to printer';

  @override
  String get restaurantPreCheckFailed => 'Pre-check print failed';

  @override
  String get restaurantSubtotal => 'Subtotal';

  @override
  String restaurantServiceChargeLine(String percent) {
    return 'Service charge ($percent%)';
  }

  @override
  String restaurantOrderNumber(int number) {
    return 'Order #$number';
  }

  @override
  String restaurantTakeoutNumber(int number) {
    return 'Takeout #$number';
  }

  @override
  String restaurantDeliveryNumber(int number) {
    return 'Delivery #$number';
  }

  @override
  String get restaurantSaved => 'Restaurant settings saved';

  @override
  String get restaurantQuickActions => 'Quick Actions';

  @override
  String get restaurantNoItems => 'No items';

  @override
  String restaurantTableSeats(int count) {
    return '$count seats';
  }

  @override
  String get restaurantOrderTab => 'Order';

  @override
  String get restaurantMenuTab => 'Menu';

  @override
  String restaurantGuestLabel(int number) {
    return 'Guest $number';
  }

  @override
  String get restaurantRemoveItem => 'Remove item';

  @override
  String get restaurantPrintPrecheck => 'Pre-check';

  @override
  String get restaurantNewTakeout => 'Takeout';

  @override
  String get restaurantNewDelivery => 'Delivery';

  @override
  String get setupSectionOrganization => 'Company';

  @override
  String get setupSectionContact => 'Contact person';

  @override
  String get setupSectionAddress => 'Addresses';

  @override
  String get setupSectionCashBox => 'Till';

  @override
  String get setupSectionUsers => 'Who will be working';

  @override
  String get setupSectionSecurity => 'PIN sign-in';

  @override
  String get setupSectionScanner => 'Scanner';

  @override
  String get setupSectionScale => 'Scales';

  @override
  String get setupSectionDisplay => 'Customer display';

  @override
  String get setupSectionTerminal => 'Payment terminal';

  @override
  String get setupSectionCashback => 'Cash withdrawal';

  @override
  String get setupTaxIdExplanation =>
      'The tax number is printed on every receipt and sent to the fiscal service. A mistake here surfaces only at the first reconciliation with the tax authority — after the receipts have been handed out.';

  @override
  String get setupFiscalCredentialsExplanation =>
      'These credentials come from the fiscal operator. While they are wrong, receipts still print as usual but never reach the fiscal service — the gap shows up at reconciliation, not at the sale.';

  @override
  String get setupKktNumberExplanation =>
      'The register number ties this till to its registration with the operator. A mistake here files receipts under someone else’s till, and the till itself gives no sign of it.';

  @override
  String setupStepProgress(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get setupStepChecking => 'Checking';

  @override
  String get setupStepTelegram => 'Telegram';

  @override
  String get setupStepCountry => 'Country';

  @override
  String get setupStepOrganization => 'Organization';

  @override
  String get setupStepVat => 'VAT';

  @override
  String get setupStepUsers => 'Users';

  @override
  String get setupStepWorkMode => 'Work Mode';

  @override
  String get setupStepPos => 'POS';

  @override
  String get setupStepFiscal => 'Fiscalization';

  @override
  String get setupStepEquipment => 'Equipment';

  @override
  String get setupStepTerminals => 'Terminals';

  @override
  String get setupStepOperatingMode => 'Business Type';

  @override
  String get setupStepBusinessRules => 'Rules';

  @override
  String get setupStepSummary => 'Review';

  @override
  String get setupStepComplete => 'Done';

  @override
  String get setupCheckingSettings => 'Checking settings...';

  @override
  String get setupStateUnreadableTitle => 'The till did not answer';

  @override
  String get setupStateUnreadableBody =>
      'Setup will not start until the till’s state can be read — otherwise it could overwrite a shop that is already working. Check that the till is running and reachable over the network.';

  @override
  String get wtUnavailableTitle => 'No connection to the till';

  @override
  String get wtUnavailableBody =>
      'The terminal gets its data over WebTransport only. There is no fallback: with no session there is nothing to show, and showing stale data as fresh is worse than showing nothing. Check that the till is running, then retry.';

  @override
  String wtUnavailableReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get terminalHomeWhoHeader => 'Who is signed in';

  @override
  String get terminalHomeUserLabel => 'Cashier';

  @override
  String get terminalHomeSaleNote =>
      'Selling in the browser is separate work: the sale screen reads the till\'s database directly and does not build for the browser yet.';

  @override
  String get wtNotPortedTitle => 'This screen is on the till only for now';

  @override
  String get wtNotPortedBody =>
      'The browser terminal gets its data over the wire, and a screen appears here once every one of its contracts can work over that wire. This one cannot yet. Showing it empty would be worse than saying so.';

  @override
  String wtNotPortedLocation(String location) {
    return 'Route: $location';
  }

  @override
  String get setupWelcomeTitle => 'Welcome to TelePOS!';

  @override
  String get setupCountryDescription =>
      'Select your country for currency and tax setup';

  @override
  String setupPriceExample(String amount) {
    return 'Example: $amount';
  }

  @override
  String setupVatRateLabel(int rate) {
    return 'VAT: $rate%';
  }

  @override
  String get setupOrganizationTitle => 'Organization Data';

  @override
  String get setupOrganizationDescription => 'Enter your company information';

  @override
  String get setupCompanyNameLabel => 'Company name';

  @override
  String get setupCompanyNameHint => 'LLC \"My Company\"';

  @override
  String setupTaxIdDigits(int length) {
    return '$length digits';
  }

  @override
  String get setupLegalAddressLabel => 'Legal address';

  @override
  String get setupActualAddressLabel => 'Store address';

  @override
  String get setupOwnerNameLabel => 'Director\'s full name';

  @override
  String get setupPhoneLabel => 'Phone';

  @override
  String get setupVatTitle => 'Value Added Tax';

  @override
  String get setupVatDescription => 'Select your organization\'s tax regime';

  @override
  String get setupVatPayerTitle => 'VAT Payer';

  @override
  String setupVatPayerRate(int rate) {
    return 'VAT rate: $rate%';
  }

  @override
  String get setupVatPayerRateUnknown => 'VAT rate depends on country';

  @override
  String get setupVatPayerDescription =>
      'VAT will be shown on receipts.\nRequired for companies on general taxation.';

  @override
  String get setupVatNonPayerTitle => 'No VAT';

  @override
  String get setupVatNonPayerSubtitle => 'VAT not applicable';

  @override
  String get setupVatNonPayerDescription =>
      'VAT will not be shown on receipts.\nFor individual entrepreneurs on simplified system.';

  @override
  String get setupWorkModeTitle => 'Work Mode';

  @override
  String get setupWorkModeDescription => 'Choose how your POS will operate';

  @override
  String get setupAutonomousTitle => 'Autonomous Mode';

  @override
  String get setupAutonomousSubtitle => 'Work without internet';

  @override
  String get setupAutonomousDescription =>
      'POS works completely offline.\nData stored locally only.\nNo sync between registers.';

  @override
  String get setupNetworkTitle => 'Network Mode';

  @override
  String get setupNetworkConfigured => 'Telegram configured';

  @override
  String get setupNetworkRequired => 'Telegram required';

  @override
  String get setupNetworkDescription =>
      'Data sync between registers.\nCloud backup.\nReports and notifications via Telegram.';

  @override
  String get setupNetworkRequiresTelegram =>
      'Telegram setup is required for network mode';

  @override
  String get setupOperatingModeTitle => 'Business Type';

  @override
  String get setupOperatingModeDescription => 'Select your business type';

  @override
  String get setupRetailTitle => 'Retail POS';

  @override
  String get setupRetailSubtitle => 'Shop, pharmacy, supermarket';

  @override
  String get setupRetailDescription =>
      'Standard POS for retail.\nSales, refunds, supply receipt.\nShifts and reporting.';

  @override
  String get setupRestaurantTitle => 'Restaurant / Cafe';

  @override
  String get setupRestaurantSubtitle => 'Tables, orders, delivery';

  @override
  String get setupRestaurantDescription =>
      'Table and hall management.\nTakeout and delivery.\nBill splitting and service charge.';

  @override
  String get setupServiceTitle => 'Service Center';

  @override
  String get setupServiceSubtitle => 'Repair, services, procedures';

  @override
  String get setupServiceDescription =>
      'Service intake.\nWork orders and task tracking.\nStatus tracking and release.';

  @override
  String get setupPosConfigTitle => 'POS Setup';

  @override
  String get setupPosConfigDescription => 'Set POS parameters';

  @override
  String get setupCashBoxNameLabel => 'POS name';

  @override
  String get setupCashBoxNameHint => 'POS 1';

  @override
  String get setupPosIdLabel => 'POS ID';

  @override
  String get setupPrinterConfigTitle => 'Receipt Printer';

  @override
  String get setupPaperWidthLabel => 'Paper width';

  @override
  String get setupPaperWidth58 => '58 mm (32 chars)';

  @override
  String get setupPaperWidth80 => '80 mm (48 chars)';

  @override
  String get setupPrinterHeaderLabel => 'Receipt header';

  @override
  String get setupPrinterHeaderHint => 'Store name\nAddress';

  @override
  String get setupPrinterFooterLabel => 'Receipt footer';

  @override
  String get setupPrinterFooterHint => 'Thank you for your purchase!';

  @override
  String get setupFiscalNotRequired =>
      'Fiscalization is not required for your country';

  @override
  String get setupFiscalDescription => 'Set up fiscal operator connection';

  @override
  String get setupEnableWebkassa => 'Enable WebKassa';

  @override
  String get setupEnableOfd => 'Enable OFD';

  @override
  String get setupWebkassaDescription =>
      'Receipt fiscalization via WebKassa (Kazakhstan)';

  @override
  String get setupOfdDescription => 'Receipt fiscalization via OFD (Russia)';

  @override
  String get setupSkipLater => 'Skip (configure later)';

  @override
  String get setupWebkassaAccountTitle => 'WebKassa Account';

  @override
  String get setupWebkassaAccountIdLabel => 'Account ID';

  @override
  String get setupWebkassaAccountIdHint => 'Your WebKassa ID';

  @override
  String get setupWebkassaTokenLabel => 'Account token';

  @override
  String get setupWebkassaTokenHint => 'API token';

  @override
  String get setupWebkassaPosTitle => 'WebKassa POS';

  @override
  String get setupWebkassaPosIdLabel => 'POS ID';

  @override
  String get setupWebkassaPosIdHint => 'POS ID in WebKassa';

  @override
  String get setupWebkassaPosTokenLabel => 'POS token';

  @override
  String get setupWebkassaPosTokenHint => 'POS token';

  @override
  String get setupWebkassaFactoryNoLabel => 'Cash register serial number';

  @override
  String get setupOfdParamsTitle => 'OFD Parameters';

  @override
  String get setupOfdInnLabel => 'Organization INN';

  @override
  String get setupOfdKktRegNoLabel => 'KKT reg. number';

  @override
  String get setupOfdFnNoLabel => 'FN number';

  @override
  String get setupOfdUrlLabel => 'OFD URL';

  @override
  String get setupEquipmentTitle => 'Equipment';

  @override
  String get setupEquipmentDescription => 'Configure connected equipment';

  @override
  String get setupEquipmentPrinter => 'Receipt Printer';

  @override
  String get setupEquipmentScanner => 'Barcode Scanner';

  @override
  String get setupEquipmentScales => 'Scales';

  @override
  String get setupEquipmentCashDrawer => 'Cash Drawer';

  @override
  String get setupEquipmentDisplay => 'Customer Display';

  @override
  String get setupConnectionTypeLabel => 'Connection type';

  @override
  String get setupConnectionUsb => 'USB';

  @override
  String get setupConnectionBluetooth => 'Bluetooth';

  @override
  String get setupConnectionWifi => 'Wi-Fi / Ethernet';

  @override
  String get setupConnectionSerial => 'COM port';

  @override
  String get setupConnectionNone => 'Not selected';

  @override
  String get setupPrinterIpLabel => 'Printer IP address';

  @override
  String get setupPrinterMacLabel => 'Printer MAC address';

  @override
  String get setupPrinterNameLabel => 'Printer name';

  @override
  String get setupPrinterNameHint => 'Kitchen printer';

  @override
  String get setupScannerTypeLabel => 'Scanner type';

  @override
  String get setupScannerCamera => 'Device camera';

  @override
  String get setupScannerUsb => 'USB scanner';

  @override
  String get setupScannerBluetooth => 'Bluetooth scanner';

  @override
  String get setupScalePortLabel => 'COM port';

  @override
  String get setupBaudRateLabel => 'Baud rate';

  @override
  String get setupCashDrawerConnected => 'Connected to printer';

  @override
  String get setupCashDrawerConnectedDesc => 'Opens via printer command';

  @override
  String get setupSkip => 'Skip';

  @override
  String get setupPaymentTerminalsTitle => 'Payment Terminals';

  @override
  String get setupPaymentTerminalsDescription =>
      'Configure payment system integrations';

  @override
  String get setupKaspiIpLabel => 'Terminal IP address';

  @override
  String get setupPortLabel => 'Port';

  @override
  String get setupApiUrlLabel => 'API URL';

  @override
  String get setupApiKeyLabel => 'API key';

  @override
  String get setupNoTerminalsAvailable =>
      'No payment terminals available for your region';

  @override
  String get setupBusinessRulesTitle => 'Business Rules';

  @override
  String get setupBusinessRulesDescription => 'Configure POS rules';

  @override
  String get setupPermissionsTitle => 'Permissions';

  @override
  String get setupAllowDiscounts => 'Discounts';

  @override
  String get setupAllowDiscountsDesc => 'Allow applying discounts';

  @override
  String get setupAllowDebtSales => 'Debt sales';

  @override
  String get setupAllowDebtSalesDesc => 'Allow credit sales';

  @override
  String get setupAllowPriceEdit => 'Price editing';

  @override
  String get setupAllowPriceEditDesc => 'Allow price changes during sale';

  @override
  String get setupAllowCashInOut => 'Cash operations';

  @override
  String get setupAllowCashInOutDesc => 'Cash deposits and withdrawals';

  @override
  String get setupBlockPriceDecrease => 'Block price decrease';

  @override
  String get setupBlockPriceDecreaseDesc => 'Prevent selling below set price';

  @override
  String get setupLimitsTitle => 'Limits';

  @override
  String get setupAllowBigAmount => 'Large amounts';

  @override
  String get setupAllowBigAmountDesc => 'Allow operations > 1,000,000';

  @override
  String get setupCashWithdrawalLimitLabel => 'Cash withdrawal limit';

  @override
  String get setupCashWithdrawalLimitHelper => 'Leave empty for no limit';

  @override
  String get setupLoyaltyTitle => 'Loyalty Program';

  @override
  String get setupCashbackLabel => 'Cashback';

  @override
  String get setupCashbackDesc => 'Enable bonus accrual';

  @override
  String get setupCashbackRateLabel => 'Cashback rate';

  @override
  String get setupRoundingTitle => 'Rounding';

  @override
  String get setupDiscountRounding => 'Discount rounding';

  @override
  String get setupWeightRounding => 'Weight product rounding';

  @override
  String get setupRoundingNone => 'No rounding';

  @override
  String get setupRoundingUp1 => 'To 1 (up)';

  @override
  String get setupRoundingDown1 => 'To 1 (down)';

  @override
  String get setupRoundingUp5 => 'To 5 (up)';

  @override
  String get setupRoundingDown5 => 'To 5 (down)';

  @override
  String get setupRoundingUp10 => 'To 10 (up)';

  @override
  String get setupRoundingDown10 => 'To 10 (down)';

  @override
  String get setupFiscalDisablesRounding =>
      'Rounding is automatically disabled when fiscalization is enabled';

  @override
  String get setupUserCreationTitle => 'Create Users';

  @override
  String get setupUserCreationDescription => 'Create users for POS operation';

  @override
  String get setupAdminLabel => 'ADMINISTRATOR';

  @override
  String get setupAdminSubtitle => 'POS owner';

  @override
  String get setupUserNameLabel => 'Name';

  @override
  String get setupUserPinLabel => 'PIN';

  @override
  String get setupUserPinConfirmLabel => 'Confirmation';

  @override
  String get setupAdminPinDefault => 'Default: 0000';

  @override
  String get setupSellerLabel => 'SELLER';

  @override
  String get setupSellerOptional => 'Optional';

  @override
  String get setupSellerPinDefault => 'Default: 1111';

  @override
  String get setupAdminPinMismatch => 'Administrator PINs do not match';

  @override
  String get setupSummaryTitle => 'Review Data';

  @override
  String get setupSummaryDescription => 'Make sure everything is correct';

  @override
  String get setupSummaryCountry => 'Country';

  @override
  String get setupSummaryCurrency => 'Currency';

  @override
  String get setupSummaryFormat => 'Format';

  @override
  String get setupSummaryVat => 'VAT';

  @override
  String get setupSummaryTelegram => 'Telegram';

  @override
  String get setupSummaryStatus => 'Status';

  @override
  String get setupConfigured => 'Configured';

  @override
  String get setupNotConfigured => 'Not configured';

  @override
  String get setupSummaryOrganization => 'Organization';

  @override
  String get setupSummaryName => 'Name';

  @override
  String get setupSummaryAddress => 'Address';

  @override
  String get setupSummaryWorkMode => 'Work Mode';

  @override
  String get setupSummaryMode => 'Mode';

  @override
  String get setupSummaryAutonomous => 'Autonomous (no network)';

  @override
  String get setupSummaryNetwork => 'Network (sync)';

  @override
  String get setupSummaryPos => 'POS';

  @override
  String get setupSummaryId => 'ID';

  @override
  String get setupEnabled => 'Enabled';

  @override
  String get setupDisabled => 'Disabled';

  @override
  String get setupSummaryFiscalType => 'Type';

  @override
  String get setupSummaryEquipment => 'Equipment';

  @override
  String get setupSummaryPrinter => 'Printer';

  @override
  String get setupSummaryScanner => 'Scanner';

  @override
  String get setupSummaryScales => 'Scales';

  @override
  String get setupSummaryCashDrawer => 'Cash drawer';

  @override
  String get setupSummaryTerminals => 'Payment Terminals';

  @override
  String get setupSummaryRules => 'Business Rules';

  @override
  String get setupSummaryDiscounts => 'Discounts';

  @override
  String get setupSummaryDebtSales => 'Debt';

  @override
  String get setupSummaryCashback => 'Cashback';

  @override
  String get setupSummaryBigAmount => 'Large amounts';

  @override
  String get setupSummaryUsers => 'Users';

  @override
  String get setupSummaryAdmin => 'Administrator';

  @override
  String get setupSummarySeller => 'Seller';

  @override
  String get setupCompleteTitle => 'Setup Complete!';

  @override
  String get setupCompleteSubtitle => 'POS is ready to work';

  @override
  String get setupStartWork => 'Start Working';

  @override
  String setupVatPayerSummary(int rate) {
    return 'VAT Payer ($rate%)';
  }

  @override
  String get setupSummaryWkPosId => 'WK POS ID';

  @override
  String get setupSummaryOfdInn => 'INN';

  @override
  String get setupScalesConfigured => 'Configured';

  @override
  String get setupScalesNotConfigured => 'Not configured';

  @override
  String get setupCashDrawerOn => 'Enabled';

  @override
  String get setupAllowed => 'Allowed';

  @override
  String get setupDenied => 'Denied';

  @override
  String get setupAllowedFem => 'Allowed';

  @override
  String get setupDeniedFem => 'Denied';

  @override
  String get setupCashbackOff => 'Disabled';

  @override
  String get setupBigAmountLimit => 'Limit 100,000';

  @override
  String get setupDisplayPortLabel => 'COM port';

  @override
  String get telegramAuthSkip => 'Skip (configure later)';

  @override
  String get telegramInitializing => 'Initializing';

  @override
  String get telegramErrorTdlib => 'TDLib Error';

  @override
  String get telegramAuthLogin => 'Telegram Login';

  @override
  String get telegramAuthCodeStep => 'Verification code';

  @override
  String get telegramAuth2fa => 'Two-factor authentication';

  @override
  String get telegramRegister => 'Registration';

  @override
  String get telegramSearchingChannels => 'Searching channels';

  @override
  String get telegramLoadingData => 'Loading data';

  @override
  String get telegramOrgData => 'Organization data';

  @override
  String get telegramSetupChannels => 'Setting up channels';

  @override
  String get telegramSetupEncryption => 'Setting up encryption';

  @override
  String get telegramSetupComplete => 'Done';

  @override
  String get telegramInitializingLong => 'Initializing Telegram...';

  @override
  String get telegramConnecting => 'Connecting to Telegram servers';

  @override
  String get telegramTdlibNotFound => 'TDLib not found';

  @override
  String get telegramTdlibErrorMessage =>
      'Native TDLib library not found.\nInstall tdjson to use Telegram.';

  @override
  String get telegramForWindows => 'For Windows:';

  @override
  String get telegramWindowsInstructions =>
      '1. Download TDLib: github.com/tdlib/td/releases\n2. Copy tdjson.dll to project root\n3. Or install to C:\\TDLib\\bin\\';

  @override
  String get telegramPhoneAuthTitle => 'Phone Number Login';

  @override
  String get telegramPhoneAuthDescription =>
      'Enter the phone number linked to your Telegram account';

  @override
  String get telegramCountryCodeLabel => 'Country code';

  @override
  String get telegramPhoneNumber => 'Phone number';

  @override
  String get telegramGetCode => 'Get Code';

  @override
  String get telegramRefreshQr => 'Refresh QR Code';

  @override
  String get telegramSignUp => 'Sign Up';

  @override
  String get telegramEnterStoreName => 'Enter store name';

  @override
  String get telegramInvalidBinIin => 'Enter valid BIN/IIN (12 digits)';

  @override
  String get telegramInvalidCode => 'Enter valid code';

  @override
  String get telegramEnterPassword => 'Enter password';

  @override
  String get telegramCodeResent => 'Code resent';

  @override
  String get telegramEnterName => 'Enter name';

  @override
  String get telegramManageAccount => 'Manage Account';

  @override
  String get telegramNotificationsSection => 'Notifications';

  @override
  String get telegramNotificationsDesc =>
      'Receive notifications about sales, shifts, etc.';

  @override
  String get telegramNotifySales => 'Sales notifications';

  @override
  String get telegramNotifySalesDesc => 'Large sales, refunds';

  @override
  String get telegramNotifyShifts => 'Shift notifications';

  @override
  String get telegramNotifyShiftsDesc => 'Shift opening and closing';

  @override
  String get telegramNotifyCritical => 'Critical notifications';

  @override
  String get telegramNotifyCriticalDesc => 'Errors, OFD issues';

  @override
  String get telegramNotifyStock => 'Stock notifications';

  @override
  String get telegramNotifyStockDesc => 'Product shortages';

  @override
  String get telegramSyncSettings => 'Sync Settings';

  @override
  String get telegramAutoSyncDesc => 'Automatically sync data';

  @override
  String get telegramSyncInterval1min => '1 minute';

  @override
  String get telegramSyncInterval5min => '5 minutes';

  @override
  String get telegramSyncInterval15min => '15 minutes';

  @override
  String get telegramSyncInterval30min => '30 minutes';

  @override
  String get telegramSyncInterval1hour => '1 hour';

  @override
  String get telegramSystemChannels => 'System Channels';

  @override
  String get telegramRefresh => 'Refresh';

  @override
  String get telegramChannelsNotConnected =>
      'Channels not connected.\nLog in to Telegram for automatic creation.';

  @override
  String telegramChannelsConnected(int connected, int total) {
    return '$connected of $total channels connected';
  }

  @override
  String telegramChannelsLoadError(String error) {
    return 'Error loading channels: $error';
  }

  @override
  String get telegramForceSyncDesc => 'Sync all data now';

  @override
  String get telegramFullSyncDesc => 'Reset and re-sync everything';

  @override
  String get telegramRecreateChannelsDesc => 'Recreate system channels';

  @override
  String get telegramLogoutDesc => 'Disconnect Telegram integration';

  @override
  String get telegramFullSyncWarning =>
      'This will reset all sync timestamps and reload all data. This may take a while.';

  @override
  String get telegramRecreateChannelsWarning =>
      'This will recreate all system channels. Existing channel data will be lost.';

  @override
  String get telegramLogoutWarning =>
      'Are you sure you want to log out? Sync and notifications will be disabled.';

  @override
  String get telegramChannelsRecreated => 'Channels recreated';

  @override
  String get telegramConnectedStatus => 'Connected';

  @override
  String get telegramNotConnected => 'Not connected';

  @override
  String get telegramAccountLabel => 'Telegram Account';

  @override
  String get telegramLoginForSync => 'Log in to sync data';

  @override
  String get channelDescSystemEvents => 'System events';

  @override
  String get channelDescSales => 'Sales feed';

  @override
  String get channelDescAlerts => 'Critical alerts';

  @override
  String get channelDescReports => 'Reports and summaries';

  @override
  String get channelDescSync => 'Data sync';

  @override
  String get channelDescFiscal => 'Fiscal events';

  @override
  String get channelDescStaffChat => 'Staff chat';

  @override
  String get channelDescDataExchange => 'Data exchange';

  @override
  String get channelDescTerminalStatus => 'Terminal status';

  @override
  String get channelDescBackup => 'Database backups';

  @override
  String get chatNoConnectionBanner =>
      'No connection. Messages will be sent when restored.';

  @override
  String get chatLinkTelegramForId => 'Link Telegram for chat identification';

  @override
  String chatSendError(String error) {
    return 'Send error: $error';
  }

  @override
  String chatFoundMessages(int count) {
    return 'Found $count messages';
  }

  @override
  String get chatNoResults => 'Nothing found';

  @override
  String get chatCopyUidInstructions => 'Copy UID for use in other systems';

  @override
  String get chatUidExample => 'Example: telepos@pos-1';

  @override
  String get chatServiceUnavailable => 'Service unavailable';

  @override
  String get chatTelegramLinked => 'Telegram linked successfully';

  @override
  String get additionalLogout => 'Logout';

  @override
  String get additionalLockCashier => 'Lock';

  @override
  String get additionalPrinterAction => 'Printer';

  @override
  String get additionalPrintLastReceipt => 'Last Receipt';

  @override
  String get additionalSyncAction => 'Sync';

  @override
  String get additionalCheckPrice => 'Price Check';

  @override
  String get additionalMinimize => 'Minimize';

  @override
  String get additionalCustomers => 'Customers';

  @override
  String get additionalUpdateAction => 'Update';

  @override
  String get additionalExtraPrinter => 'Extra Printer';

  @override
  String get additionalSupplyAction => 'Supply';

  @override
  String get additionalLanguageAction => 'Language';

  @override
  String get additionalKaspiPos => 'Kaspi POS';

  @override
  String get additionalPrinterEscPos => 'Thermal Printer ESC/POS';

  @override
  String get additionalPrinterNotConfigured => 'Printer not configured';

  @override
  String get additionalPrinterWifi => 'Wi-Fi Printer';

  @override
  String get additionalPrinterWifiDesc => 'Connect via IP';

  @override
  String get additionalPrinterBluetooth => 'Bluetooth Printer';

  @override
  String get additionalPrinterBluetoothDesc => 'Search devices';

  @override
  String get additionalPrinterUsb => 'USB Printer';

  @override
  String get additionalPrinterSystem => 'System Printer';

  @override
  String get additionalPrinterDisconnected => 'Printer disconnected';

  @override
  String get additionalPrinterIpLabel => 'IP';

  @override
  String get additionalPrinterEnterIp => 'Enter IP address';

  @override
  String additionalPrinterConnecting(String address) {
    return 'Connecting to $address...';
  }

  @override
  String get additionalPrinterConnectingUsb => 'Connecting USB printer...';

  @override
  String get additionalPrinterNotConnected => 'Printer not connected';

  @override
  String get additionalPrintingLastReceipt => 'Printing last receipt...';

  @override
  String get additionalTestReceiptTitle => '=== TEST RECEIPT ===';

  @override
  String get additionalReceiptPrinted => 'Receipt printed';

  @override
  String additionalPriceSearching(String query) {
    return 'Searching: $query';
  }

  @override
  String get additionalMinimizing => 'Minimizing window...';

  @override
  String get additionalLatestVersion => 'You have the latest version';

  @override
  String get additionalExtraPrinterTitle => 'Extra Printer';

  @override
  String get additionalExtraPrinterUsedFor => 'Extra printer is used for:';

  @override
  String get additionalExtraPrinterLabels => 'Label printing';

  @override
  String get additionalExtraPrinterKitchen => 'Kitchen printing';

  @override
  String get additionalExtraPrinterDuplicate => 'Receipt duplicate';

  @override
  String get additionalKaspiPosTitle => 'Kaspi POS';

  @override
  String get additionalKaspiPosDesc => 'Kaspi terminal for payment acceptance.';

  @override
  String get additionalKaspiPosNotConnected => 'Status: Not connected';

  @override
  String additionalPrinterConnectedName(String name) {
    return 'Printer connected: $name';
  }

  @override
  String additionalErrorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get additionalPrinterUsbNotSupported => 'USB printers not supported';

  @override
  String get additionalPrinterUsbConnected => 'USB printer connected';

  @override
  String get additionalBarcodeLabel => 'Barcode';

  @override
  String get additionalBarcodeHint => 'Scan or enter';

  @override
  String additionalTestReceiptProduct(String number) {
    return 'Product $number';
  }

  @override
  String get additionalTestReceiptTotal => 'TOTAL:';

  @override
  String get additionalTestReceiptThankYou => 'Thank you for your purchase!';

  @override
  String get langRussian => 'Русский';

  @override
  String get langEnglish => 'English';

  @override
  String get langKazakh => 'Қазақша';

  @override
  String get langKyrgyz => 'Кыргызча';

  @override
  String get langUzbek => 'O\'zbekcha';

  @override
  String get transportFullSyncWarning =>
      'This will reset all sync timestamps and reload all data. This may take a while. Continue?';

  @override
  String get transportSyncAbout => 'About sync';

  @override
  String transportSyncStateError(String error) {
    return 'Error loading sync state: $error';
  }

  @override
  String get transportSyncInfoDialog =>
      'Each data type is synced independently. Only items modified after the last sync are transferred.\n\nInterval: 5 minutes (default)\nData is encrypted with AES-256-GCM before transfer.';

  @override
  String get transportSyncNever => 'Never';

  @override
  String get transportModeDescription =>
      'Select how the app communicates with the server';

  @override
  String get transportModeRest => 'REST API';

  @override
  String get transportModeRestDesc => 'Traditional HTTP/WebSocket connection';

  @override
  String get transportModeTelegram => 'Telegram';

  @override
  String get transportModeTelegramDesc => 'Uses Telegram as transport layer';

  @override
  String get transportModeHybrid => 'Hybrid';

  @override
  String get transportModeHybridDesc => 'Telegram primary, REST as fallback';

  @override
  String get transportModeRecommended => 'Recommended';

  @override
  String transportSyncIntervalMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get transportSyncOnConnectivity => 'Sync when network is restored';

  @override
  String transportSyncIntervalOption(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return '$_temp0';
  }

  @override
  String get transportEnableQueue => 'Operation Queue';

  @override
  String get transportEnableQueueDesc => 'Buffer operations when offline';

  @override
  String get transportMaxQueueSize => 'Max Queue Size';

  @override
  String transportQueueSizeStatus(int size) {
    return '$size operations';
  }

  @override
  String get transportAutoCleanup => 'Auto Cleanup';

  @override
  String get transportAutoCleanupDesc =>
      'Remove completed operations after 7 days';

  @override
  String get transportNotifyChanges => 'Transport Changes';

  @override
  String get transportNotifyChangesDesc => 'Notify when transport mode changes';

  @override
  String get transportNotifySyncErrors => 'Sync Errors';

  @override
  String get transportNotifySyncErrorsDesc =>
      'Notify on synchronization failures';

  @override
  String get transportNotifyOfflineOnline => 'Connectivity';

  @override
  String get transportNotifyConnectivityDesc =>
      'Notify on connectivity changes';

  @override
  String get transportNotifyQueueFull => 'Queue Full';

  @override
  String get transportNotifyQueueFullDesc => 'Notify when queue reaches limit';

  @override
  String saleErrorInitiation(String error) {
    return 'Sale initiation error: $error';
  }

  @override
  String get saleErrorNotInitialized => 'Sale not initialized';

  @override
  String get saleErrorEmpty => 'Receipt is empty';

  @override
  String saleErrorCompletion(String error) {
    return 'Sale completion error: $error';
  }

  @override
  String saleErrorSearch(String error) {
    return 'Search error: $error';
  }

  @override
  String saleErrorDeferred(String error) {
    return 'Defer error: $error';
  }

  @override
  String get saleErrorDeferredNotFound => 'Deferred receipt not found';

  @override
  String saleErrorLoadingDeferred(String error) {
    return 'Error loading deferred receipt: $error';
  }

  @override
  String get paymentCustomerDefault => 'Customer';

  @override
  String get paymentErrorFormation =>
      'Could not form payment. Check account settings.';

  @override
  String get paymentErrorSaving => 'Error saving sale';

  @override
  String paymentErrorProcessing(String error) {
    return 'Payment processing error: $error';
  }

  @override
  String paymentAccountDefault(int id) {
    return 'Account $id';
  }

  @override
  String refundErrorReceiptNotFound(String number) {
    return 'Receipt #$number not found';
  }

  @override
  String refundErrorLoadingReceipt(String error) {
    return 'Error loading receipt: $error';
  }

  @override
  String refundErrorSearch(String error) {
    return 'Search error: $error';
  }

  @override
  String get refundErrorProductNotFound => 'Product not found';

  @override
  String get refundErrorNotAuthenticated => 'User not authenticated';

  @override
  String refundErrorProcessing(String error) {
    return 'Refund error: $error';
  }

  @override
  String shiftErrorLoadingData(String error) {
    return 'Error loading shift data: $error';
  }

  @override
  String shiftErrorOpening(String error) {
    return 'Error opening shift: $error';
  }

  @override
  String shiftErrorClosing(String error) {
    return 'Error closing shift: $error';
  }

  @override
  String shiftErrorPrinting(String error) {
    return 'Z-report print error: $error';
  }

  @override
  String get cashOpTypeInvestment => 'Deposit';

  @override
  String get cashOpTypeExpense => 'Expense';

  @override
  String get cashOpTypeDividend => 'Withdrawal';

  @override
  String get supplyNoName => 'No name';

  @override
  String get supplyNoTitle => 'Untitled';

  @override
  String get supplyErrorSupplierNotFound => 'Supplier not found';

  @override
  String supplyErrorSelectingSupplier(String error) {
    return 'Error selecting supplier: $error';
  }

  @override
  String get supplyErrorAccountNotFound => 'Account not found';

  @override
  String supplyErrorSelectingAccount(String error) {
    return 'Error selecting account: $error';
  }

  @override
  String supplyErrorAddingProduct(String error) {
    return 'Error adding product: $error';
  }

  @override
  String get supplyErrorProductNotFound => 'Product not found';

  @override
  String get supplyErrorMissingFields => 'Fill in all required fields';

  @override
  String supplyErrorSaving(String error) {
    return 'Save error: $error';
  }

  @override
  String historyErrorLoading(String error) {
    return 'Error loading history: $error';
  }

  @override
  String get syncTypeProducts => 'Products';

  @override
  String get syncTypePrices => 'Prices';

  @override
  String get syncTypeCategories => 'Categories';

  @override
  String get syncTypeAgents => 'Agents';

  @override
  String get syncTypeConfig => 'Settings';

  @override
  String get syncTypeSales => 'Sales';

  @override
  String get syncTypeRefunds => 'Refunds';

  @override
  String get syncTypeCashOps => 'Cash operations';

  @override
  String get syncTypeShifts => 'Shifts';

  @override
  String get syncTypeSupplies => 'Supplies';

  @override
  String get syncStepPreparing => 'Preparing...';

  @override
  String syncStepUploading(String type) {
    return 'Uploading: $type';
  }

  @override
  String syncStepDownloading(String type) {
    return 'Downloading: $type';
  }

  @override
  String get syncCompleted => 'Sync completed';

  @override
  String get loginErrorNoUsers => 'No registered users';

  @override
  String loginErrorLoadingData(String error) {
    return 'Error loading data: $error';
  }

  @override
  String get loginErrorSelectUser => 'Select a user';

  @override
  String get loginErrorIncompletePin => 'Enter PIN (minimum 4 digits)';

  @override
  String get loginErrorNoRsaKey =>
      'Error: RSA key not configured. Contact administrator.';

  @override
  String get loginErrorWrongPin => 'Wrong PIN';

  @override
  String get loginErrorSystemTime =>
      'System time is incorrect. Check date and time settings.';

  @override
  String get receiptLabelBin => 'BIN:';

  @override
  String get receiptLabelPhone => 'Tel:';

  @override
  String get receiptLabelReceiptNo => 'Receipt #:';

  @override
  String get receiptLabelPosId => 'POS:';

  @override
  String get receiptLabelDate => 'Date:';

  @override
  String get receiptLabelCashier => 'Cashier:';

  @override
  String get receiptLabelTable => 'Table:';

  @override
  String get receiptLabelWaiter => 'Waiter:';

  @override
  String get receiptLabelGuests => 'Guests:';

  @override
  String get receiptLabelCustomer => 'Customer:';

  @override
  String get receiptLabelSubtotal => 'Subtotal:';

  @override
  String get receiptLabelDiscount => 'Discount:';

  @override
  String get receiptLabelServiceCharge => 'Service charge:';

  @override
  String get receiptLabelTotal => 'TOTAL:';

  @override
  String receiptLabelVat(String percent) {
    return 'incl. VAT $percent%:';
  }

  @override
  String get receiptLabelCash => 'Cash:';

  @override
  String get receiptLabelCard => 'Card:';

  @override
  String get receiptLabelChange => 'Change:';

  @override
  String get receiptLabelCheckReceipt => 'Verify receipt:';

  @override
  String get receiptLabelItemName => 'Name';

  @override
  String get receiptLabelQty => 'Qty';

  @override
  String get receiptLabelPrice => 'Price';

  @override
  String get receiptLabelAmount => 'Amount';

  @override
  String get receiptLabelItemDiscount => 'Discount:';

  @override
  String get receiptLabelFiscalBin => 'BIN:';

  @override
  String get receiptLabelFiscalNo => 'FN:';

  @override
  String get receiptLabelFiscalSign => 'FS:';

  @override
  String get receiptLabelVatCertificate => 'VAT:';

  @override
  String get receiptLabelOfflineMode => '*** OFFLINE ***';

  @override
  String get receiptLabelRefundHeader => '*** REFUND ***';

  @override
  String get receiptLabelRefundNo => 'Refund #:';

  @override
  String get receiptLabelReason => 'Reason:';

  @override
  String get receiptLabelRefundTotal => 'REFUND TOTAL:';

  @override
  String get receiptLabelZReport => 'Z-REPORT';

  @override
  String get receiptLabelShiftClosing => 'SHIFT CLOSING';

  @override
  String get receiptLabelShiftNo => 'Shift #:';

  @override
  String get receiptLabelShiftOpenTime => 'Opened:';

  @override
  String get receiptLabelShiftCloseTime => 'Closed:';

  @override
  String get receiptLabelSales => 'SALES';

  @override
  String get receiptLabelQuantity => 'Quantity:';

  @override
  String get receiptLabelCashSales => 'Cash:';

  @override
  String get receiptLabelCardSales => 'Card:';

  @override
  String get receiptLabelSalesTotal => 'Total:';

  @override
  String get receiptLabelRefunds => 'REFUNDS';

  @override
  String get receiptLabelRefundQty => 'Quantity:';

  @override
  String get receiptLabelRefundAmount => 'Amount:';

  @override
  String get receiptLabelCashOperations => 'CASH OPERATIONS';

  @override
  String get receiptLabelInvestments => 'Deposits:';

  @override
  String get receiptLabelExpenses => 'Expenses:';

  @override
  String get receiptLabelRevenue => 'REVENUE:';

  @override
  String get receiptLabelCashInDrawer => 'CASH IN DRAWER:';

  @override
  String get receiptLabelXReport => 'X-REPORT';

  @override
  String get receiptLabelType => 'Type:';

  @override
  String get receiptLabelDescription => 'Description:';

  @override
  String get receiptLabelDebtPayment => 'DEBT PAYMENT';

  @override
  String get receiptLabelPreviousDebt => 'Previous debt:';

  @override
  String get receiptLabelPaidAmount => 'PAID:';

  @override
  String get receiptLabelRemainingDebt => 'Remaining:';

  @override
  String get receiptLabelTestPrint => 'TEST PRINT';

  @override
  String get receiptLabelThankYou => 'Thank you for your purchase!';

  @override
  String get receiptLabelSaleReceipt => 'SALES RECEIPT';

  @override
  String get receiptLabelOfflineHeader => '*** OFFLINE MODE ***';

  @override
  String get receiptLabelVatCertificateTitle => 'VAT Certificate:';

  @override
  String get fiscalErrorBin12Digits => 'BIN must contain 12 digits';

  @override
  String get fiscalErrorBinDigitsOnly => 'BIN must contain only digits';

  @override
  String get fiscalErrorFiscalNoRequired => 'Fiscal number is required';

  @override
  String get fiscalErrorRnkRequired => 'RNK is required';

  @override
  String get fiscalErrorZnkRequired => 'ZNK is required';

  @override
  String get fiscalErrorVatSerialRequired =>
      'VAT certificate serial is required';

  @override
  String get fiscalErrorVatNumberRequired =>
      'VAT certificate number is required';

  @override
  String get telegramTabPhone => 'By phone';

  @override
  String get telegramTabQr => 'QR code';

  @override
  String get telegramQrAuthTitle => 'QR Code Login';

  @override
  String get telegramQrAuthDescription =>
      'Scan the QR code in the Telegram app on your phone';

  @override
  String get telegramQrTapToGenerate => 'Tap to generate\nQR code';

  @override
  String get telegramQrHowToScan => 'How to scan:';

  @override
  String get telegramQrStep1 => 'Open Telegram on your phone';

  @override
  String get telegramQrStep2 => 'Go to Settings → Devices';

  @override
  String get telegramQrStep3 => 'Tap \"Link Desktop Device\"';

  @override
  String get telegramQrStep4 => 'Scan the QR code';

  @override
  String get telegramEnterCode => 'Enter code';

  @override
  String telegramCodeSentTo(String phone) {
    return 'Code was sent to Telegram to number\n$phone';
  }

  @override
  String get telegramCodeLabel => 'Verification code';

  @override
  String get telegramPasswordDescription =>
      'Enter your Telegram account password';

  @override
  String telegramPasswordHint(String hint) {
    return 'Hint: $hint';
  }

  @override
  String get telegramPasswordLabel => 'Password';

  @override
  String get telegramRegistrationDescription =>
      'Account with this number not found.\nCreate a new Telegram account.';

  @override
  String get telegramFirstNameLabel => 'First name';

  @override
  String get telegramLastNameLabel => 'Last name (optional)';

  @override
  String get telegramLoadingOrgData => 'Loading organization data...';

  @override
  String get telegramSearchingExistingChannels =>
      'Searching for existing channels...';

  @override
  String get telegramFoundChannels =>
      'Organization channels found.\nLoading configuration...';

  @override
  String get telegramCheckingChannels => 'Checking for existing channels...';

  @override
  String get telegramOrgDataNotLoaded =>
      'Could not load data.\nEnter your organization information.';

  @override
  String get telegramOrgDataFirstRun =>
      'First TelePOS launch.\nEnter your organization information.';

  @override
  String get telegramStoreNameLabel => 'Store name *';

  @override
  String get telegramStoreNameHint => 'My Store';

  @override
  String get telegramBinLabel => 'BIN/IIN *';

  @override
  String get telegramAddressLabel => 'Address (optional)';

  @override
  String get telegramAddressHint => 'City, Street, 123';

  @override
  String get telegramPosIdLabel => 'POS ID';

  @override
  String get telegramOwnerNameLabel => 'Owner name (optional)';

  @override
  String get telegramImportantNote => 'Important';

  @override
  String get telegramOrgDataNote =>
      'This data will be used to create system channels and sync between POS devices. On other devices data will be loaded automatically.';

  @override
  String get telegramCreatingChannels => 'Creating system channels...';

  @override
  String get telegramSettingUpEncryption => 'Setting up encryption...';

  @override
  String get telegramSettingUp => 'Setting up...';

  @override
  String get telegramPleaseWait => 'Please wait.\nThis may take a moment.';

  @override
  String get telegramSetupDone => 'Setup complete!';

  @override
  String get telegramSetupDoneMessage =>
      'Telegram configured successfully.\nSystem channels created.';

  @override
  String get telegramTermsNotice =>
      'By tapping \"Get Code\", you agree to Telegram\'s terms of service';

  @override
  String get telegramActionsSection => 'Actions';

  @override
  String get chatNotConfigured => 'Chat not configured';

  @override
  String get chatCanDeleteOwnOnly => 'You can only delete your own messages';

  @override
  String get chatMessageDeleted => 'Message deleted';

  @override
  String get chatDeleteFailed => 'Could not delete message';

  @override
  String get chatTelegramNotLinked => 'Telegram not linked';

  @override
  String get chatLinkInstructions =>
      'Enter your Telegram User ID for identification in the staff chat.';

  @override
  String get chatLinkHowTo =>
      'How to find ID:\n1. Open @userinfobot in Telegram\n2. Tap /start\n3. Copy the number from the \"Id\" field';

  @override
  String get chatLinkFailed => 'Could not link. This ID may already be in use.';

  @override
  String get chatPhotoSent => 'Photo sent';

  @override
  String get chatPhotoFailed => 'Could not send photo';

  @override
  String get chatPhotoError => 'Error selecting photo';

  @override
  String get chatPhotoUnavailableWeb =>
      'Photo sending is not available in web version';

  @override
  String get chatDocSent => 'Document sent';

  @override
  String get chatDocFailed => 'Could not send document';

  @override
  String get chatDocError => 'Error selecting document';

  @override
  String get chatDocUnavailableWeb =>
      'Document sending is not available in web version';

  @override
  String get chatDocPathError => 'Could not get file path';

  @override
  String get chatDocTooLarge => 'File too large (max 50 MB)';

  @override
  String get chatLocationSent => 'Location sent';

  @override
  String get chatLocationFailed => 'Could not send location';

  @override
  String get chatLocationError => 'Error getting location';

  @override
  String get chatLocationUnavailableWeb =>
      'Geolocation is not available in web version';

  @override
  String get chatLocationDenied => 'Location access denied';

  @override
  String get chatLocationDeniedForever =>
      'Location access permanently denied. Change in settings.';

  @override
  String get chatLocationServiceDisabled =>
      'Enable location services on your device';

  @override
  String get syncToUpload => 'To upload';

  @override
  String get syncToDownload => 'To download';

  @override
  String get syncDataTypeCol => 'Data type';

  @override
  String get syncDirectionCol => 'Direction';

  @override
  String get syncPendingCol => 'Pending';

  @override
  String get syncStatusCol => 'Status';

  @override
  String get syncProgressCol => 'Progress';

  @override
  String get syncUpload => 'Upload';

  @override
  String get syncDownload => 'Download';

  @override
  String syncPendingCount(int count) {
    return 'Pending: $count';
  }

  @override
  String get syncInfoTelegram =>
      'Data syncs between POS terminals via Telegram. Users are shared across all terminals.';

  @override
  String get syncAutoEnabled => 'Data syncs automatically';

  @override
  String get syncManualOnly => 'Manual sync only';

  @override
  String syncMinutes(int count) {
    return '$count min';
  }

  @override
  String get agentBinIin => 'BIN/IIN';

  @override
  String get agentLastOperation => 'Last operation';

  @override
  String get agentNoAdditionalInfo => 'No additional information';

  @override
  String get agentNoDebt => 'No debt';

  @override
  String agentDeletedWithName(String name) {
    return 'Customer \"$name\" deleted';
  }

  @override
  String agentDeleteError(String error) {
    return 'Delete error: $error';
  }

  @override
  String get agentNewCustomer => 'New customer';

  @override
  String get agentTypeCustomer => 'Customer';

  @override
  String get agentTypeSupplier => 'Supplier';

  @override
  String get agentNameHint => 'Enter name';

  @override
  String get agentBinHint => '12 digits';

  @override
  String get agentCustomerFound => 'Customer found';

  @override
  String get agentDeletedPhoneMsg => 'Customer with this phone was deleted';

  @override
  String get agentRestoreQuestion => 'Want to restore?';

  @override
  String get agentRestore => 'Restore';

  @override
  String get kaspiTerminal => 'Kaspi POS Terminal';

  @override
  String get kaspiIpAddress => 'Terminal IP address';

  @override
  String get kaspiInvalidIp => 'Invalid IP address format';

  @override
  String get kaspiPort => 'Port';

  @override
  String get kaspiTesting => 'Testing...';

  @override
  String get kaspiTest => 'TEST';

  @override
  String get kaspiDisconnected => 'Disconnected';

  @override
  String get kaspiConnecting => 'Connecting...';

  @override
  String get kaspiConnected => 'Connection established';

  @override
  String get kaspiNoConnection => 'No connection';

  @override
  String get kaspiTestPassed => 'Test passed';

  @override
  String get kaspiTestFailed => 'Test failed';

  @override
  String kaspiLatency(String ms) {
    return 'Latency: $ms ms';
  }

  @override
  String kaspiTerminalInfo(String info) {
    return 'Terminal: $info';
  }

  @override
  String get splashSubtitle => 'Point of Sale System';

  @override
  String get splashInitializing => 'Initializing...';

  @override
  String get splashLoadingOrg => 'Loading organization data...';

  @override
  String get splashEnterPosKey => 'Enter POS key';

  @override
  String get splashEnterPosKeyMessage =>
      'To activate the POS, enter the key provided by the administrator.';

  @override
  String get splashPosKeyHint => 'XXXX-XXXX-XXXX-XXXX';

  @override
  String get splashKeyEmpty => 'Key cannot be empty';

  @override
  String get splashKeyTooShort => 'Key is too short';

  @override
  String get splashKeyNotEntered => 'Key not entered';

  @override
  String get splashKeyRequiredMessage =>
      'The POS cannot operate without a key. The application will be closed.';

  @override
  String get splashDataCorrupted => 'Data corrupted';

  @override
  String get splashDataCorruptedMessage =>
      'Required application data is missing or corrupted.\n\nChoose an action:';

  @override
  String get splashReconfigure => 'Reconfigure';

  @override
  String get splashExit => 'Exit';

  @override
  String get splashDatabaseError => 'Database error';

  @override
  String get splashDatabaseErrorMessage =>
      'The database is corrupted or unavailable.\n\nYou can try to restore from a backup or reconfigure the POS.';

  @override
  String get splashRestoreFromBackup => 'Restore from backup';

  @override
  String get splashSyncSuspended => 'Sync suspended';

  @override
  String get splashSyncSuspendedMessage =>
      'Data synchronization is temporarily suspended.\n\nThe POS is operating in offline mode. Data will be synced when connection is restored.';

  @override
  String get splashAuthError =>
      'Authorization error\n\nThe access token is invalid or expired.\nContact the administrator for a new key.';

  @override
  String get splashSupportEnded =>
      'Version not supported\n\nThis application version is no longer supported.\nPlease update to the latest version.';

  @override
  String get generalSettingsTitle => 'Settings';

  @override
  String get generalSettingsPosInfo => 'POS Information';

  @override
  String get generalSettingsCashBoxName => 'POS Name';

  @override
  String get generalSettingsCompany => 'Company';

  @override
  String get generalSettingsIinBin => 'IIN/BIN';

  @override
  String get generalSettingsPosId => 'POS ID';

  @override
  String get generalSettingsStoreId => 'Store ID';

  @override
  String get generalSettingsNotSpecified => 'Not specified';

  @override
  String get generalSettingsAppVersion => 'App Version';

  @override
  String get generalSettingsVersion => 'Version';

  @override
  String get generalSettingsPlatform => 'Platform';

  @override
  String get generalSettingsLanguage => 'Interface Language';

  @override
  String get generalSettingsTheme => 'Appearance';

  @override
  String get generalSettingsThemeDesc => 'Light, dark or follow the system';

  @override
  String get generalSettingsThemeLight => 'Light';

  @override
  String get generalSettingsThemeDark => 'Dark';

  @override
  String get generalSettingsThemeSystem => 'Follow the system';

  @override
  String generalSettingsLanguageChanged(String language) {
    return 'Language changed to $language';
  }

  @override
  String get generalSettingsCurrency => 'Currency';

  @override
  String get generalSettingsCurrencySymbol => 'Symbol';

  @override
  String get generalSettingsCurrencyCode => 'Code';

  @override
  String get generalSettingsCountry => 'Country';

  @override
  String get generalSettingsAdditional => 'Additional Settings';

  @override
  String get generalSettingsTransport => 'Transport';

  @override
  String get generalSettingsTransportSubtitle => 'Data sync settings';

  @override
  String get generalSettingsPrinter => 'Printer';

  @override
  String get generalSettingsPrinterSubtitle => 'Receipt printing settings';

  @override
  String get generalSettingsPermissions => 'Permissions';

  @override
  String get generalSettingsPermissionsSubtitle => 'Cashier permissions';

  @override
  String get generalSettingsFiscal => 'Fiscalization';

  @override
  String get generalSettingsFiscalSubtitle => 'WebKassa, OFD, VAT';

  @override
  String get generalSettingsRestaurant => 'Operating Mode';

  @override
  String get generalSettingsRestaurantSubtitle =>
      'Retail, restaurant, service mode';

  @override
  String get generalSettingsTelegram => 'Telegram';

  @override
  String get generalSettingsTelegramSubtitle =>
      'Communication channels and bots';

  @override
  String get generalSettingsPosInfoDesc => 'POS name, company, ID';

  @override
  String get generalSettingsVersionDesc => 'Current version and platform';

  @override
  String get generalSettingsLanguageDesc => 'Interface language selection';

  @override
  String get generalSettingsCurrencyDesc => 'Currency and country';

  @override
  String get generalSettingsUpdate => 'Update';

  @override
  String get generalSettingsUpdateSubtitle => 'Check and install updates';

  @override
  String get generalSettingsAppUpdate => 'Application update';

  @override
  String get generalSettingsAppUpdateSubtitle =>
      'POS app update (not the OS update)';

  @override
  String get generalSettingsUpdateDesc => 'Current version and updates';

  @override
  String get settingsUpdateTitle => 'Application Update';

  @override
  String get settingsUpdateCurrentVersion => 'Current version';

  @override
  String get settingsUpdateCheckBtn => 'Check for updates';

  @override
  String get settingsUpdateChecking => 'Checking for updates...';

  @override
  String get settingsUpdateUpToDate => 'You have the latest version';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Version $version available';
  }

  @override
  String get settingsUpdateDownloadBtn => 'Download update';

  @override
  String settingsUpdateDownloading(String percent) {
    return 'Downloading... $percent%';
  }

  @override
  String get settingsUpdateInstallBtn => 'Install update';

  @override
  String get settingsUpdateInstalling => 'Installing...';

  @override
  String get settingsUpdateFailed => 'Update failed';

  @override
  String get settingsUpdateAutoEnabled => 'Automatic check every 3 hours';

  @override
  String get settingsUpdateCloseShift => 'Close shift before updating';

  @override
  String get settingsUpdateReleaseNotes => 'What\'s new';

  @override
  String get countryKazakhstan => 'Kazakhstan';

  @override
  String get countryRussia => 'Russia';

  @override
  String get countryKyrgyzstan => 'Kyrgyzstan';

  @override
  String get countryUzbekistan => 'Uzbekistan';

  @override
  String get countryUSA => 'USA';

  @override
  String get countryTurkmenistan => 'Turkmenistan';

  @override
  String get permEditPrice => 'Edit price';

  @override
  String get permSellInDebt => 'Sell on credit';

  @override
  String get permDiscounts => 'Discounts';

  @override
  String get permCashOperations => 'Cash operations';

  @override
  String get permSendToOfd => 'Send to OFD';

  @override
  String get permCancelPayment => 'Cancel payment';

  @override
  String get permDeferSale => 'Deferred sale';

  @override
  String get permShowHistory => 'Show history';

  @override
  String get printerSettingsSaved => 'Settings saved';

  @override
  String printerSettingsSaveError(String error) {
    return 'Save error: $error';
  }

  @override
  String get printerSettingsPrinting => 'Printing...';

  @override
  String get printerSettingsTestReceipt => 'TEST RECEIPT';

  @override
  String get printerSettingsWidth => 'Width:';

  @override
  String printerSettingsWidthValue(int width) {
    return '$width characters';
  }

  @override
  String get printerSettingsType => 'Type:';

  @override
  String get printerSettingsAddress => 'Address:';

  @override
  String get printerSettingsNotSpecifiedAddr => 'Not specified';

  @override
  String get printerSettingsPrinterWorks => 'Printer works!';

  @override
  String get printerSettingsPrintSuccess => 'Print successful';

  @override
  String get printerSettingsPrintError => 'Print error';

  @override
  String get printerSettingsNotConnected => 'Not connected';

  @override
  String get printerSettingsChecking => 'Checking...';

  @override
  String get printerSettingsReady => 'Ready';

  @override
  String get printerSettingsNoPaper => 'No paper';

  @override
  String get printerSettingsCoverOpen => 'Cover open';

  @override
  String get printerSettingsSave => 'Save';

  @override
  String get printerSettingsConnectionType => 'Connection Type';

  @override
  String get printerSettingsPrinterAddress => 'Printer Address';

  @override
  String get printerSettingsPaperWidth => 'Paper Width';

  @override
  String get printerSettingsTesting => 'Testing';

  @override
  String printerSettingsStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get printerSettingsCheck => 'Check';

  @override
  String get printerSettingsTestCheck => 'Test receipt';

  @override
  String get printerSettingsPort => 'Port';

  @override
  String get printerSettingsIpAddress => 'Printer IP address';

  @override
  String get printerSettingsMacAddress => 'MAC address or name';

  @override
  String get printerSettingsPrinterName => 'Printer name';

  @override
  String get printerSettingsComPort => 'COM port';

  @override
  String get printerSettingsSerialCom => 'Serial (COM)';

  @override
  String get printerSettingsPaperWidth58 => '58mm (32 chars)';

  @override
  String get printerSettingsPaperWidth80_42 => '80mm (42 chars)';

  @override
  String get printerSettingsPaperWidth80_48 => '80mm (48 chars)';

  @override
  String get fiscalSettingsTitle => 'Fiscalization';

  @override
  String get fiscalSettingsSaved => 'Settings saved';

  @override
  String fiscalSettingsSaveError(String error) {
    return 'Save error: $error';
  }

  @override
  String get fiscalSettingsSave => 'Save';

  @override
  String get fiscalSettingsOperator => 'Fiscal Operator';

  @override
  String get fiscalSettingsWebkassaSettings => 'WebKassa Settings';

  @override
  String get fiscalSettingsTaxpayerInfo => 'Taxpayer Information';

  @override
  String get fiscalSettingsVatSettings => 'VAT Settings';

  @override
  String get fiscalSettingsWebkassaLabel => 'WebKassa';

  @override
  String get fiscalSettingsWebkassaDesc => 'Cloud fiscal service';

  @override
  String get fiscalSettingsOfdLabel => 'OFD';

  @override
  String get fiscalSettingsOfdDesc => 'Fiscal data operator';

  @override
  String get fiscalSettingsNoneLabel => 'No fiscalization';

  @override
  String get fiscalSettingsNoneDesc => 'Receipts are not sent to OFD';

  @override
  String get fiscalSettingsOfdId => 'OFD ID';

  @override
  String get fiscalSettingsOfdIdHint => 'OFD identifier';

  @override
  String get fiscalSettingsOfdName => 'OFD Name';

  @override
  String get fiscalSettingsOfdNameHint => 'WebKassa / OFD.kz';

  @override
  String get fiscalSettingsOfdHost => 'OFD Server Address';

  @override
  String get fiscalSettingsOfdHostHint => 'https://api.webkassa.kz';

  @override
  String get fiscalSettingsWebkassaActive => 'WebKassa activated';

  @override
  String get fiscalSettingsWebkassaInactive => 'WebKassa not activated';

  @override
  String get fiscalSettingsCompanyName => 'Company Name';

  @override
  String get fiscalSettingsCashBox => 'Cash Register';

  @override
  String get fiscalSettingsVatPayer => 'VAT Payer';

  @override
  String get fiscalSettingsVatPayerSubtitle =>
      'Organization is a VAT payer (12%)';

  @override
  String get fiscalSettingsPrintVat => 'Print VAT on receipt';

  @override
  String get fiscalSettingsPrintVatSubtitle => 'Display VAT amount on receipt';

  @override
  String get fiscalSettingsVatRate => 'VAT rate: 12% (calculated as 3/28)';

  @override
  String historyProductUcode(String ucode) {
    return 'Product #$ucode';
  }

  @override
  String historyRefundProductId(String id) {
    return 'Refund product #$id';
  }

  @override
  String historyAccountId(String id) {
    return 'Account #$id';
  }

  @override
  String historyLoadError(String error) {
    return 'Loading error: $error';
  }

  @override
  String historyReceiptNo(String number) {
    return 'Receipt $number';
  }

  @override
  String get historySyncSynced => 'Synced';

  @override
  String get historySyncPending => 'Pend.';

  @override
  String get historySyncSending => 'Send.';

  @override
  String get historySyncDeferred => 'Defer.';

  @override
  String get historySyncInProgress => 'In progress';

  @override
  String get historyClient => 'Client';

  @override
  String get historyFiscalization => 'Fiscalization';

  @override
  String get historyProducts => 'Products';

  @override
  String get historyPayment => 'Payment';

  @override
  String get historyNoProducts => 'No products';

  @override
  String get historyNoPayments => 'No payments';

  @override
  String historyPrintingReceipt(String number) {
    return 'Printing receipt $number...';
  }

  @override
  String get historyReceiptPrinted => 'Receipt printed';

  @override
  String get historyPrintError => 'Print error';

  @override
  String get historyOperationType => 'Operation type';

  @override
  String get historyFilterSales => 'Sales';

  @override
  String get historyFilterRefunds => 'Refunds';

  @override
  String get historySearchShort => 'Search...';

  @override
  String get historyFilters => 'Filters';

  @override
  String get historyDateFrom => 'From';

  @override
  String get historyDateTo => 'To';

  @override
  String get historyReset => 'Reset';

  @override
  String get historyApply => 'Apply';

  @override
  String get historySearchFull => 'Search by receipt number, amount...';

  @override
  String get historySyncStatus => 'Sync status';

  @override
  String get historyReceiptColumn => 'Receipt';

  @override
  String get historySyncSyncedFull => 'Synchronized';

  @override
  String get historySyncPendingFull => 'Pending sync';

  @override
  String get historySyncSendingFull => 'Sending';

  @override
  String get historySyncDeferredFull => 'Deferred';

  @override
  String get historySyncInProgressFull => 'In progress';

  @override
  String get historyPaymentCash => 'Cash';

  @override
  String get historyPaymentCard => 'Card';

  @override
  String get historyPaymentMixed => 'Mixed';

  @override
  String get historyPaymentBonus => 'Bonus';

  @override
  String get historyPaymentDebt => 'Debt';

  @override
  String get historyPaymentDiscount => 'Discount';

  @override
  String get historyPaymentWithDiscount => 'With discount';

  @override
  String get historyOfdFiscalized => 'Fiscalized';

  @override
  String get historyOfdError => 'Fiscal error';

  @override
  String get historyOfdNotFiscalized => 'Not fiscalized';

  @override
  String get historyClearFilters => 'Clear filters';

  @override
  String historyRecordsRange(String start, String end, String total) {
    return 'Records $start–$end of $total';
  }

  @override
  String get historyFirstPage => 'First page';

  @override
  String get historyPrevious => 'Previous';

  @override
  String get historyNextPage => 'Next';

  @override
  String get historyLastPage => 'Last page';

  @override
  String historyAmount(String amount) {
    return 'Amount: $amount';
  }

  @override
  String historyDate(String date) {
    return 'Date: $date';
  }

  @override
  String historyPos(String id) {
    return 'POS: $id';
  }

  @override
  String historyClientName(String name) {
    return 'Client: $name';
  }

  @override
  String get historyFiscalYes => 'Yes';

  @override
  String get historyFiscalNo => 'No';

  @override
  String get historyFiscalError => 'Error';

  @override
  String get shiftPrintZReport => 'Print Z-report';

  @override
  String get shiftZReportQueued =>
      'Z-report accepted into the print queue. There is no paper yet: it will come out when the printer can. The job waits 30 minutes — see it under Settings → Printer';

  @override
  String get shiftZReportAlreadyQueued =>
      'The Z-report has already been submitted for printing — it is not printed twice';

  @override
  String get shiftZReportPrintFailed =>
      'Failed to submit the Z-report for printing';

  @override
  String get shiftFinishAllSales => 'Finish all sales';

  @override
  String get shiftCannotClose => 'Cannot close shift';

  @override
  String get shiftOpeningShift => 'Open shift';

  @override
  String get shiftClosingShift => 'Close shift';

  @override
  String get shiftEnterInitialAmount => 'Enter initial cash amount:';

  @override
  String get shiftDiscrepancyFound => 'Discrepancy found';

  @override
  String shiftDifferenceAmount(String amount) {
    return 'Difference: $amount';
  }

  @override
  String get shiftConfirmCloseQuestion =>
      'Are you sure you want to close the shift?';

  @override
  String shiftFixedAmount(String amount) {
    return 'Amount to be recorded: $amount KZT';
  }

  @override
  String get shiftCloseWithDiscrepancy => 'Close with discrepancy';

  @override
  String get shiftCashierLabel => 'Cashier';

  @override
  String get shiftUnknown => 'Unknown';

  @override
  String get shiftSystemTotal => 'Expected in register';

  @override
  String get shiftEnteredTotal => 'Counted amount';

  @override
  String get shiftCashOperations => 'Cash operations';

  @override
  String get shiftSalesLabel => 'Sales';

  @override
  String get shiftSalesTotal => 'Sales total';

  @override
  String get shiftCashSales => 'Cash';

  @override
  String get shiftCardSales => 'Card';

  @override
  String get shiftRefundsTotal => 'Refunds';

  @override
  String get shiftShortage => 'Shortage';

  @override
  String get shiftSurplus => 'Surplus';

  @override
  String get shiftBalances => 'Balanced';

  @override
  String get shiftCloseBlocked => 'Closing blocked';

  @override
  String shiftActiveSalesCount(int count) {
    return 'Active sales: $count';
  }

  @override
  String shiftPendingSalesCount(int count) {
    return 'Pending sales: $count';
  }

  @override
  String get shiftFinishSalesBeforeClose =>
      'Finish or cancel sales before closing the shift';

  @override
  String get shiftBillsTab => 'Bills';

  @override
  String get shiftTotalTab => 'Total';

  @override
  String get shiftOperationsTab => 'Operations';

  @override
  String get shiftAmountTab => 'Amount';

  @override
  String get shiftBillCount => 'Bill count';

  @override
  String get shiftDifferenceLabel => 'Difference: ';

  @override
  String get supplySupplierRequired => 'Supplier *';

  @override
  String get supplyPaymentType => 'Payment type';

  @override
  String get supplyFullPayment => 'Full payment';

  @override
  String get supplyAccountDebit => 'Account debit';

  @override
  String get supplyConsignment => 'Consignment';

  @override
  String get supplyDeferredPayment => 'Deferred payment';

  @override
  String get supplyPaymentAccountRequired => 'Payment account *';

  @override
  String get supplyAddProduct => 'Add product';

  @override
  String get supplyBarcodeOrSku => 'Barcode or SKU';

  @override
  String supplyProductsCount(int count) {
    return 'Products ($count)';
  }

  @override
  String supplyAmountValue(String amount) {
    return 'Amount: $amount';
  }

  @override
  String get supplyProductNotFound => 'Product not found';

  @override
  String get supplyInvalidQuantity => 'Enter a valid quantity';

  @override
  String get supplySelectSupplierTitle => 'Select supplier';

  @override
  String get supplySuppliersNotFound => 'No suppliers found';

  @override
  String get supplySelectAccountTitle => 'Select account';

  @override
  String get supplyAccountsNotFound => 'No accounts found';

  @override
  String supplyAccountBalance(String amount) {
    return 'Balance: $amount';
  }

  @override
  String supplyProductNumber(String number) {
    return 'Product #$number';
  }

  @override
  String supplyProductCountLabel(int count) {
    return 'Products: $count';
  }

  @override
  String supplyTotalLabel(String amount) {
    return 'Total: $amount';
  }

  @override
  String supplySavedSuccess(int count, String amount) {
    return 'Supply saved. Products: $count, amount: $amount';
  }

  @override
  String get supplyCancelConfirm => 'Cancel supply?';

  @override
  String get supplyCancelMessage => 'All entered data will be lost.';

  @override
  String get supplyYesCancel => 'Yes, cancel';

  @override
  String get supplySearchProduct => 'Search product...';

  @override
  String get supplyAddProductsHint => 'Add products to supply';

  @override
  String get supplyScanOrSearch => 'Scan barcode or search product';

  @override
  String get refundTotalAmount => 'Refund amount';

  @override
  String get refundPosLabel => 'POS';

  @override
  String refundSelectedOfTotal(String selected, String total) {
    return '$selected of $total';
  }

  @override
  String get refundTotalProducts => 'Total products';

  @override
  String get refundToReturn => 'TO REFUND';

  @override
  String get refundToReturnLabel => 'To refund:';

  @override
  String get refundAction => 'REFUND';

  @override
  String refundSelectedItemsShort(String selected, String total) {
    return '$selected of $total items';
  }

  @override
  String get refundColumnName => 'Name';

  @override
  String get refundColumnQty => 'Qty';

  @override
  String get refundEmptyHint => 'Load a receipt or add products manually';

  @override
  String get refundNoItemsShort => 'No products';

  @override
  String get refundEmptyHintShort => 'Load a receipt or\nadd products';

  @override
  String refundSelectedCount(String count) {
    return 'Selected items: $count';
  }

  @override
  String refundAmountValue(String amount) {
    return 'Refund amount: $amount';
  }

  @override
  String get refundSuccess => 'Refund completed successfully';

  @override
  String get paymentAmountDue => 'Amount due';

  @override
  String get paymentTotalDue => 'Total due';

  @override
  String get paymentCashLabel => 'Cash';

  @override
  String get paymentReceived => 'Received';

  @override
  String get paymentRemainingLabel => 'Remaining';

  @override
  String paymentCardAmount(String amount) {
    return 'Card payment for $amount';
  }

  @override
  String get paymentLoyaltyProgram => 'Loyalty program';

  @override
  String get paymentPhoneNumber => 'Phone number';

  @override
  String get paymentAvailableBonus => 'Available bonus:';

  @override
  String get paymentUseBonuses => 'Use bonuses';

  @override
  String paymentBonusToDeduct(String amount) {
    return 'To deduct: $amount bonuses';
  }

  @override
  String get paymentSuccessMessage => 'Payment successful';

  @override
  String get paymentRefundButton => 'REFUND';

  @override
  String get paymentPayButton => 'PAY';

  @override
  String get syncWidgetRetry => 'Retry';

  @override
  String syncWidgetLastSync(String time) {
    return 'Last sync: $time';
  }

  @override
  String syncWidgetRecordsCount(int count) {
    return '$count records';
  }

  @override
  String get syncWidgetWaiting => 'Waiting';

  @override
  String get syncWidgetSynced => 'Synced';

  @override
  String get syncWidgetJustNow => 'just now';

  @override
  String syncWidgetMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String syncWidgetHoursAgo(int hours) {
    return '$hours h ago';
  }

  @override
  String syncWidgetDaysAgo(int days) {
    return '$days d ago';
  }

  @override
  String get syncWidgetConnecting => 'Connecting to server...';

  @override
  String get syncWidgetSyncingProducts => 'Syncing products...';

  @override
  String get syncWidgetSyncingSales => 'Syncing sales...';

  @override
  String get syncWidgetSyncingAgents => 'Syncing agents...';

  @override
  String get syncWidgetSyncingPrices => 'Syncing prices...';

  @override
  String get syncWidgetFinishing => 'Finishing...';

  @override
  String get updateDialogUpdating => 'Updating...';

  @override
  String get updateDialogAvailable => 'Update available';

  @override
  String updateDialogAutoUpdate(int seconds) {
    return 'Auto update in $seconds sec';
  }

  @override
  String get updateDialogUpdateNow => 'Update now';

  @override
  String get updateDialogLater => 'Later';

  @override
  String get updateDialogSkip => 'Skip';

  @override
  String get updateDialogUpdate => 'Update';

  @override
  String storeUpdateVersion(String version) {
    return 'Version $version';
  }

  @override
  String storeUpdateNewVersionAvailable(String storeName) {
    return 'A new version of the app is available in $storeName.';
  }

  @override
  String get storeUpdateWhatsNew => 'What\'s new:';

  @override
  String get storeUpdateRequired => 'This is a required update';

  @override
  String storeUpdateGoTo(String storeName) {
    return 'Go to $storeName';
  }

  @override
  String get storeUpdateButton => 'UPDATE';

  @override
  String get storeUpdateDownloaded => 'Update downloaded';

  @override
  String get storeUpdateReadyToInstall =>
      'Update downloaded and ready to install.\nInstall now? The app will be restarted.';

  @override
  String get storeUpdateInstall => 'INSTALL';

  @override
  String get storeUpdateDownloading => 'Downloading update...';

  @override
  String get storeUpdateReadyShort => 'Update ready to install';

  @override
  String get versionConflictTitle => 'Version conflict';

  @override
  String get versionConflictDescription =>
      'A version conflict has been detected.';

  @override
  String get versionConflictCurrent => 'Current version';

  @override
  String get versionConflictFound => 'Found version';

  @override
  String get versionConflictChooseAction => 'Choose an action:';

  @override
  String get versionConflictOpenFolder => 'Open in folder';

  @override
  String get versionConflictPreviousVersion => 'Previous version';

  @override
  String get versionConflictContinue => 'Continue';

  @override
  String get restoreLoadingBackups => 'Loading backups...';

  @override
  String get restoreSearchingBackups => 'Searching backups...';

  @override
  String restoreLoadError(String error) {
    return 'Load error: $error';
  }

  @override
  String get restoreRestoring => 'Restoring...';

  @override
  String get restoreRestoreError => 'Restore error';

  @override
  String get restoreRestoreFailed => 'Failed to restore from backup';

  @override
  String get restoreTitle => 'Restore';

  @override
  String get restoreChooseMethod => 'Choose setup method';

  @override
  String get restoreSetupNewPos => 'Set up new POS';

  @override
  String get restoreNoBackups => 'No backups found';

  @override
  String get restoreSetupAsNew => 'Set up POS as new';

  @override
  String get restoreFoundBackups => 'Found backups:';

  @override
  String get agentSearchByNameOrPhone => 'Search by name or phone...';

  @override
  String get agentOnlyWithDebt => 'Only with debt';

  @override
  String get agentTypeTooltip => 'Type';

  @override
  String agentBinLabel(String bin) {
    return 'BIN: $bin';
  }

  @override
  String agentSelectedMessage(String name) {
    return 'Selected: $name';
  }

  @override
  String agentFoundCount(int count) {
    return 'Found: $count';
  }

  @override
  String get agentEnterNameOrPhoneToSearch => 'Enter name or phone to search';

  @override
  String get agentNotFound => 'No clients found';

  @override
  String get agentSearchClients => 'Search clients';

  @override
  String get agentNotFoundShort => 'Not found';

  @override
  String get agentEnterNameOrPhone => 'Enter name or phone';

  @override
  String get agentEnterCustomerName => 'Enter customer name';

  @override
  String get agentDeletedCustomerPhone =>
      'Customer with this phone was deleted';

  @override
  String get agentWantRestore => 'Do you want to restore?';

  @override
  String get agentDeleteCustomerTitle => 'Delete customer?';

  @override
  String agentDeleteConfirmMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String agentCustomerDeleted(String name) {
    return 'Customer \"$name\" deleted';
  }

  @override
  String get cashOpTitle => 'Cash operation';

  @override
  String get cashOpComment => 'Comment';

  @override
  String get cashOpCommentRequired => 'Comment *';

  @override
  String get cashOpCommentHint => 'Enter comment...';

  @override
  String cashOpError(String error) {
    return 'Error: $error';
  }

  @override
  String get cashOpOperationType => 'Operation type';

  @override
  String get cashOpExpense => 'Expense';

  @override
  String get cashOpDividend => 'Withdrawal';

  @override
  String get saleReceiptTotal => 'Receipt total';

  @override
  String get salePay => 'PAY';

  @override
  String get saleTotalColon => 'Total:';

  @override
  String salePositionsAndQuantity(int count, String qty) {
    return '$count items / $qty pcs.';
  }

  @override
  String get saleWholesale => 'WHOLESALE';

  @override
  String get saleRetail => 'Retail';

  @override
  String get syncPreparing => 'Preparing...';

  @override
  String errorSaveFailed(String details) {
    return 'Save error: $details';
  }

  @override
  String get errorSaveFailedGeneric => 'Save error';

  @override
  String errorLoadFailed(String details) {
    return 'Data loading error: $details';
  }

  @override
  String get errorLoadFailedGeneric => 'Data loading error';

  @override
  String errorSearchFailed(String details) {
    return 'Search error: $details';
  }

  @override
  String get errorSearchFailedGeneric => 'Search error';

  @override
  String get errorUnknownGeneric => 'Unknown error';

  @override
  String get errorFillRequired => 'Fill in all required fields';

  @override
  String get errorNoUsers => 'No registered users';

  @override
  String get errorSelectUser => 'Select a user';

  @override
  String get errorPinTooShort => 'Enter PIN (minimum 4 digits)';

  @override
  String get errorRsaNotConfigured =>
      'Error: RSA key not configured. Contact administrator.';

  @override
  String get errorWrongPin => 'Incorrect PIN';

  @override
  String get errorAmbiguousPin =>
      'This PIN matches more than one cashier. Select your name and log in with it.';

  @override
  String get errorNoPinSet =>
      'No PIN is set for this cashier. Ask an administrator to set one.';

  @override
  String get errorWalkUpDisabled =>
      'Signing in without picking a name is disabled at this point. Select your name from the list.';

  @override
  String get errorCredentialUnreadable =>
      'The PIN record is corrupted. Contact an administrator — retyping the PIN will not help.';

  @override
  String get errorAuthUnknown =>
      'The till could not answer the login attempt. Try again.';

  @override
  String get errorTillNotConfigured =>
      'The till is not set up yet — sign-in is unavailable until the setup wizard has run.';

  @override
  String get errorTerminalLimitReached =>
      'This till already has the maximum number of terminals. Ask an administrator to free up a slot.';

  @override
  String get errorPairingCodeInvalid =>
      'The pairing code did not work — it may be expired, already used, or mistyped. Get a new code from the till operator.';

  @override
  String get errorTerminalSecretInvalid =>
      'This device\'s pairing is no longer valid — the terminal may have been removed on the till. Enter a new pairing code.';

  @override
  String get errorSessionExpired => 'Your session has expired — sign in again.';

  @override
  String get errorSessionEnded =>
      'Your session was ended by the till — sign in again.';

  @override
  String get errorSaleNotInitialized => 'Sale not initialized';

  @override
  String get errorReceiptEmpty => 'Receipt is empty';

  @override
  String get errorDeferredNotFound => 'Deferred receipt not found';

  @override
  String errorReceiptNotFound(String receiptNo) {
    return 'Receipt #$receiptNo not found';
  }

  @override
  String get errorReceiptNotFoundGeneric => 'Receipt not found';

  @override
  String get errorNotAuthorized => 'User not authorized';

  @override
  String get errorSupplierNotFound => 'Supplier not found';

  @override
  String get errorAccountNotFound => 'Account not found';

  @override
  String errorProductNotFound(String details) {
    return 'Product not found: $details';
  }

  @override
  String get errorProductNotFoundGeneric => 'Product not found';

  @override
  String get errorNameRequired => 'Name is required';

  @override
  String get errorNameTooShort => 'Minimum 2 characters';

  @override
  String get errorPhoneInvalid => 'Invalid phone format';

  @override
  String get errorBinInvalid => 'BIN/IIN must contain 12 digits';

  @override
  String get errorPhoneExists => 'Customer with this phone already exists';

  @override
  String errorShiftOpenFailed(String details) {
    return 'Shift opening error: $details';
  }

  @override
  String get errorShiftOpenFailedGeneric => 'Shift opening error';

  @override
  String errorShiftCloseFailed(String details) {
    return 'Shift closing error: $details';
  }

  @override
  String get errorShiftCloseFailedGeneric => 'Shift closing error';

  @override
  String errorShiftLoadFailed(String details) {
    return 'Shift data loading error: $details';
  }

  @override
  String get errorShiftLoadFailedGeneric => 'Shift data loading error';

  @override
  String get errorPaymentConfig =>
      'Failed to create payment. Check account settings.';

  @override
  String get errorSaleSaveFailed => 'Sale save error';

  @override
  String get errorInventoryCannotComplete => 'Cannot complete';

  @override
  String get errorNoProducts => 'No products to write off';

  @override
  String get errorSelectCountry => 'Select a country';

  @override
  String get errorEnterOrgName => 'Enter organization name';

  @override
  String errorEnterTaxId(String label) {
    return 'Enter $label';
  }

  @override
  String get errorEnterTaxIdGeneric => 'Enter tax ID';

  @override
  String errorTaxIdLength(String info) {
    return '$info';
  }

  @override
  String get errorTaxIdLengthGeneric => 'Invalid tax ID length';

  @override
  String get errorEnterPosName => 'Enter POS name';

  @override
  String get errorFillWebkassa => 'Fill in all WebKassa fields';

  @override
  String get errorFillOfd => 'Fill in all OFD fields';

  @override
  String get errorEnterKaspiIp => 'Enter Kaspi terminal IP address';

  @override
  String get errorEnterAdminName => 'Enter administrator name';

  @override
  String get errorAdminPinShort =>
      'Administrator PIN must contain at least 4 digits';

  @override
  String get errorSellerPinShort => 'Seller PIN must contain at least 4 digits';

  @override
  String errorCheckFailed(String details) {
    return 'Validation error: $details';
  }

  @override
  String get errorCheckFailedGeneric => 'Validation error';

  @override
  String get errorTelegramNotInitialized =>
      'TelegramInitializer not initialized';

  @override
  String get errorTelegramAuthNotInitialized =>
      'TelegramAuthService not initialized';

  @override
  String errorPhoneSendFailed(String details) {
    return 'Phone number send error: $details';
  }

  @override
  String get errorPhoneSendFailedGeneric => 'Phone number send error';

  @override
  String errorQrAuthFailed(String details) {
    return 'QR authorization error: $details';
  }

  @override
  String get errorQrAuthFailedGeneric => 'QR authorization error';

  @override
  String errorWrongCode(String details) {
    return 'Incorrect code: $details';
  }

  @override
  String get errorWrongCodeGeneric => 'Incorrect code';

  @override
  String errorWrongPassword(String details) {
    return 'Incorrect password: $details';
  }

  @override
  String get errorWrongPasswordGeneric => 'Incorrect password';

  @override
  String errorRegistrationFailed(String details) {
    return 'Registration error: $details';
  }

  @override
  String get errorRegistrationFailedGeneric => 'Registration error';

  @override
  String errorChannelSearchFailed(String details) {
    return 'Channel search error: $details';
  }

  @override
  String get errorChannelSearchFailedGeneric => 'Channel search error';

  @override
  String errorChannelConnectFailed(String details) {
    return 'Channel connection error: $details';
  }

  @override
  String get errorChannelConnectFailedGeneric => 'Channel connection error';

  @override
  String errorChannelCreateFailed(String details) {
    return 'Channel creation error: $details';
  }

  @override
  String get errorChannelCreateFailedGeneric => 'Channel creation error';

  @override
  String get errorFillClientData => 'Fill in client data';

  @override
  String get shiftCashInvestments => 'Cash in';

  @override
  String get shiftCashExpenses => 'Expenses';

  @override
  String get shiftCashDividends => 'Cash out';

  @override
  String get shiftNoCashOps => 'No cash operations';

  @override
  String get shiftNoCashOpsDescription =>
      'Cash in, expenses and cash out\nwill be displayed here';

  @override
  String shiftMoreItems(int count) {
    return '+$count more';
  }

  @override
  String get shiftEqualsSystem => '= System';

  @override
  String get shiftBillsTotal => 'Bills total:';

  @override
  String get receiptInputTitle => 'Find receipt';

  @override
  String get receiptInputNumber => 'Receipt number';

  @override
  String get receiptInputNumberHint => 'For example: 12345';

  @override
  String get receiptInputPos => 'POS';

  @override
  String get receiptInputInvalid => 'Enter a valid receipt number';

  @override
  String get receiptInputFind => 'Find';

  @override
  String get paymentDenominations => 'Denominations';

  @override
  String get paymentExactAmount => 'Exact amount';

  @override
  String get paymentNumpad => 'Numpad';

  @override
  String get paymentIinLabel => 'IIN/BIN (optional)';

  @override
  String get paymentIinInvalid => 'Invalid IIN/BIN';

  @override
  String get paymentIinHint =>
      'IIN — for individuals, BIN — for legal entities';

  @override
  String get paymentIinShort => 'IIN/BIN';

  @override
  String get paymentTypeCash => 'Cash';

  @override
  String get paymentTypeCard => 'Card';

  @override
  String get paymentTypeMixed => 'Mixed';

  @override
  String get paymentAccount => 'Account';

  @override
  String get authNoUsers => 'No registered users';

  @override
  String get authNoPin => 'No PIN';

  @override
  String get authSelectUser => 'Select user';

  @override
  String get authNoUsersShort => 'No users';

  @override
  String get authEnterPin => 'Enter PIN';

  @override
  String updateVersion(String version) {
    return 'Version $version';
  }

  @override
  String get updateWhatsNew => 'What\'s new';

  @override
  String get updateFixedIssues => 'Fixed';

  @override
  String get updateSize => 'Size';

  @override
  String get updateDate => 'Date';

  @override
  String get updateMandatory => 'This is a mandatory update';

  @override
  String updateLaterCountdown(int countdown) {
    return 'Later ($countdown)';
  }

  @override
  String get updateDownloading => 'Downloading update';

  @override
  String get updateDownloadingFile => 'Downloading update file...';

  @override
  String get updatePosNow => 'UPDATE POS';

  @override
  String get serviceAddNote => 'Add note';

  @override
  String get serviceClientLookup => 'Client lookup';

  @override
  String serviceOrderDetail(int orderId) {
    return 'Service order details #$orderId';
  }

  @override
  String get paymentDefaultLabel => 'Default';

  @override
  String get currencySymbol => '₸';

  @override
  String get serviceIntakeTitle => 'Service intake';

  @override
  String get serviceIntakeClient => 'Client';

  @override
  String get serviceIntakeDevice => 'Device / Item';

  @override
  String get serviceIntakeServices => 'Services';

  @override
  String get serviceIntakeDelivery => 'Delivery';

  @override
  String get serviceIntakePickup => 'Pick up from client';

  @override
  String get serviceIntakeSave => 'Save';

  @override
  String get serviceIntakeCancel => 'Cancel';

  @override
  String get serviceQueueTitle => 'Service orders';

  @override
  String get serviceQueueEmpty => 'No service orders';

  @override
  String get serviceQueueSearch => 'Search by number, client, device';

  @override
  String get serviceDetailTitle => 'Order details';

  @override
  String get serviceDetailInfo => 'Information';

  @override
  String get serviceDetailTimeline => 'Work log';

  @override
  String get serviceDetailCost => 'Cost';

  @override
  String get serviceDetailActions => 'Actions';

  @override
  String get serviceStatusIntake => 'Intake';

  @override
  String get serviceStatusInProgress => 'In progress';

  @override
  String get serviceStatusCompleted => 'Completed';

  @override
  String get serviceStatusClosed => 'Closed';

  @override
  String get serviceStatusCancelled => 'Cancelled';

  @override
  String get serviceMarkDiagnostic => 'Diagnostic';

  @override
  String get serviceMarkReplacement => 'Part replacement';

  @override
  String get serviceMarkRepair => 'Repair';

  @override
  String get serviceMarkTesting => 'Testing';

  @override
  String get serviceMarkOther => 'Other';

  @override
  String get serviceAddMark => 'Add work entry';

  @override
  String get serviceDeleteMark => 'Delete entry';

  @override
  String get serviceMarkDescription => 'Description';

  @override
  String get serviceMarkType => 'Work type';

  @override
  String get serviceMarkCost => 'Cost';

  @override
  String get serviceMarkNote => 'Note';

  @override
  String get serviceCatalogTitle => 'Service catalog';

  @override
  String get serviceCatalogAdd => 'Add service';

  @override
  String get serviceCatalogDuration => 'min';

  @override
  String get serviceCatalogWarranty => 'Warranty (days)';

  @override
  String get serviceCatalogRequiresDevice => 'Requires device';

  @override
  String get serviceClientNew => 'New client';

  @override
  String get serviceClientPhone => 'Phone';

  @override
  String get serviceClientName => 'Name';

  @override
  String get serviceClientAddress => 'Address';

  @override
  String get serviceAssignTechnician => 'Assign technician';

  @override
  String get serviceReassignTechnician => 'Reassign technician';

  @override
  String serviceTechnicianAssigned(String name) {
    return 'Technician assigned: $name';
  }

  @override
  String get serviceTechnicianSelect => 'Select technician';

  @override
  String get servicePrepayment => 'Prepayment';

  @override
  String get servicePrepaymentAmount => 'Prepayment amount';

  @override
  String get serviceEstimatedDate => 'Estimated date';

  @override
  String get serviceEstimatedAmount => 'Amount';

  @override
  String get servicePrintLabel => 'QR label';

  @override
  String get servicePrintReceipt => 'Print receipt';

  @override
  String get serviceProgressConfirm => 'Start work';

  @override
  String get serviceCancelConfirm => 'Cancel';

  @override
  String get serviceTotalCost => 'Work cost';

  @override
  String get servicePrepaid => 'Prepaid';

  @override
  String get serviceRemaining => 'To pay';

  @override
  String get serviceDeliveryAddress => 'Delivery address';

  @override
  String get serviceNeedsPickup => 'Pick up from client';

  @override
  String get serviceNeedsDelivery => 'Deliver to client';

  @override
  String serviceQrFormat(Object id, Object number) {
    return 'TELEPOS:SO:$id:$number';
  }

  @override
  String get serviceOrderCreated => 'New order';

  @override
  String get serviceOrderUpdated => 'Edit';

  @override
  String get serviceNoOrders => 'No data';

  @override
  String get serviceFilterAll => 'All';

  @override
  String get navCatalog => 'Catalog';

  @override
  String get catalogTitle => 'Product Catalog';

  @override
  String get catalogSearch => 'Search';

  @override
  String get catalogSearchHint => 'Name or barcode';

  @override
  String get catalogFilterAll => 'All';

  @override
  String get catalogFilterProducts => 'Products';

  @override
  String get catalogFilterWeighted => 'Weighted';

  @override
  String get catalogFilterServices => 'Services';

  @override
  String get catalogFilterPackages => 'Packages';

  @override
  String get catalogAddProduct => 'Add product';

  @override
  String get catalogEditProduct => 'Edit product';

  @override
  String get catalogDeleteProduct => 'Delete product';

  @override
  String get catalogRestoreProduct => 'Restore product';

  @override
  String get catalogProductName => 'Name';

  @override
  String get catalogBarcode => 'Barcode';

  @override
  String get catalogType => 'Type';

  @override
  String get catalogPrice => 'Selling price';

  @override
  String get catalogWholesalePrice => 'Wholesale price';

  @override
  String get catalogCategory => 'Category';

  @override
  String get catalogMeasure => 'Unit of measure';

  @override
  String get catalogQuantity => 'Stock';

  @override
  String get catalogQuickProduct => 'Quick product';

  @override
  String get catalogAddToQuick => 'Add to quick products';

  @override
  String get catalogRemoveFromQuick => 'Remove from quick products';

  @override
  String get catalogNoProducts => 'No products';

  @override
  String get catalogDeleted => 'Deleted';

  @override
  String catalogConfirmDelete(String name) {
    return 'Delete product \"$name\"?';
  }

  @override
  String get catalogProductCreated => 'Product created';

  @override
  String get catalogProductUpdated => 'Product updated';

  @override
  String get catalogProductDeleted => 'Product deleted';

  @override
  String get catalogProductRestored => 'Product restored';

  @override
  String get catalogShowDeleted => 'Show deleted';

  @override
  String get catalogTypeNormal => 'Normal';

  @override
  String get catalogTypeWeight => 'Weighted';

  @override
  String get catalogTypeInner => 'Inner';

  @override
  String get catalogTypePackage => 'Package';

  @override
  String get catalogTypeService => 'Service';

  @override
  String get catalogMeasurePiece => 'Piece';

  @override
  String get catalogMeasureKg => 'Kilogram';

  @override
  String get catalogMeasureLiter => 'Liter';

  @override
  String get catalogMeasureMeter => 'Meter';

  @override
  String get catalogNameRequired => 'Enter product name';

  @override
  String get catalogPriceRequired => 'Enter price';

  @override
  String get catalogPriceInvalid => 'Price must be greater than 0';

  @override
  String get catalogBarcodeExists => 'Product with this barcode already exists';

  @override
  String get catalogCategories => 'Categories';

  @override
  String get catalogAllCategories => 'All categories';

  @override
  String get catalogNoCategories => 'No categories';

  @override
  String get catalogQuickProductCategory => 'Quick product category';

  @override
  String get catalogAddCategory => 'Add category';

  @override
  String get catalogCategoryName => 'Category name';

  @override
  String get catalogManageCategories => 'Manage categories';

  @override
  String get catalogCategoryHasProducts =>
      'Cannot delete: category has products';

  @override
  String get catalogConfirmDeleteCategory => 'Delete category';

  @override
  String get catalogMenuCategories => 'Menu categories';

  @override
  String get catalogParentCategory => 'Parent category';

  @override
  String get catalogRootCategory => 'Root (no parent)';

  @override
  String get telegramErrorPhoneSendFailed => 'Failed to send verification code';

  @override
  String get telegramErrorQrAuthFailed => 'QR code authorization failed';

  @override
  String get telegramErrorWrongCode => 'Wrong verification code';

  @override
  String get telegramErrorWrongPassword => 'Wrong password';

  @override
  String get telegramErrorRegistrationFailed => 'Registration failed';

  @override
  String get telegramErrorChannelSearchFailed => 'Channel search failed';

  @override
  String get telegramErrorChannelConnectFailed =>
      'Failed to connect to channels';

  @override
  String get telegramErrorChannelCreateFailed => 'Failed to create channels';

  @override
  String get hwSettingsTitle => 'Hardware';

  @override
  String get hwSettingsSubtitle => 'Scanner, display, terminals';

  @override
  String get terminalServiceTitle => 'Browser terminals';

  @override
  String get terminalServiceSubtitle => 'A tablet or a phone as a workstation';

  @override
  String get terminalServiceEnable => 'Serve browser terminals';

  @override
  String get terminalServiceEnabledNote =>
      'The till listens on the shop network. Terminals can connect.';

  @override
  String get terminalServiceDisabledNote =>
      'The till listens to itself only. No port is open to the network, and terminals cannot connect.';

  @override
  String get terminalServiceRestartNote =>
      'The change takes effect after the till is restarted.';

  @override
  String get terminalServiceAddress => 'Address for the terminal';

  @override
  String get terminalServiceAddressHint =>
      'Open this address in the tablet\'s browser. If the name does not resolve, type the till\'s IP address.';

  @override
  String get pairingTitle => 'Terminal pairing';

  @override
  String get pairingSubtitle => 'Code for a new device';

  @override
  String get pairingDisabledNote =>
      'The till does not serve browser terminals. Turn on serving to issue a pairing code.';

  @override
  String get pairingDisabledAction => 'Open terminal settings';

  @override
  String get pairingAddressLabel => 'Link for the new device';

  @override
  String get pairingAddressHint =>
      'Type or copy this address exactly on the new device — the code is already in it.';

  @override
  String get pairingLinkPending =>
      'The link appears here once you issue a code.';

  @override
  String get pairingRestartNote =>
      'Terminal service is on in settings, but this till has not restarted with it yet — the address will not answer. Restart the till.';

  @override
  String get pairingMint => 'Issue code';

  @override
  String get pairingMintAgain => 'Issue a new code';

  @override
  String get pairingCodeLabel => 'Pairing code';

  @override
  String pairingExpiresAt(String time) {
    return 'Valid until $time';
  }

  @override
  String get pairingOnceNote =>
      'The code is shown only now — leaving this screen loses it. Issuing a new code revokes this one if it has not been used yet. This code is spent by opening the link — the device itself will then ask for a second, separate code: issue a new one when it does.';

  @override
  String get enrolTitle => 'Terminal pairing';

  @override
  String get enrolInstructions =>
      'This device is not paired with the till yet. Ask the operator to open \"Terminal pairing\" on the till and enter the code shown there.';

  @override
  String get enrolCodeLabel => 'Pairing code';

  @override
  String get enrolSubmit => 'Pair';

  @override
  String get accountsSettingsTitle => 'Payment Accounts';

  @override
  String get accountsSettingsSubtitle => 'Cash and card accounts for payments';

  @override
  String get accountsSettingsAdd => 'Add Account';

  @override
  String get accountsSettingsEdit => 'Edit Account';

  @override
  String get accountsSettingsEmpty => 'No payment accounts configured';

  @override
  String get accountsSettingsName => 'Account Name';

  @override
  String get accountsSettingsType => 'Account Type';

  @override
  String get accountsSettingsTypePOS => 'POS (cash register)';

  @override
  String get accountsSettingsTypeBank => 'Bank (card)';

  @override
  String get accountsSettingsTypeCash => 'Cash';

  @override
  String get accountsSettingsTypeSystem => 'System';

  @override
  String get accountsSettingsTypeBonus => 'Bonus';

  @override
  String get accountsSettingsTypeOther => 'Other';

  @override
  String get accountsSettingsBalance => 'Balance';

  @override
  String get accountsSettingsVisible => 'POS';

  @override
  String get accountsSettingsVisibleToPos => 'Visible in POS';

  @override
  String get hwSettingsSaved => 'Hardware settings saved';

  @override
  String get hwScannerTitle => 'Barcode Scanner';

  @override
  String get hwScannerMode => 'Scanner Mode';

  @override
  String get hwScannerModeKeyboard => 'USB / keyboard (wedge)';

  @override
  String get hwScannerModeSerial => 'Serial';

  @override
  String get hwScannerModeCamera => 'Camera';

  @override
  String get hwScannerModeHint => 'USB scanners work in this mode';

  @override
  String get hwScannerTimeout => 'Timeout';

  @override
  String get hwScannerMinLength => 'Min length';

  @override
  String get hwScannerMaxLength => 'Max length';

  @override
  String get hwDisplayTitle => 'Customer Display';

  @override
  String get hwDisplayModel => 'Model';

  @override
  String get hwDisplayModelLed8 => 'LED 8 chars';

  @override
  String get hwDisplayModelVfd20 => 'VFD 20x2';

  @override
  String get hwDisplayPort => 'COM Port';

  @override
  String get hwDisplayBaudRate => 'Baud Rate';

  @override
  String get hwDisplayDisabled => 'Customer display disabled';

  @override
  String get hwDrawerTitle => 'Cash Drawer';

  @override
  String get hwDrawerMode => 'Open Mode';

  @override
  String get hwDrawerModePrinter => 'Via Printer';

  @override
  String get hwDrawerModeSerial => 'Serial Port';

  @override
  String get hwDrawerPort => 'COM Port';

  @override
  String get hwTerminalsTitle => 'Payment Terminals';

  @override
  String get hwTerminalIp => 'IP Address';

  @override
  String get hwTerminalPort => 'Port';

  @override
  String get hwTerminalMerchantId => 'Merchant ID';

  @override
  String get hwTerminalTerminalId => 'Terminal ID';

  @override
  String get catalogExportCsv => 'Export CSV';

  @override
  String get catalogImport => 'Import';

  @override
  String get catalogFilterColumn => 'Filter...';

  @override
  String catalogExportSuccess(String path) {
    return 'Exported to $path';
  }

  @override
  String get catalogExportFailed => 'Export failed';

  @override
  String get catalogImportResults => 'Import Results';

  @override
  String catalogImportImported(int count) {
    return 'Imported: $count';
  }

  @override
  String catalogImportUpdated(int count) {
    return 'Updated: $count';
  }

  @override
  String catalogImportSkipped(int count) {
    return 'Skipped: $count';
  }

  @override
  String get catalogImportErrors => 'Errors:';

  @override
  String get catalogTypeConsumable => 'Consumable';

  @override
  String get catalogFilterConsumable => 'Consumables';

  @override
  String get catalogFilterInner => 'Internal';

  @override
  String get serviceMarkConsumable => 'Consumable material';

  @override
  String get serviceConsumableSearch => 'Search product / consumable';

  @override
  String get serviceConsumableSelected => 'Selected product';

  @override
  String get serviceQuickServicesTitle => 'Quick services';

  @override
  String get serviceQuickServicesEmpty => 'No quick services';

  @override
  String get serviceIntakeItems => 'Items received';

  @override
  String get serviceItemName => 'What are you accepting (item, thing, device)';

  @override
  String get serviceItemDescription => 'Problem description / client wishes';

  @override
  String get serviceItemSerial => 'Serial number / marking';

  @override
  String get serviceItemAdd => 'Add item';

  @override
  String get serviceItemEmpty => 'Add at least one item';

  @override
  String serviceItemCount(int count) {
    return '$count pcs.';
  }

  @override
  String get serviceClientQuickName => 'Client name';

  @override
  String get serviceClientQuickPhone => 'Client phone';

  @override
  String get serviceClientOrSearch => 'or find in database';

  @override
  String get catalogTypeDish => 'Dish';

  @override
  String get catalogFilterDish => 'Dishes';

  @override
  String get dishCalculation => 'Costing';

  @override
  String get dishCalculationStub => 'Costing module will be available later';

  @override
  String get dishIngredients => 'Ingredients';

  @override
  String get serviceConsumablesTitle => 'Consumption norms';

  @override
  String get serviceConsumablesEmpty => 'No consumable materials';

  @override
  String get serviceConsumablesAdd => 'Add consumable';

  @override
  String get serviceConsumableQuantity => 'Qty per 1 service';

  @override
  String get serviceConsumablesAutoAdded => 'Consumables added automatically';

  @override
  String get catalogDescription => 'Description';

  @override
  String get catalogImagePlaceholder => 'Tap to upload photo';

  @override
  String get catalogImageFromGallery => 'Choose from gallery';

  @override
  String get catalogImageFromCamera => 'Take a photo';

  @override
  String get catalogImageRemove => 'Remove photo';

  @override
  String get catalogImagePickError => 'Failed to load photo';

  @override
  String get globalRetry => 'Retry';

  @override
  String get globalRefresh => 'Refresh';

  @override
  String get globalReset => 'Reset';

  @override
  String get globalApply => 'Apply';

  @override
  String get globalCreate => 'Create';

  @override
  String get stockOpSupply => 'Receipt';

  @override
  String get stockOpMovement => 'Transfer';

  @override
  String get stockOpSupplierReturn => 'Return to supplier';

  @override
  String get stockOpMovementShort => 'Transfer';

  @override
  String get stockOpReturnShort => 'Return';

  @override
  String get stockRegistryTitle => 'Stock operations';

  @override
  String get stockRegistryAppBarTitle => 'Warehouse';

  @override
  String get stockRegistryLoadError => 'Failed to load the registry';

  @override
  String get stockRegistryResetFilters => 'Reset filters';

  @override
  String get stockRegistryFilters => 'Filters';

  @override
  String get stockRegistryEmpty => 'No records';

  @override
  String get stockRegistryEmptyFiltered => 'Adjust the filter parameters';

  @override
  String get stockRegistryEmptyCreate => 'Create your first stock operation';

  @override
  String get stockRegistryPeriod => 'Period';

  @override
  String get stockRegistryOperationType => 'Operation type';

  @override
  String get stockRegistrySearchHint => 'Search by number, counterparty...';

  @override
  String get stockRegistryDateFrom => 'From';

  @override
  String get stockRegistryDateTo => 'To';

  @override
  String get stockRegistryColType => 'Type';

  @override
  String get stockRegistryColNumber => 'Number';

  @override
  String get stockRegistryColCounterparty => 'Counterparty / Warehouse';

  @override
  String get stockRegistryColProducts => 'Items';

  @override
  String get stockRegistryColStatus => 'Status';

  @override
  String get stockSyncDraft => 'Draft';

  @override
  String get stockSyncPending => 'Pending';

  @override
  String get stockSyncSending => 'Sending';

  @override
  String get stockSyncSynced => 'Synced';

  @override
  String stockRegistryDetailType(String type) {
    return 'Type: $type';
  }

  @override
  String stockRegistryDetailDate(String date) {
    return 'Date: $date';
  }

  @override
  String stockRegistryDetailCounterparty(String name) {
    return 'Counterparty: $name';
  }

  @override
  String stockRegistryDetailAmount(String amount) {
    return 'Amount: $amount';
  }

  @override
  String stockRegistryDetailProducts(int count) {
    return 'Items: $count';
  }

  @override
  String stockRegistryDetailComment(String comment) {
    return 'Comment: $comment';
  }

  @override
  String stockRegistryProductsShort(int count) {
    return '$count pcs';
  }

  @override
  String stockRegistryPaginationRange(int from, int to, int total) {
    return '$from–$to of $total';
  }

  @override
  String get stockCreateSupplyTitle => 'New receipt';

  @override
  String get stockCreateSupplySubtitle => 'Receive goods from a supplier';

  @override
  String get stockCreateMovementSubtitle => 'Transfer between warehouses';

  @override
  String get stockCreateReturnSubtitle => 'Return goods to the supplier';

  @override
  String get stockCreateWriteoffSubtitle =>
      'Write off goods (breakage, spoilage, expiry)';

  @override
  String get stockCreateInventorySubtitle => 'Recount actual stock';

  @override
  String get serviceQueueActive => 'Active';

  @override
  String get serviceScanQrTitle => 'Scan order QR code';

  @override
  String get serviceScanQrHint => 'TELEPOS:SO:... or order number';

  @override
  String get serviceIntakePhotos => 'Intake photos';

  @override
  String get serviceIntakePhotosHint =>
      'Take photos of the items being received';

  @override
  String get expenseTypeOther => 'Other';

  @override
  String get expenseTypeSmallPurchases => 'Small purchases';

  @override
  String get expenseTypeSalary => 'Salary';

  @override
  String get expenseTypeUtilities => 'Utilities';

  @override
  String get expenseTypeCollection => 'Cash collection';

  @override
  String get expenseTypeCustom => 'Custom';

  @override
  String get networkTitle => 'Network & Connections';

  @override
  String get networkUnavailableTitle => 'Available only on a TelePOS OS device';

  @override
  String get networkUnavailableDesc =>
      'The telepos-sysd system daemon was not found. Network management works only when the POS runs on a TelePOS OS appliance.';

  @override
  String get networkRefresh => 'Refresh';

  @override
  String get networkSearch => 'Search';

  @override
  String get networkConnect => 'Connect';

  @override
  String get networkDisconnect => 'Disconnect';

  @override
  String get networkConnected => 'Connected';

  @override
  String get networkEthernetTitle => 'Wired network (Ethernet)';

  @override
  String get networkEthernetDesc =>
      'Cable connection status and internet access.';

  @override
  String get networkCableLabel => 'Cable';

  @override
  String get networkCableConnected => 'Connected';

  @override
  String get networkCableNotConnected => 'Not connected';

  @override
  String get networkInternetLabel => 'Internet';

  @override
  String get networkInternetAvailable => 'Available';

  @override
  String get networkInternetUnavailable => 'No access';

  @override
  String get networkWifiTitle => 'Wi-Fi';

  @override
  String get networkWifiDesc => 'Connect to a wireless network.';

  @override
  String get networkWifiSearchHint => 'Tap \"Search\" to find networks.';

  @override
  String get networkBluetoothTitle => 'Bluetooth';

  @override
  String get networkBluetoothDesc =>
      'Pair with printers, scales and other devices.';

  @override
  String get networkBluetoothSearchHint => 'Tap \"Search\" to find devices.';

  @override
  String get networkBluetoothUnavailableInBrowser =>
      'Not available in the browser — Bluetooth is configured on the till itself only.';

  @override
  String networkWifiPasswordTitle(String ssid) {
    return 'Password for \"$ssid\"';
  }

  @override
  String get networkWifiPasswordLabel => 'Wi-Fi password';

  @override
  String networkConnectedTo(String ssid) {
    return 'Connected to $ssid';
  }

  @override
  String networkConnectFailed(String ssid) {
    return 'Could not connect to $ssid';
  }

  @override
  String networkPaired(String device) {
    return 'Paired: $device';
  }

  @override
  String get networkPairFailed => 'Pairing failed';

  @override
  String get networkEthernetConfigure => 'Настроить';

  @override
  String get networkEthernetConfigTitle => 'Настройка Ethernet';

  @override
  String get networkEthernetInterface => 'Интерфейс';

  @override
  String get networkEthernetCurrentIp => 'Текущий IP';

  @override
  String get networkEthernetMode => 'Способ получения адреса';

  @override
  String get networkEthernetModeDhcp => 'Автоматически (DHCP)';

  @override
  String get networkEthernetModeStatic => 'Вручную (статический)';

  @override
  String get networkEthernetIpLabel => 'IP-адрес';

  @override
  String get networkEthernetPrefixLabel => 'Префикс (маска)';

  @override
  String get networkEthernetGatewayLabel => 'Шлюз';

  @override
  String get networkEthernetDnsLabel => 'DNS-сервер';

  @override
  String get networkEthernetApply => 'Применить';

  @override
  String get networkEthernetApplied => 'Настройки сети применены';

  @override
  String get networkEthernetApplyFailed =>
      'Не удалось применить настройки сети';

  @override
  String get networkEthernetNoInterface => 'Интерфейс Ethernet не определён';

  @override
  String get networkEthernetInvalidIp => 'Неверный IP-адрес';

  @override
  String get networkEthernetInvalidGateway => 'Неверный адрес шлюза';

  @override
  String get networkEthernetInvalidDns => 'Неверный адрес DNS';

  @override
  String get networkEthernetInvalidPrefix => 'Префикс должен быть от 0 до 32';

  @override
  String get networkEthernetIpRequired => 'Укажите IP-адрес';

  @override
  String get networkEthernetOptional => 'необязательно';

  @override
  String get applianceTitle => 'System (TelePOS OS)';

  @override
  String get applianceHubSubtitle => 'System management, network, drivers';

  @override
  String get applianceUnavailableDesc =>
      'The telepos-sysd system daemon was not found. This section works only when the POS runs on a TelePOS OS appliance.';

  @override
  String get applianceNetworkTitle => 'Network & Connections';

  @override
  String get applianceNetworkDesc =>
      'Wi-Fi, wired network and Bluetooth. Required for login and sync.';

  @override
  String get applianceNetworkButton => 'Configure network';

  @override
  String get applianceDesktopTitle => 'Desktop mode';

  @override
  String get applianceDesktopDesc =>
      'Full desktop for installing apps and maintenance.';

  @override
  String get applianceCurrentMode => 'Current mode: ';

  @override
  String get applianceOpenDesktop => 'Open desktop';

  @override
  String get applianceDesktopUnavailable =>
      'Desktop is not available in this build.';

  @override
  String get applianceModeKiosk => 'POS (kiosk)';

  @override
  String get applianceModeDesktop => 'Desktop';

  @override
  String get applianceDriversTitle => 'Peripheral drivers';

  @override
  String get applianceDriversDesc =>
      'Install drivers for printers, scales and payment terminals from the trusted TelePOS catalog.';

  @override
  String get applianceDriversEmpty => 'Driver catalog is empty.';

  @override
  String get applianceDriverInstall => 'Install';

  @override
  String get applianceDriverRemove => 'Remove';

  @override
  String applianceDriverInstalled(String title) {
    return 'Driver installed: $title';
  }

  @override
  String applianceDriverRemoved(String title) {
    return 'Driver removed: $title';
  }

  @override
  String applianceError(String message) {
    return 'Error: $message';
  }

  @override
  String get navNetwork => 'Network';

  @override
  String get navCollapseMenu => 'Collapse menu';

  @override
  String get navExpandMenu => 'Expand menu';

  @override
  String get languageSwitcherTooltip => 'Language / Язык / Тіл';

  @override
  String get labelPrinterSettingsTitle => 'Label printer';

  @override
  String get labelPrinterSettingsSubtitle => 'Price tags and barcodes';

  @override
  String get labelPrinterLanguage => 'Printer language';

  @override
  String get labelPrinterSize => 'Label size';

  @override
  String get labelPrinterWidthMm => 'Width, mm';

  @override
  String get labelPrinterHeightMm => 'Height, mm';

  @override
  String get labelPrinterTestSuccess => 'Label sent to printer';

  @override
  String get labelPrinterNotConfigured =>
      'Label printer is not configured. Set the address in settings.';

  @override
  String get labelTemplatesTitle => 'Label templates';

  @override
  String get labelTemplatesManage => 'Manage templates';

  @override
  String get labelTemplatesManageSubtitle => 'Create and edit layouts';

  @override
  String get labelTemplatesEmpty => 'No templates found';

  @override
  String get labelTemplateNew => 'New template';

  @override
  String get labelTemplateEdit => 'Edit template';

  @override
  String get labelTemplateBuiltIn => 'Built-in';

  @override
  String get labelMmUnit => 'mm';

  @override
  String get labelTemplateDeleteTitle => 'Delete template';

  @override
  String labelTemplateDeleteConfirm(String name) {
    return 'Delete template \"$name\"?';
  }

  @override
  String get labelTemplateName => 'Template name';

  @override
  String get labelTemplateNameRequired => 'Enter a template name';

  @override
  String get labelTemplatePreview => 'Preview';

  @override
  String get labelTemplateFields => 'Fields';

  @override
  String get labelTemplateAddField => 'Add field';

  @override
  String get labelTemplateNoFields => 'No fields. Add at least one field.';

  @override
  String get labelFieldKind => 'Field type';

  @override
  String get labelFieldText => 'Text';

  @override
  String get labelFieldFontSize => 'Font';

  @override
  String get labelFieldBold => 'Bold';

  @override
  String get labelFieldKindName => 'Name';

  @override
  String get labelFieldKindPrice => 'Price';

  @override
  String get labelFieldKindBarcode => 'Barcode';

  @override
  String get labelFieldKindSku => 'SKU';

  @override
  String get labelFieldKindDate => 'Date';

  @override
  String get labelFieldKindText => 'Text';

  @override
  String get labelPrintTitle => 'Print price tag';

  @override
  String labelPrintBulkTitle(int count) {
    return 'Print price tags ($count)';
  }

  @override
  String get labelPrintChooseTemplate => 'Choose a template';

  @override
  String get labelPrintCopies => 'Copies';

  @override
  String get labelPrintAction => 'Print';

  @override
  String labelPrintedCount(int count) {
    return 'Printed: $count';
  }

  @override
  String get catalogPrintLabel => 'Print price tag';

  @override
  String get receiptTemplatesTitle => 'Receipt templates';

  @override
  String get receiptTemplatesSubtitle =>
      'Receipt layout: logo, header/footer, BIN, QR, width';

  @override
  String get receiptTemplatesEmpty => 'No templates found';

  @override
  String get receiptTemplateNew => 'New template';

  @override
  String get receiptTemplateEdit => 'Edit template';

  @override
  String get receiptTemplateBuiltIn => 'Built-in';

  @override
  String get receiptTemplateActive => 'Active';

  @override
  String get receiptTemplateMakeActive => 'Make active';

  @override
  String get receiptTemplateName => 'Template name';

  @override
  String get receiptTemplateNameRequired => 'Enter a template name';

  @override
  String get receiptTemplatePreview => 'Preview';

  @override
  String get receiptTemplatePaperWidth => 'Paper width';

  @override
  String get receiptTemplateContent => 'Receipt content';

  @override
  String get receiptTemplateHeaderFooter => 'Header and footer';

  @override
  String get receiptTemplateHeaderText => 'Header text';

  @override
  String get receiptTemplateFooterText => 'Footer text';

  @override
  String get receiptTemplateExtraFooter => 'Extra footer lines';

  @override
  String get receiptTemplateExtraFooterHint =>
      'One line each (e.g. return policy)';

  @override
  String get receiptTemplateShowBin => 'Print BIN/IIN';

  @override
  String get receiptTemplateShowAddress => 'Print address';

  @override
  String get receiptTemplateShowCashier => 'Print cashbox/cashier';

  @override
  String get receiptTemplateShowVat => 'Print VAT';

  @override
  String get receiptTemplateShowQr => 'Print verification link (QR)';

  @override
  String get receiptTemplateShowItemNumbers => 'Number items';

  @override
  String get receiptTemplateShowLogo => 'Print logo';

  @override
  String get receiptTemplateTestPrint => 'Test print';

  @override
  String get receiptTemplateTestPrintOk => 'Sample receipt sent to printer';

  @override
  String get receiptTemplateTestPrintFail => 'Print failed (check the printer)';

  @override
  String get receiptTemplateDeleteTitle => 'Delete template';

  @override
  String receiptTemplateDeleteConfirm(String name) {
    return 'Delete template \"$name\"?';
  }

  @override
  String get sysmTitle => 'System management';

  @override
  String get sysmHubSubtitle => 'Health, updates, backups, power';

  @override
  String get sysmOpenPanel => 'Open management panel';

  @override
  String get sysmNoData => 'No data';

  @override
  String get sysmGenericError => 'Operation failed';

  @override
  String get sysmHealthTitle => 'System health';

  @override
  String get sysmHealthDesc => 'CPU load, memory, disk, temperature and uptime';

  @override
  String get sysmCpu => 'CPU';

  @override
  String get sysmCores => 'cores';

  @override
  String get sysmRam => 'Memory';

  @override
  String get sysmMb => 'MB';

  @override
  String get sysmDisk => 'Disk';

  @override
  String get sysmGb => 'GB';

  @override
  String get sysmGbFree => 'GB free';

  @override
  String get sysmTemperature => 'Temperature';

  @override
  String get sysmUptime => 'Uptime';

  @override
  String get sysmDaysShort => 'd';

  @override
  String get sysmHoursShort => 'h';

  @override
  String get sysmMinsShort => 'm';

  @override
  String get sysmUpdateTitle => 'Software update';

  @override
  String get sysmUpdateDesc => 'Check for and install system updates';

  @override
  String get sysmCurrentVersion => 'Current version';

  @override
  String get sysmLatestVersion => 'Latest version';

  @override
  String get sysmUpdateAvailable => 'Update available';

  @override
  String get sysmCheckUpdate => 'Check';

  @override
  String get sysmUpdateNow => 'Update';

  @override
  String get sysmUpdateConfirm =>
      'The system will download and install the update. A reboot may be required afterwards. Continue?';

  @override
  String get sysmUpdateStarted => 'Update started';

  @override
  String get sysmUpdateFailed => 'Update failed';

  @override
  String get sysmUpdatePhaseDownload => 'Downloading update…';

  @override
  String get sysmUpdatePhaseApply => 'Installing update…';

  @override
  String get sysmRollback => 'Roll back version';

  @override
  String get sysmRollbackConfirm => 'Roll back to the previous system version?';

  @override
  String get sysmRollbackDone => 'Rollback complete';

  @override
  String get sysmBackupTitle => 'Backups';

  @override
  String get sysmBackupDesc => 'Create, restore and transfer backups via USB';

  @override
  String get sysmBackupEmpty => 'No backups';

  @override
  String get sysmBackupCreate => 'Create backup';

  @override
  String get sysmBackupCreated => 'Backup created';

  @override
  String get sysmBackupRestore => 'Restore';

  @override
  String sysmBackupRestoreConfirm(String name) {
    return 'Restore the system from backup \"$name\"? Current data will be replaced.';
  }

  @override
  String get sysmBackupRestored => 'Restore started';

  @override
  String get sysmBackupExport => 'To USB';

  @override
  String get sysmBackupExported => 'Backup exported to USB';

  @override
  String get sysmBackupImport => 'Import from USB';

  @override
  String get sysmBackupImported => 'Backup imported from USB';

  @override
  String get sysmSnapshotTitle => 'Snapshots & reset';

  @override
  String get sysmSnapshotDesc => 'System restore points and factory reset';

  @override
  String get sysmSnapshotUnsupported =>
      'Snapshots are not supported on this device';

  @override
  String get sysmSnapshotEmpty => 'No snapshots';

  @override
  String get sysmSnapshotCreate => 'Create snapshot';

  @override
  String get sysmSnapshotCreated => 'Snapshot created';

  @override
  String get sysmSnapshotRollback => 'Roll back';

  @override
  String sysmSnapshotRollbackConfirm(String name) {
    return 'Roll the system back to snapshot \"$name\"?';
  }

  @override
  String get sysmSnapshotRolledBack => 'Rolled back to snapshot';

  @override
  String get sysmSnapshotRebootRequired =>
      'Rollback complete. A reboot is required.';

  @override
  String get sysmFactoryReset => 'Factory reset';

  @override
  String get sysmFactoryResetWarn =>
      'Erases all data and settings, returning the device to factory state.';

  @override
  String get sysmFactoryResetConfirm1 =>
      'Factory reset will erase ALL data, settings and sales. This action is irreversible. Continue?';

  @override
  String get sysmFactoryResetConfirm2 =>
      'Are you sure? All data will be permanently erased. Confirm the factory reset.';

  @override
  String get sysmFactoryResetDo => 'Reset';

  @override
  String get sysmFactoryResetStarted => 'Factory reset started';

  @override
  String get sysmDisplayTitle => 'Display';

  @override
  String get sysmDisplayDesc => 'Screen brightness and rotation';

  @override
  String get sysmDisplayUnsupported =>
      'This device has no controllable screen (no backlight). Adjust brightness and rotation on the monitor itself.';

  @override
  String get sysmRotation => 'Screen rotation';

  @override
  String get sysmRemoteTitle => 'Remote support';

  @override
  String get sysmRemoteDesc => 'Temporary secure access for the support team';

  @override
  String get sysmRemoteHelp =>
      '“Restore support” opens a temporary, secure (SSH) channel for the TelePOS support team to reach this appliance and fix issues remotely. Access closes automatically after 30 minutes. Enable it only when support asks you to.';

  @override
  String get sysmRemoteOn => 'Access enabled';

  @override
  String get sysmRemoteOff => 'Access disabled';

  @override
  String sysmRemoteExpires(String minutes) {
    return 'Expires in $minutes min';
  }

  @override
  String get sysmRemoteEnable => 'Enable for 30 minutes';

  @override
  String get sysmRemoteEnabled => 'Remote access enabled';

  @override
  String get sysmRemoteDisable => 'Disable access';

  @override
  String get sysmRemoteDisabled => 'Remote access disabled';

  @override
  String get sysmPowerTitle => 'Power';

  @override
  String get sysmPowerDesc => 'Reboot and shut down the device';

  @override
  String get sysmReboot => 'Reboot';

  @override
  String get sysmRebootConfirm => 'Reboot the device now?';

  @override
  String get sysmRebooting => 'Rebooting…';

  @override
  String get sysmShutdown => 'Shut down';

  @override
  String get sysmShutdownConfirm => 'Shut down the device now?';

  @override
  String get sysmShuttingDown => 'Shutting down…';

  @override
  String get sysmTimeTitle => 'Time and timezone';

  @override
  String get sysmTimeDesc => 'Current time, timezone and NTP synchronization';

  @override
  String get sysmTimeCurrent => 'Current time';

  @override
  String get sysmTimezone => 'Timezone';

  @override
  String get sysmTimezoneSave => 'Save timezone';

  @override
  String get sysmTimezoneSaved => 'Timezone saved';

  @override
  String get sysmTimezoneSaveError => 'Failed to save timezone';

  @override
  String get sysmNtpSync => 'Sync time (NTP)';

  @override
  String get sysmNtpSyncing => 'Synchronizing…';

  @override
  String get sysmNtpDone => 'Time synchronized';

  @override
  String get sysmNtpFailed => 'Failed to synchronize time';

  @override
  String get sysmTerminalTitle => 'Terminal';

  @override
  String get sysmTerminalDesc =>
      'Appliance diagnostics and management (command line)';

  @override
  String get sysmTerminalOpen => 'Open terminal';

  @override
  String get sysmTerminalRootNote => 'Commands run as root on the appliance.';

  @override
  String get sysmTerminalHint =>
      'Enter a command (e.g.: systemctl status telepos-sysd)';

  @override
  String get sysmTerminalRun => 'Run';

  @override
  String get sysmTerminalClear => 'Clear output';

  @override
  String get sysmTerminalRunning => 'Running…';

  @override
  String sysmTerminalExitCode(int code) {
    return 'Exit code: $code';
  }

  @override
  String get sysmTerminalEmpty => 'Output will appear here';

  @override
  String get sysmTerminalHistory => 'Command history';

  @override
  String get sysmTerminalPresets => 'Presets';

  @override
  String get sysmTerminalPresetsNetwork => 'Network';

  @override
  String get sysmTerminalPresetsPrinters => 'Printers';

  @override
  String get sysmTerminalPresetsSystem => 'System';

  @override
  String get sysmTerminalPresetsTime => 'Time';

  @override
  String get sysmTermGroupDiagnostics => 'Diagnostics';

  @override
  String get sysmTermGroupPrinter => 'Printer';

  @override
  String get sysmTermGroupNetwork => 'Network';

  @override
  String get sysmTermGroupSystem => 'System';

  @override
  String get sysmTermGroupTime => 'Time';

  @override
  String get sysmTermDiagOsAndDaemon => 'OS and daemon version';

  @override
  String get sysmTermDiagNetworkStatus => 'Network: status and address';

  @override
  String get sysmTermDiagNetworkConnectivity => 'Network: connectivity';

  @override
  String get sysmTermDiagHardware => 'Hardware: disk/memory/printers';

  @override
  String get sysmTermPrinterFixAuto => 'Fix printer (auto)';

  @override
  String get sysmTermPrinterDiag => 'Printer diagnostics';

  @override
  String get sysmTermPrinterLoadUsblp => 'Load usblp module';

  @override
  String get sysmTermPrinterNodesAndPerms => 'Printer nodes and permissions';

  @override
  String get sysmTermPrinterLsusb => 'USB devices (lsusb)';

  @override
  String get sysmTermPrinterCupsStatus => 'CUPS: status and queues';

  @override
  String get sysmTermPrinterGiveToKernel => 'Hand printer to kernel (usblp)';

  @override
  String get sysmTermPrinterTestPrint => 'Test print to /dev/usb/lp0';

  @override
  String get sysmTermNetDeviceStatus => 'Device status';

  @override
  String get sysmTermNetIpAddresses => 'IP addresses';

  @override
  String get sysmTermNetConnectEthernet => 'Connect Ethernet';

  @override
  String get sysmTermNetReload => 'Reload network';

  @override
  String get sysmTermNetPing => 'Ping 8.8.8.8';

  @override
  String get sysmTermSysDisk => 'Disk';

  @override
  String get sysmTermSysMemory => 'Memory';

  @override
  String get sysmTermSysSysdStatus => 'telepos-sysd status';

  @override
  String get sysmTermSysKioskLogs => 'Kiosk logs';

  @override
  String get sysmTermTimeDateTime => 'Date and time';

  @override
  String get sysmTermTimeNtpSync => 'NTP sync';

  @override
  String get labelPrinterDevicePath => 'Device path';

  @override
  String get labelPrinterDevicePathHint =>
      'E.g. /dev/usb/lp0 (USB) or /dev/ttyUSB0 (Serial). Leave empty for the default.';

  @override
  String get movementTitle => 'Transfer';

  @override
  String get movementTitleFull => 'Stock transfer';

  @override
  String get movementFrom => 'From *';

  @override
  String get movementTo => 'To *';

  @override
  String get movementLocationHint => 'Warehouse / location name';

  @override
  String movementProductsCount(int count) {
    return 'Items: $count';
  }

  @override
  String movementSumLabel(String amount) {
    return 'Total: $amount';
  }

  @override
  String get movementAddProduct => 'Add product';

  @override
  String get movementBarcodeHint => 'Barcode or SKU';

  @override
  String get movementComment => 'Comment';

  @override
  String get movementCommentHint => 'Note for the transfer...';

  @override
  String get movementCommentHintShort => 'Note...';

  @override
  String get movementProductNotFound => 'Product not found';

  @override
  String movementSavedMessage(int count, String amount) {
    return 'Transfer saved: $count items for $amount';
  }

  @override
  String get movementCancelTitle => 'Cancel transfer?';

  @override
  String get movementCancelMessage => 'All unsaved data will be lost.';

  @override
  String get movementCancelConfirm => 'Yes, cancel';

  @override
  String movementProductFallback(String ucode) {
    return 'Product #$ucode';
  }

  @override
  String get movementPriceLabel => 'Price';

  @override
  String get movementSaveError => 'Save error';

  @override
  String get movementEmptyTitle => 'Add products to transfer';

  @override
  String get movementEmptyHint => 'Scan a barcode or enter manually';

  @override
  String get supplierReturnTitle => 'Return to supplier';

  @override
  String supplierReturnProductsCount(int count) {
    return 'Items: $count';
  }

  @override
  String supplierReturnSumLabel(String amount) {
    return 'Total: $amount';
  }

  @override
  String get supplierReturnSupplier => 'Supplier *';

  @override
  String get supplierReturnSelectSupplier => 'Select supplier';

  @override
  String get supplierReturnAccount => 'Return account';

  @override
  String get supplierReturnSelectAccount => 'Select account';

  @override
  String get supplierReturnAddProduct => 'Add product';

  @override
  String get supplierReturnBarcodeHint => 'Barcode or SKU';

  @override
  String get supplierReturnComment => 'Comment';

  @override
  String get supplierReturnCommentHint => 'Reason for return...';

  @override
  String get supplierReturnProductNotFound => 'Product not found';

  @override
  String supplierReturnSavedMessage(int count, String amount) {
    return 'Return saved: $count items for $amount';
  }

  @override
  String get supplierReturnCancelTitle => 'Cancel return?';

  @override
  String get supplierReturnCancelMessage => 'All unsaved data will be lost.';

  @override
  String get supplierReturnCancelConfirm => 'Yes, cancel';

  @override
  String supplierReturnProductFallback(String ucode) {
    return 'Product #$ucode';
  }

  @override
  String get supplierReturnNoSuppliers => 'No suppliers';

  @override
  String get supplierReturnNoAccounts => 'No accounts';

  @override
  String supplierReturnBalance(String amount) {
    return 'Balance: $amount';
  }

  @override
  String get supplierReturnPriceLabel => 'Price';

  @override
  String get supplierReturnSaveError => 'Save error';

  @override
  String get supplierReturnEmptyTitle => 'Add products to return';

  @override
  String get supplierReturnEmptyHint => 'Scan a barcode or enter manually';

  @override
  String get esfSettingsTitle => 'ESF (electronic invoices)';

  @override
  String get esfSettingsSubtitle => 'Requisites, digital signature, outbox';

  @override
  String get esfSettingsSave => 'Save';

  @override
  String get esfSettingsSaved => 'ESF settings saved';

  @override
  String get esfSettingsSaveError => 'Failed to save ESF settings';

  @override
  String get esfSettingsEnable => 'Enable ESF';

  @override
  String get esfSettingsEnableSubtitle =>
      'Build invoices for B2B sales (by buyer BIN)';

  @override
  String get esfSettingsOperator => 'ESF operator';

  @override
  String get esfSettingsTestMode => 'Test mode';

  @override
  String get esfSettingsSupplier => 'Supplier requisites (our organization)';

  @override
  String get esfSettingsBin => 'BIN/IIN';

  @override
  String get esfSettingsName => 'Name';

  @override
  String get esfSettingsAddress => 'Address';

  @override
  String get esfSettingsVatPayer => 'VAT payer';

  @override
  String get esfSettingsVatSeries => 'VAT certificate series';

  @override
  String get esfSettingsVatNumber => 'VAT certificate number';

  @override
  String get esfSettingsVatRate => 'VAT rate, %';

  @override
  String get esfSettingsEcp => 'Digital signature (NCA RK)';

  @override
  String get esfSettingsEcpKeyPath => 'Signature key path';

  @override
  String get esfSettingsEcpKeyAlias => 'Key alias';

  @override
  String get esfSettingsB2bOnly => 'B2B only';

  @override
  String get esfSettingsB2bOnlySubtitle =>
      'Do not build ESF for retail sales to individuals';

  @override
  String get esfSettingsEcpHint =>
      'Real issuance requires an NCA RK signature and an IS ESF profile. Drafts are built and stored offline without a signature.';

  @override
  String get esfSettingsWebkassaNote =>
      'Issuance credentials (signature, connection, token) come from WebKassa (Fiscal) settings — one shared config. No separate ESF credentials are needed here.';

  @override
  String get esfOutboxTitle => 'ESF outbox';

  @override
  String get esfOutboxEmpty => 'No ESF documents';

  @override
  String get esfOutboxEmptyHint => 'Invoices will appear here after B2B sales';

  @override
  String get esfOutboxRetry => 'Retry submission';

  @override
  String get esfOutboxRetryAll => 'Retry all';

  @override
  String esfOutboxRetryDone(int delivered, int queued, int failed) {
    return 'Processed: delivered $delivered, queued $queued, failed $failed';
  }

  @override
  String get esfOutboxStatusDraft => 'Draft';

  @override
  String get esfOutboxStatusQueued => 'Queued';

  @override
  String get esfOutboxStatusSubmitted => 'Submitted';

  @override
  String get esfOutboxStatusDelivered => 'Registered';

  @override
  String get esfOutboxStatusRejected => 'Rejected';

  @override
  String get esfOutboxStatusRevoked => 'Revoked';

  @override
  String get esfOutboxStatusError => 'Error';

  @override
  String esfOutboxAttempts(int count) {
    return 'Attempts: $count';
  }

  @override
  String esfOutboxRegNumber(String number) {
    return 'Reg. no.: $number';
  }

  @override
  String get sntTitle => 'SNT (goods transport notices)';

  @override
  String get sntSubtitle => 'Virtual warehouse, goods movement';

  @override
  String get sntEmpty => 'No SNT documents';

  @override
  String get sntEmptyHint =>
      'SNT are built automatically after receiving traceable goods';

  @override
  String get sntRefresh => 'Refresh queue';

  @override
  String sntDrainDone(int submitted, int remaining, int failed) {
    return 'Processed: submitted $submitted, queued $remaining, failed $failed';
  }

  @override
  String get sntDirectionInbound => 'Inbound';

  @override
  String get sntDirectionOutbound => 'Outbound';

  @override
  String get sntStatusDraft => 'Draft';

  @override
  String get sntStatusQueued => 'Queued';

  @override
  String get sntStatusRegistered => 'Registered';

  @override
  String get sntStatusDelivered => 'Delivered';

  @override
  String get sntStatusConfirmed => 'Confirmed';

  @override
  String get sntStatusRejected => 'Rejected';

  @override
  String get sntStatusRevoked => 'Revoked';

  @override
  String get sntStatusAnnulled => 'Annulled';

  @override
  String get sntStatusFailed => 'Failed';

  @override
  String sntLinesCount(int count) {
    return 'Lines: $count';
  }

  @override
  String sntRegNumber(String number) {
    return 'Reg. no.: $number';
  }

  @override
  String get sntNotConfigured =>
      'SNT / Virtual warehouse not configured. Documents are stored locally and will be submitted after the signature is set up.';

  @override
  String get sntConfigure => 'Configure SNT';

  @override
  String get sntSettingsTitle => 'SNT settings';

  @override
  String get sntSettingsOperator => 'Operator / submission method';

  @override
  String get sntSettingsEnable => 'Enable SNT';

  @override
  String get sntSettingsEnableSubtitle =>
      'Assemble and submit accompanying waybills (IS ESF)';

  @override
  String get sntSettingsProvider => 'Submission method';

  @override
  String get sntSettingsTestMode => 'Test mode';

  @override
  String get sntSettingsRequisites => 'Taxpayer details';

  @override
  String get sntSettingsOwnBin => 'BIN / IIN (ours)';

  @override
  String get sntSettingsWarehouseCode => 'Virtual warehouse code';

  @override
  String get sntSettingsBackend => 'TelePOS backend (IS ESF proxy)';

  @override
  String get sntSettingsBackendUrl => 'Backend URL';

  @override
  String get sntSettingsApiKey => 'API key';

  @override
  String get sntSettingsEcp => 'Digital signature (NUC RK)';

  @override
  String get sntSettingsCertPath => 'Signature key path';

  @override
  String get sntSettingsCertPassword => 'Key password';

  @override
  String get sntSettingsEcpHint =>
      'Real SNT submission requires a NUC RK digital signature and a registered IS ESF profile. Without a signature, documents are assembled and stored locally (the Virtual warehouse works offline).';

  @override
  String get sntSettingsSharedEsfHint =>
      'SNT and ESF are KGD subsystems. The BIN and signature can be configured on the ESF screen.';

  @override
  String get sntSettingsWebkassaNote =>
      'Connection credentials (login, apiKey, cashbox, signature) come from WebKassa (Fiscal) settings — one shared config.';

  @override
  String get sntSettingsOpenEsf => 'ESF settings';

  @override
  String get sntSettingsSave => 'Save';

  @override
  String get sntSettingsSaved => 'SNT settings saved';

  @override
  String get sntSettingsSaveError => 'Failed to save SNT settings';

  @override
  String get sntSettingsBinRequired => 'Enter the taxpayer\'s BIN / IIN';

  @override
  String get esutdTitle => 'ESUTD (e-waybills)';

  @override
  String get esutdSubtitle => 'Goods transport waybills (e-waybill)';

  @override
  String get esutdNotConfigured =>
      'ESUTD is not configured. Enter portal credentials to load waybills.';

  @override
  String get esutdNotConfiguredShort => 'ESUTD is not configured';

  @override
  String get esutdConfigure => 'Configure ESUTD';

  @override
  String get esutdRefresh => 'Refresh';

  @override
  String get esutdInbound => 'Inbound waybills';

  @override
  String get esutdOutbound => 'Outbound waybills';

  @override
  String get esutdEmpty => 'No waybills';

  @override
  String esutdWaybillNumber(String number) {
    return 'Waybill No. $number';
  }

  @override
  String esutdCargoCount(int count) {
    return 'Cargo items: $count';
  }

  @override
  String get esutdSettingsTitle => 'ESUTD settings';

  @override
  String get esutdSettingsConnection => 'Connection';

  @override
  String get esutdSettingsEnable => 'Enable ESUTD';

  @override
  String get esutdSettingsEnableSubtitle =>
      'Load and submit e-waybills (esutd.gov.kz)';

  @override
  String get esutdSettingsCredentials => 'Portal credentials';

  @override
  String get esutdSettingsEmail => 'Email (portal login)';

  @override
  String get esutdSettingsPassword => 'Password';

  @override
  String get esutdSettingsApiUrl => 'API URL (optional)';

  @override
  String get esutdSettingsApiUrlHint =>
      'Leave empty for the default: https://esutd.gov.kz/api';

  @override
  String get esutdSettingsTestLogin => 'Test login / Sign in';

  @override
  String get esutdSettingsSessionActive => 'Session active';

  @override
  String get esutdSettingsLoginOk => 'Signed in to ESUTD';

  @override
  String esutdSettingsLoginError(String error) {
    return 'Login failed: $error';
  }

  @override
  String get esutdSettingsCredsRequired =>
      'Enter the ESUTD portal email and password';

  @override
  String get esutdSettingsSave => 'Save';

  @override
  String get esutdSettingsSaved => 'ESUTD settings saved';

  @override
  String get esutdSettingsSaveError => 'Failed to save ESUTD settings';

  @override
  String get esutdSettingsHint =>
      'ESUTD has no public API. The integration uses the portal\'s internal endpoints: a login/password sign-in yields a session that is reused and auto-refreshed. Creating/approving waybills requires complex reference data (KATO, product classifier, carriers) and is not yet available from the POS.';

  @override
  String get ismptSettingsTitle => 'IS MPT settings';

  @override
  String get ismptSettingsSubtitle => 'Marking (Honest Sign KZ)';

  @override
  String get ismptSettingsOperator => 'Operator / submission method';

  @override
  String get ismptSettingsEnable => 'Enable IS MPT';

  @override
  String get ismptSettingsEnableSubtitle =>
      'Verify and submit marking codes (ismet.kz / Tañba)';

  @override
  String get ismptSettingsBackend => 'Backend';

  @override
  String get ismptSettingsTestMode => 'Test mode';

  @override
  String get ismptSettingsRequisites => 'Taxpayer details';

  @override
  String get ismptSettingsOwnBin => 'BIN / IIN (ours)';

  @override
  String get ismptSettingsApi => 'True API (ismet.kz)';

  @override
  String get ismptSettingsApiUrl => 'API URL';

  @override
  String get ismptSettingsApiKey => 'API key / token';

  @override
  String get ismptSettingsEcp => 'Digital signature (NUC RK)';

  @override
  String get ismptSettingsCertPath => 'Signature key path';

  @override
  String get ismptSettingsCertPassword => 'Key password';

  @override
  String get ismptSettingsEcpHint =>
      'Live IS MPT operations require an NUC RK digital signature and a registered participant profile. Without a signature, marking codes are accepted and stored locally (receiving works offline, sales are never blocked).';

  @override
  String get ismptSettingsSharedEsfHint =>
      'IS MPT and ESF are KGD subsystems. BIN and digital signature can be configured on the ESF screen.';

  @override
  String get ismptSettingsWebkassaNote =>
      'Marking-code verification runs through WebKassa. Connection credentials (login, apiKey, cashbox, signature) come from WebKassa (Fiscal) settings — one shared config.';

  @override
  String get ismptSettingsOpenEsf => 'ESF settings';

  @override
  String get ismptSettingsSave => 'Save';

  @override
  String get ismptSettingsSaved => 'IS MPT settings saved';

  @override
  String get ismptSettingsSaveError => 'Failed to save IS MPT settings';

  @override
  String get ismptSettingsBinRequired => 'Enter the taxpayer\'s BIN / IIN';

  @override
  String get reorderRulesTitle => 'Reorder rules';

  @override
  String get reorderRulesSubtitle => 'Minimum stock per product';

  @override
  String get reorderRulesEmpty => 'No reorder rules';

  @override
  String get reorderRulesEmptyHint =>
      'Set a minimum stock per product to get reorder signals';

  @override
  String get reorderRulesAdd => 'Add rule';

  @override
  String get reorderRulesMinStock => 'Minimum stock';

  @override
  String get reorderRulesReorderQty => 'Order quantity';

  @override
  String get reorderRulesProduct => 'Product (ucode)';

  @override
  String get reorderRulesProductHint => 'Product code';

  @override
  String get reorderRulesSave => 'Save';

  @override
  String get reorderRulesSaved => 'Rule saved';

  @override
  String get reorderRulesInvalid => 'Specify product code and minimum stock';

  @override
  String reorderRulesBelowPoint(int count) {
    return 'Below reorder point: $count';
  }

  @override
  String get reorderRulesEditTitle => 'Reorder rule';

  @override
  String get supplierOrderRuleBased => 'By reorder rules';

  @override
  String supplierOrderGlobalThreshold(String threshold) {
    return 'Global threshold ($threshold)';
  }

  @override
  String get catalogPageFirst => 'First';

  @override
  String get catalogPagePrev => 'Previous';

  @override
  String get catalogPageNext => 'Next';

  @override
  String get catalogPageLast => 'Last';

  @override
  String get catalogGoToPage => 'Go to page';

  @override
  String catalogPageOf(int total) {
    return 'Page of $total';
  }

  @override
  String get shiftClosedGateTitle => 'Shift is closed';

  @override
  String get shiftClosedGateMessage =>
      'Open a shift to continue with operations.';

  @override
  String get shiftClosedGateOpen => 'Open shift';

  @override
  String get sysmTerminalPresetsDiag => 'Diagnostics';

  @override
  String get wmsDashboardTitle => 'WMS — Warehouse management';

  @override
  String get wmsDashboardTitleShort => 'WMS — Warehouse';

  @override
  String get wmsSettings => 'WMS settings';

  @override
  String get wmsSettingsSubtitle => 'Module configuration';

  @override
  String get wmsModuleWarehouses => 'Warehouses';

  @override
  String get wmsModuleWarehousesSubtitle => 'Warehouses, zones, cells';

  @override
  String get wmsModuleBatches => 'Batches';

  @override
  String get wmsModuleBatchesSubtitle => 'Batch tracking';

  @override
  String get wmsModuleCellStock => 'Cell stock';

  @override
  String get wmsModuleCellStockSubtitle => 'Stock, placement, picking';

  @override
  String get wmsModuleSerials => 'Serial tracking';

  @override
  String get wmsModuleSerialsSubtitle => 'Serial numbers';

  @override
  String get wmsModuleMarking => 'Marking';

  @override
  String get wmsModuleMarkingSubtitle => 'Marking codes';

  @override
  String get wmsModuleClaims => 'Claims';

  @override
  String get wmsModuleClaimsSubtitle => 'Claims and returns';

  @override
  String get wmsWarehousesAndCells => 'Warehouses and cells';

  @override
  String get wmsWarehouses => 'Warehouses';

  @override
  String get wmsAddWarehouse => 'Add warehouse';

  @override
  String get wmsNoWarehouses => 'No warehouses';

  @override
  String get wmsNoName => 'No name';

  @override
  String get wmsZones => 'Zones';

  @override
  String wmsZonesNamed(String name) {
    return 'Zones: $name';
  }

  @override
  String get wmsAddZone => 'Add zone';

  @override
  String get wmsSelectWarehouse => 'Select warehouse';

  @override
  String get wmsNoZones => 'No zones';

  @override
  String get wmsCells => 'Cells';

  @override
  String wmsCellsNamed(String name) {
    return 'Cells: $name';
  }

  @override
  String get wmsGenerate => 'Generate';

  @override
  String get wmsSelectZone => 'Select zone';

  @override
  String get wmsNoCells => 'No cells';

  @override
  String get wmsNoAddress => 'No address';

  @override
  String get wmsCellBlocked => 'Blocked';

  @override
  String wmsCellsCount(int count) {
    return '$count cells';
  }

  @override
  String get wmsNewWarehouse => 'New warehouse';

  @override
  String get wmsWarehouseCode => 'Warehouse code';

  @override
  String get wmsName => 'Name';

  @override
  String get wmsError => 'Error';

  @override
  String get wmsCreate => 'Create';

  @override
  String get wmsSelectWarehouseFirst => 'Select a warehouse first';

  @override
  String get wmsNewZone => 'New zone';

  @override
  String get wmsZoneCode => 'Zone code';

  @override
  String get wmsSelectZoneFirst => 'Select a zone first';

  @override
  String get wmsGenerateCells => 'Generate cells';

  @override
  String get wmsRows => 'Rows';

  @override
  String get wmsRacks => 'Racks';

  @override
  String get wmsLevels => 'Levels';

  @override
  String get wmsBins => 'Bins';

  @override
  String get wmsEditWarehouse => 'Edit warehouse';

  @override
  String get wmsAddress => 'Address';

  @override
  String get wmsDeleteWarehouseTitle => 'Delete warehouse?';

  @override
  String wmsDeleteWarehouseConfirm(String name) {
    return 'Are you sure you want to delete the warehouse \"$name\"?';
  }

  @override
  String get wmsCellStockTitle => 'Cell stock';

  @override
  String get wmsPlace => 'Place';

  @override
  String get wmsPick => 'Pick';

  @override
  String get wmsTransfer => 'Transfer';

  @override
  String get wmsByCell => 'By cell';

  @override
  String get wmsByProduct => 'By product';

  @override
  String get wmsSearchCellHint => 'Enter cell ID or address...';

  @override
  String get wmsSearchProductHint => 'Enter product ucode...';

  @override
  String get wmsCell => 'Cell';

  @override
  String get wmsProductUcode => 'Product code (ucode)';

  @override
  String get wmsFind => 'Find';

  @override
  String get wmsEnterCellIdToSearch => 'Enter a cell ID to search stock';

  @override
  String get wmsEnterUcodeToSearch => 'Enter a product ucode to search';

  @override
  String wmsProductLabeled(String value) {
    return 'Product: $value';
  }

  @override
  String wmsCellLabeled(String value) {
    return 'Cell: $value';
  }

  @override
  String wmsStockSummary(String qty, String reserved, String available) {
    return 'Qty: $qty  |  Reserved: $reserved  |  Available: $available';
  }

  @override
  String wmsBatchLabeled(String value) {
    return 'Batch: $value';
  }

  @override
  String get wmsQuantityShort => 'Qty';

  @override
  String get wmsReserved => 'Reserved';

  @override
  String get wmsAvailable => 'Available';

  @override
  String get wmsBatch => 'Batch';

  @override
  String get wmsEnterNumericId => 'Enter a numeric ID';

  @override
  String get wmsPlaceStockTitle => 'Place stock in cell';

  @override
  String get wmsCellId => 'Cell ID';

  @override
  String get wmsProductUcodeField => 'Product ucode';

  @override
  String get wmsQuantity => 'Quantity';

  @override
  String get wmsBatchIdOptional => 'Batch ID (optional)';

  @override
  String get wmsFillRequiredNumericFields =>
      'Fill in the required fields (numeric values)';

  @override
  String wmsStockPlaced(String cellId) {
    return 'Stock placed in cell $cellId';
  }

  @override
  String get wmsPlaceError => 'Placement error';

  @override
  String get wmsPickStockTitle => 'Pick stock from cell';

  @override
  String get wmsFillAllNumericFields => 'Fill in all fields (numeric values)';

  @override
  String wmsStockPicked(String cellId) {
    return 'Stock picked from cell $cellId';
  }

  @override
  String get wmsPickError => 'Picking error';

  @override
  String get wmsTransferStockTitle => 'Transfer stock';

  @override
  String get wmsCellIdFrom => 'Cell ID (from)';

  @override
  String get wmsCellIdTo => 'Cell ID (to)';

  @override
  String wmsStockTransferred(String from, String to) {
    return 'Stock transferred from cell $from to $to';
  }

  @override
  String get wmsTransferError => 'Transfer error';

  @override
  String get wmsBatches => 'Batches';

  @override
  String get wmsBatchTrackingTitle => 'Batch tracking';

  @override
  String get wmsBatchTabAll => 'All batches';

  @override
  String get wmsBatchTabExpiring => 'Expiring';

  @override
  String get wmsBatchTabExpired => 'Expired';

  @override
  String get wmsBatchTabQuarantine => 'Quarantine';

  @override
  String get wmsNoBatches => 'No batches';

  @override
  String get wmsNoExpiringBatches => 'No expiring batches';

  @override
  String get wmsNoExpiredBatches => 'No expired batches';

  @override
  String get wmsNoQuarantinedBatches => 'No quarantined batches';

  @override
  String get wmsSearchByUcodeHint => 'Search by product ucode...';

  @override
  String get wmsNoNumber => 'No number';

  @override
  String wmsBatchCardSummary(String ucode, String expiry, String qty) {
    return 'Product: $ucode  |  Expiry: $expiry  |  Qty: $qty';
  }

  @override
  String get wmsBatchNumber => 'Batch number';

  @override
  String get wmsProduct => 'Product';

  @override
  String get wmsExpiryDate => 'Expiry date';

  @override
  String get wmsStatus => 'Status';

  @override
  String get wmsActions => 'Actions';

  @override
  String get wmsQuarantine => 'Quarantine';

  @override
  String get wmsApprove => 'Approve';

  @override
  String get wmsStatusQuarantine => 'Quarantine';

  @override
  String get wmsStatusExpired => 'Expired';

  @override
  String get wmsStatusExpiring => 'Expiring';

  @override
  String get wmsStatusOk => 'OK';

  @override
  String get wmsMoveToQuarantine => 'Move to quarantine';

  @override
  String wmsBatchQuarantined(String number) {
    return 'Batch $number moved to quarantine';
  }

  @override
  String wmsBatchApproved(String number) {
    return 'Batch $number approved';
  }

  @override
  String get wmsSearchBatchesByProduct => 'Search batches by product';

  @override
  String get wmsEnterProductCode => 'Enter product code';

  @override
  String get wmsSerialTrackingTitle => 'Serial tracking';

  @override
  String get wmsScan => 'Scan';

  @override
  String get wmsSearchBySerialHint => 'Search by serial number...';

  @override
  String get wmsNothingFound => 'Nothing found';

  @override
  String get wmsEnterSerialToSearch => 'Enter a serial number to search';

  @override
  String get wmsRegister => 'Register';

  @override
  String get wmsSelectSerial => 'Select a serial number';

  @override
  String get wmsSerialNumber => 'Serial number';

  @override
  String get wmsLocation => 'Location';

  @override
  String wmsCellHash(String id) {
    return 'Cell #$id';
  }

  @override
  String get wmsDetails => 'Details';

  @override
  String get wmsMarking => 'Marking';

  @override
  String get wmsWarrantyUntil => 'Warranty until';

  @override
  String get wmsNotes => 'Notes';

  @override
  String get wmsMovementHistory => 'Movement history';

  @override
  String get wmsNoData => 'No data';

  @override
  String get wmsSerialStatusInStock => 'In stock';

  @override
  String get wmsSerialStatusSold => 'Sold';

  @override
  String get wmsSerialStatusReturned => 'Returned';

  @override
  String get wmsSerialStatusWrittenOff => 'Written off';

  @override
  String get wmsSerialStatusUnknown => 'Unknown';

  @override
  String get wmsScannerUseHardware => 'Scanner: use a hardware scanner';

  @override
  String get wmsRegisterSerialTitle => 'Register serial number';

  @override
  String get wmsSerialRegistered => 'Serial number registered';

  @override
  String get wmsMarkingCodesTitle => 'Marking codes';

  @override
  String get wmsMarkingAccept => 'Receive';

  @override
  String get wmsRefresh => 'Refresh';

  @override
  String get wmsIsMptSettings => 'IS MPT settings';

  @override
  String get wmsMarkingAcceptTitle => 'Receive marking codes';

  @override
  String get wmsSupplyIdOptional => 'Supply ID (optional)';

  @override
  String get wmsMarkingCodesPerLine => 'Marking codes (one per line)';

  @override
  String get wmsAccept => 'Accept';

  @override
  String get wmsNoCodesEntered => 'No codes entered';

  @override
  String wmsAcceptedLocally(String count) {
    return 'Accepted locally: $count (IS MPT — deferred)';
  }

  @override
  String wmsAccepted(String count) {
    return 'Accepted: $count';
  }

  @override
  String wmsAcceptError(String error) {
    return 'Receiving error: $error';
  }

  @override
  String wmsMarkingStatusResult(String status) {
    return 'Marking code status: $status';
  }

  @override
  String get wmsInCirculation => '(in circulation)';

  @override
  String get wmsIsMptNoConnection =>
      'No connection to IS MPT — verification deferred';

  @override
  String get wmsVerifyUnavailable =>
      'Verification unavailable (IS MPT not configured)';

  @override
  String wmsVerifyError(String error) {
    return 'Verification error: $error';
  }

  @override
  String get wmsNoMarkingCodes => 'No marking codes';

  @override
  String get wmsVerifyStatus => 'Verify status (IS MPT)';

  @override
  String get wmsMarkingStatusReceived => 'Received';

  @override
  String get wmsMarkingStatusInStock => 'In stock';

  @override
  String get wmsMarkingStatusSold => 'Sold';

  @override
  String get wmsMarkingStatusReturned => 'Returned';

  @override
  String get wmsMarkingStatusRetired => 'Written off';

  @override
  String get wmsMarkingStatusBlocked => 'Blocked';

  @override
  String get wmsClaims => 'Claims';

  @override
  String get wmsClaimTabOpen => 'Open';

  @override
  String get wmsClaimTabInProgress => 'In progress';

  @override
  String get wmsClaimTabResolved => 'Resolved';

  @override
  String get wmsNoOpenClaims => 'No open claims';

  @override
  String get wmsNoInProgressClaims => 'No claims in progress';

  @override
  String get wmsNoResolvedClaims => 'No resolved claims';

  @override
  String get wmsNewClaim => 'New claim';

  @override
  String get wmsNumber => 'Number';

  @override
  String get wmsType => 'Type';

  @override
  String get wmsSeverity => 'Severity';

  @override
  String get wmsDate => 'Date';

  @override
  String get wmsSeverityLow => 'Low';

  @override
  String get wmsSeverityMedium => 'Medium';

  @override
  String get wmsSeverityHigh => 'High';

  @override
  String get wmsSeverityCritical => 'Critical';

  @override
  String get wmsClaimTypeDefect => 'Defect';

  @override
  String get wmsClaimTypeMissort => 'Missort';

  @override
  String get wmsClaimTypeShortage => 'Shortage';

  @override
  String get wmsClaimTypeDamage => 'Damage';

  @override
  String get wmsClaimTypeOther => 'Other';

  @override
  String get wmsProblemDescription => 'Problem description';

  @override
  String get wmsClaimCreated => 'Claim created';

  @override
  String wmsClaimTitle(String number) {
    return 'Claim $number';
  }

  @override
  String wmsTypeLabeled(String value) {
    return 'Type: $value';
  }

  @override
  String wmsSeverityLabeled(String value) {
    return 'Severity: $value';
  }

  @override
  String wmsDateLabeled(String value) {
    return 'Date: $value';
  }

  @override
  String get wmsProblemDescriptionLabel => 'Problem description:';

  @override
  String get wmsNoDescription => 'No description';

  @override
  String get wmsResolutionLabel => 'Resolution:';

  @override
  String get wmsNotSpecified => 'Not specified';

  @override
  String get wmsHistoryLabel => 'History:';

  @override
  String get wmsNoRecords => 'No records';

  @override
  String get wmsResolve => 'Resolve';

  @override
  String get wmsResolveClaimTitle => 'Resolve claim';

  @override
  String get wmsResolutionNotes => 'Resolution notes';

  @override
  String get wmsClaimResolved => 'Claim resolved';

  @override
  String get setUserManagementTitle => 'Users and access';

  @override
  String get setUsersTitle => 'Users';

  @override
  String get setUsersSubtitle => 'Access management';

  @override
  String get authSettingsTitle => 'Login and session';

  @override
  String get authSettingsSubtitle => 'Walk-up login and session length';

  @override
  String get authSettingsWalkUpTitle => 'Login without picking a cashier';

  @override
  String get authSettingsWalkUpSubtitle =>
      'One PIN lets anyone in without a name. Unsafe with several cashiers: off by default.';

  @override
  String get authSettingsSessionTitle => 'Session length';

  @override
  String get authSettingsSessionSubtitle =>
      'How many minutes a cashier\'s session stays open without activity. Applies right away, no restart needed.';

  @override
  String get authSettingsSessionMinutesLabel => 'Minutes';

  @override
  String get authSettingsSaved => 'Saved';

  @override
  String get authSettingsInvalidMinutes =>
      'Enter a whole number of minutes from 1 to 1440';

  @override
  String get sessionsTitle => 'Active sessions';

  @override
  String get sessionsSubtitle => 'Who is logged in now, revoke with a button';

  @override
  String get sessionsEmpty => 'Nobody is logged in right now';

  @override
  String sessionsTerminalLabel(String id) {
    return 'Terminal #$id';
  }

  @override
  String sessionsTimes(String issued, String expires) {
    return 'Logged in $issued · expires $expires';
  }

  @override
  String get sessionsRevoke => 'End session';

  @override
  String get sessionsRevokeConfirmTitle => 'End this session?';

  @override
  String sessionsRevokeConfirmBody(String name) {
    return '«$name» will be logged out immediately.';
  }

  @override
  String sessionsRevoked(String name) {
    return 'Session for «$name» ended';
  }

  @override
  String sessionsRevokeError(String error) {
    return 'Could not end the session: $error';
  }

  @override
  String get setUsersEmpty => 'No users';

  @override
  String get setAddUser => 'Add user';

  @override
  String setUserNumber(String id) {
    return 'User #$id';
  }

  @override
  String get setUserActive => 'Active';

  @override
  String setUsersLoadError(String error) {
    return 'Error: $error';
  }

  @override
  String get setNewUser => 'New user';

  @override
  String get setEditUser => 'Edit';

  @override
  String get setUserTabProfile => 'Profile';

  @override
  String get setUserTabPermissions => 'Permissions';

  @override
  String get setUserName => 'Name';

  @override
  String get setUserNameRequired => 'Enter a name';

  @override
  String get setUserPinLabel => 'PIN (4-6 digits)';

  @override
  String get setUserPinRequired => 'Enter a PIN';

  @override
  String get setUserPinMin => 'At least 4 digits';

  @override
  String get setUserPinRange => 'PIN must be 4-6 digits';

  @override
  String get setUserRole => 'Role';

  @override
  String get setRoleOwner => 'Owner';

  @override
  String get setRoleAdministrator => 'Administrator';

  @override
  String get setRoleUser => 'User';

  @override
  String get setRoleCashier => 'Cashier';

  @override
  String get setUserActiveDesc => 'User can sign in';

  @override
  String get setUserBlockedDesc => 'Access blocked';

  @override
  String get setUserOwnerFullAccess => 'Owner has full access';

  @override
  String get setUserSelectAll => 'Select all';

  @override
  String get setUserDeselectAll => 'Deselect all';

  @override
  String get setDeleteUserTitle => 'Delete user?';

  @override
  String setDeleteUserConfirm(String name) {
    return 'User \"$name\" will be deleted. This action cannot be undone.';
  }

  @override
  String setDeleteUserError(String error) {
    return 'Failed to delete user: $error';
  }

  @override
  String get setUserNoEncryptionKey =>
      'Encryption key is not set. Complete the initial POS setup.';

  @override
  String get setUserPinEncryptFailed => 'Failed to encrypt PIN';

  @override
  String get setWmsTitle => 'WMS settings';

  @override
  String get setWmsModules => 'WMS modules';

  @override
  String get setWmsCellStorage => 'Bin storage';

  @override
  String get setWmsCellStorageDesc =>
      'Addressed storage of goods by zones and bins';

  @override
  String get setWmsBatchTracking => 'Batch tracking';

  @override
  String get setWmsBatchTrackingDesc =>
      'Track goods by batch with supply tracing';

  @override
  String get setWmsSerialTracking => 'Serial tracking';

  @override
  String get setWmsSerialTrackingDesc =>
      'Per-unit tracking by unique serial numbers';

  @override
  String get setWmsExpiryControl => 'Expiry control';

  @override
  String get setWmsExpiryControlDesc =>
      'Expiry warnings and automatic FEFO picking';

  @override
  String get setWmsMarking => 'Marking';

  @override
  String get setWmsMarkingDesc =>
      'Support for mandatory marking codes (DataMatrix, GS1)';

  @override
  String get setWmsWarranty => 'Warranty tracking';

  @override
  String get setWmsWarrantyDesc => 'Track warranty periods by serial numbers';

  @override
  String get setWmsPickingStrategy => 'Picking strategy';

  @override
  String get setWmsPickingStrategyDesc =>
      'Defines the order goods are shipped from the warehouse';

  @override
  String get setWmsStrategy => 'Strategy';

  @override
  String get setWmsStrategyFefo => 'FEFO — first to expire, first out';

  @override
  String get setWmsStrategyFifo => 'FIFO — first in, first out';

  @override
  String get setWmsStrategyLifo => 'LIFO — last in, first out';

  @override
  String get setWmsCostMethod => 'Cost calculation method';

  @override
  String get setWmsCostMethodDesc => 'Cost write-off method on sale';

  @override
  String get setWmsMethod => 'Method';

  @override
  String get setWmsCostFifo => 'FIFO — by order of receipt';

  @override
  String get setWmsCostLifo => 'LIFO — in reverse order';

  @override
  String get setWmsCostAvg => 'Weighted average cost';

  @override
  String get setWmsExpiryWarnDesc => 'How many days before expiry to warn';

  @override
  String setWmsDaysShort(int days) {
    return '$days d.';
  }

  @override
  String get setWmsAbcAnalysis => 'ABC analysis';

  @override
  String get setWmsAbcDesc => 'Thresholds for classifying goods by turnover';

  @override
  String get setWmsAbcCategoryA => 'Category A (high turnover)';

  @override
  String get setWmsAbcCategoryB => 'Category B (medium turnover)';

  @override
  String get setWmsAbcCategoryC => 'Category C (low turnover)';

  @override
  String get setWmsSaved => 'WMS settings saved';

  @override
  String get setWmsSaveError => 'Failed to save WMS settings';

  @override
  String get setSalesPolicy => 'Sales policy';

  @override
  String get setSalesPolicyDesc => 'Stock control on sale';

  @override
  String get setBlockOversell => 'Block sale when stock is insufficient';

  @override
  String get setBlockOversellDesc =>
      'Do not complete a sale if receipt quantity exceeds stock (protection against negative stock)';

  @override
  String get setScreenTouch => 'Screen and touchscreen';

  @override
  String get setScreenTouchDesc => 'Touchscreen convenience';

  @override
  String get setScrollAssist => 'Scroll buttons on touchscreen';

  @override
  String get setScrollAssistDesc =>
      'On-screen ▲/▼ buttons for scrolling long lists (catalog, receipt, reports, warehouse) on a touchscreen';

  @override
  String get setDemoData => 'Demo data';

  @override
  String get setDemoDataSubtitle => '12 months of sales';

  @override
  String get setDemoDataDialogContent =>
      'Load demo data for all modes:\n• Retail: ~6000 sales, supplies, refunds\n• Restaurant: 15 tables, 29 dishes with costing, orders\n• Service: services, consumables, work orders\n\nOr clear all data for a clean start.';

  @override
  String get setDemoClearAll => 'Clear all';

  @override
  String get setDemoLoad => 'Load demo';

  @override
  String get setDemoGenerating => 'Generating demo data...';

  @override
  String get setDemoLoadedTitle => 'Demo data loaded';

  @override
  String get setDemoAlreadyExists =>
      'Data already exists. First press \"Clear all\".';

  @override
  String get setClearDataTitle => 'Clear data';

  @override
  String get setClearDataContent =>
      'ALL data will be deleted:\n• Sales, refunds, payments\n• Products, categories, prices\n• Counterparties, supplies\n• Orders, shifts, cash operations\n• Restaurant tables, orders\n• Service orders\n\nPOS settings and users will be kept.\nThis action is irreversible!';

  @override
  String get setClearDeleteAll => 'Delete all';

  @override
  String get setClearInProgress => 'Clearing data...';

  @override
  String get setClearDone => 'All data cleared';

  @override
  String setGenericError(String error) {
    return 'Error: $error';
  }

  @override
  String get setCorrectionTitle => 'Correction receipt';

  @override
  String get setCorrectionIntro =>
      'A correction receipt fixes a previously punched or unpunched amount. Specify the reason and amount. If the operator does not support correction, this will be shown honestly.';

  @override
  String get setCorrectionReasonLabel => 'Correction reason';

  @override
  String get setCorrectionReasonHint => 'e.g. self-correction';

  @override
  String get setCorrectionAmountLabel => 'Correction amount, KZT';

  @override
  String get setCorrectionPaymentLabel => 'Payment method';

  @override
  String get setCorrectionCash => 'Cash';

  @override
  String get setCorrectionCard => 'Card';

  @override
  String get setCorrectionSubmit => 'Send correction receipt';

  @override
  String get setCorrectionDefaultName => 'Correction';

  @override
  String get setCorrectionInvalidAmount =>
      'Enter a valid correction amount (> 0)';

  @override
  String get setCorrectionQueued => 'Correction receipt queued (offline)';

  @override
  String get setCorrectionSent => 'Correction receipt sent';

  @override
  String get setCorrectionUnsupported =>
      'Correction receipt is not supported by the current operator';

  @override
  String get setCorrectionNotConfigured => 'Fiscalization is not configured';

  @override
  String get setCorrectionError => 'Correction receipt error';

  @override
  String get setFiscalConnection => 'Connection';

  @override
  String get setFiscalTestMode => 'Test mode';

  @override
  String get setFiscalLogin => 'Login';

  @override
  String get setFiscalLoginHint => 'email / phone';

  @override
  String get setFiscalPassword => 'Password';

  @override
  String get setFiscalCashboxSerial => 'ZNM (cash register serial number)';

  @override
  String get setFiscalCashboxSerialHint => 'e.g. SWK00033717';

  @override
  String get setFiscalRnm => 'RNM (registration number)';

  @override
  String get setFiscalKeyPath => 'Path to key/certificate';

  @override
  String get setFiscalOfflineModule => 'Offline module address';

  @override
  String get setFiscalVatRate => 'VAT rate, %';

  @override
  String get dishTabRecipe => 'Recipe';

  @override
  String get dishTabCosting => 'Costing';

  @override
  String get dishTabYield => 'Yield & nutrition';

  @override
  String get dishVersions => 'Versions';

  @override
  String get dishCostLabel => 'Cost';

  @override
  String get dishPriceLabel => 'Price';

  @override
  String get dishProfitLabel => 'Profit';

  @override
  String get dishMarkupLabel => 'Markup';

  @override
  String get dishNoIngredients => 'No ingredients';

  @override
  String get dishNoIngredientsHint => 'Add ingredients to calculate the recipe';

  @override
  String get dishAddIngredient => 'Add ingredient';

  @override
  String get dishColIngredient => 'Ingredient';

  @override
  String get dishColGross => 'Gross';

  @override
  String get dishColColdLoss => 'Prep loss%';

  @override
  String get dishColNet => 'Net';

  @override
  String get dishColHotLoss => 'Cook loss%';

  @override
  String get dishColYield => 'Yield';

  @override
  String get dishColCost => 'Cost';

  @override
  String get dishDeleteIngredient => 'Delete ingredient';

  @override
  String get dishTotal => 'Total';

  @override
  String get dishDeleteIngredientTitle => 'Delete ingredient?';

  @override
  String dishDeleteIngredientConfirm(String name) {
    return 'Remove \"$name\" from the recipe?';
  }

  @override
  String get dishSearchIngredientHint =>
      'Search ingredient by name or barcode...';

  @override
  String dishCodeOnly(int code) {
    return 'Code: $code';
  }

  @override
  String dishCodeWithBarcode(int code, int barcode) {
    return 'Code: $code  |  Barcode: $barcode';
  }

  @override
  String dishAddTitle(String name) {
    return 'Add: $name';
  }

  @override
  String get dishGrossQty => 'Gross (qty)';

  @override
  String get dishColdLossLabel => 'Prep loss, %';

  @override
  String get dishHotLossLabel => 'Heat-treatment loss, %';

  @override
  String get dishSeasonCoefficient => 'Seasonal coefficient';

  @override
  String get dishSeasonStandard => 'Standard (x1.0)';

  @override
  String get dishSeasonWinter => 'Winter (+15%) (x1.15)';

  @override
  String get dishSeasonSummer => 'Summer (-5%) (x0.95)';

  @override
  String dishEffectiveColdLoss(String value) {
    return 'Effective prep loss: $value%';
  }

  @override
  String dishTotalYieldSummary(String cost, String yield) {
    return 'Total: $cost ₸  |  Yield: $yield';
  }

  @override
  String get dishGostNorms => 'GOST norms';

  @override
  String get dishGostNormsTitle => 'GOST loss norms';

  @override
  String get dishSearchProductHint => 'Search product...';

  @override
  String get dishReferenceEmpty => 'Reference is empty';

  @override
  String get dishGostNotLoaded => 'GOST norm data not loaded yet';

  @override
  String dishGostLossLine(String cold, String hot) {
    return 'Cold: $cold%  Heat: $hot%';
  }

  @override
  String get dishPhotoSection => 'Dish photo';

  @override
  String get dishMissingPricesWarning =>
      'Some ingredients have no purchase price';

  @override
  String get dishProfitPerServing => 'Profit per serving';

  @override
  String get dishLossPerServing => 'Loss per serving';

  @override
  String get dishCostOfDish => 'Dish cost';

  @override
  String get dishSellingPrice => 'Selling price';

  @override
  String get dishMargin => 'Margin';

  @override
  String get dishNoPhoto => 'No photo';

  @override
  String get dishPhotoLoaded => 'Photo uploaded';

  @override
  String get dishPhotoAddHint => 'Add a photo of the finished dish';

  @override
  String get dishCamera => 'Camera';

  @override
  String get dishGallery => 'Gallery';

  @override
  String get dishPhotoLoadError => 'Failed to load photo';

  @override
  String get dishFoodCost => 'Food cost';

  @override
  String get dishFoodCostExcellent => 'Excellent';

  @override
  String get dishFoodCostNormal => 'Normal';

  @override
  String get dishFoodCostHigh => 'High';

  @override
  String get dishServingsCount => 'Servings:';

  @override
  String get dishCostPerServing => 'Cost per serving';

  @override
  String get dishPricePerServing => 'Price per serving';

  @override
  String get dishTotalYield => 'Total yield';

  @override
  String get dishIngredientsCount => 'Ingredients';

  @override
  String get dishKbjuSection => 'Nutrition (per serving)';

  @override
  String get dishKbjuEmpty => 'Nutrition data not filled in';

  @override
  String get dishKbjuCalories => 'Calories';

  @override
  String get dishKbjuProteins => 'Proteins';

  @override
  String get dishKbjuFats => 'Fats';

  @override
  String get dishKbjuCarbs => 'Carbs';

  @override
  String dishKcalValue(String value) {
    return '$value kcal';
  }

  @override
  String dishGramValue(String value) {
    return '$value g';
  }

  @override
  String get dishVersionHistory => 'Change history';

  @override
  String get dishNoVersions => 'No saved versions';

  @override
  String dishVersionN(String version) {
    return 'Version $version';
  }

  @override
  String get dishViewComposition => 'View composition';

  @override
  String get dishRestoreThisVersion => 'Restore this version';

  @override
  String get dishSaveVersion => 'Save version';

  @override
  String dishVersionComposition(String version) {
    return 'Version $version — composition';
  }

  @override
  String get dishSnapshotUnavailable => 'Composition snapshot unavailable';

  @override
  String dishSnapshotIngredientLine(
    String gross,
    String cold,
    String hot,
    String yield,
  ) {
    return 'Gross: $gross  |  Prep loss: $cold%  |  Cook loss: $hot%  |  Yield: $yield';
  }

  @override
  String get dishVersionNotRestorable =>
      'This version cannot be restored (no ingredient data), view only';

  @override
  String get dishRestoreVersionTitle => 'Restore version?';

  @override
  String dishRestoreVersionConfirm(String version) {
    return 'The current recipe will be replaced with the composition of version $version. Continue?';
  }

  @override
  String get dishRestore => 'Restore';

  @override
  String dishVersionRestored(String version) {
    return 'Version $version restored';
  }

  @override
  String get dishRestoreError => 'Failed to restore version';

  @override
  String dishVersionSummary(int count, String cost) {
    return 'Ingredients: $count, cost: $cost';
  }

  @override
  String get dishSaveVersionError => 'Failed to save recipe version';

  @override
  String get prodBarcodeAutoHint => 'Auto';

  @override
  String get prodCatalogAttributes => 'Catalog attributes';

  @override
  String get prodBrand => 'Brand';

  @override
  String get prodManufacturer => 'Manufacturer';

  @override
  String get prodCountryOfOrigin => 'Country of origin';

  @override
  String get prodFiscalAttributes => 'Fiscal attributes';

  @override
  String get prodVatRate => 'VAT rate';

  @override
  String get prodVatNone => 'No VAT';

  @override
  String get prodNtin => 'NTIN';

  @override
  String get prodMarkable => 'Subject to marking';

  @override
  String get promoTitle => 'Promotions';

  @override
  String get promoNew => 'New promotion';

  @override
  String promoError(String error) {
    return 'Error: $error';
  }

  @override
  String get promoEmpty => 'No promotions';

  @override
  String get promoEmptyHint => 'Create a 1+1 or Gift promotion';

  @override
  String get promoTypeGift => 'Gift';

  @override
  String promoBuyGetFree(int trigger, int reward) {
    return 'buy $trigger → $reward free';
  }

  @override
  String get promoSupplierTag => 'supplier-funded';

  @override
  String get promoDefaultName11 => '1+1 promotion';

  @override
  String get promoNameLabel => 'Name';

  @override
  String get promoTriggerLabel => 'Trigger product (what to buy)';

  @override
  String get promoRewardLabel => 'Gift (what\'s free)';

  @override
  String get promoSupplierFunded => 'Supplier-funded promotion';

  @override
  String get promoSaveButton => 'Save promotion';

  @override
  String get saleWeighingPlaceItem => 'Weighing... place the item on the scale';

  @override
  String get saleWeightReadFailed => 'Failed to read weight — enter manually';

  @override
  String get salePriceLabelSent => 'Price label sent to printer';

  @override
  String get transPrimary => 'Primary';

  @override
  String get transSecondary => 'Secondary';

  @override
  String get transStatusOnline => 'Online';

  @override
  String get transStatusOffline => 'Offline';

  @override
  String get transStatusSyncing => 'Syncing';

  @override
  String get transStatusQueued => 'Queued';

  @override
  String get transStatusWarning => 'Warning';

  @override
  String get transStatusError => 'Error';

  @override
  String transQueuedCount(int count) {
    return '$count in queue';
  }

  @override
  String transFailedCount(int count) {
    return '$count failed';
  }

  @override
  String transLastSyncAgo(String ago) {
    return 'Last sync: $ago ago';
  }

  @override
  String get transSyncing => 'Syncing...';

  @override
  String get transSyncNow => 'Sync Now';

  @override
  String get transRetryFailed => 'Retry Failed';

  @override
  String get restTips => 'Tips';

  @override
  String get restNoTips => 'No tips';

  @override
  String get svcPendingApproval => 'Pending approval';

  @override
  String get svcApprove => 'Approve';

  @override
  String get svcReject => 'Reject';

  @override
  String get svcRejected => 'Rejected';

  @override
  String get svcQr => 'QR';

  @override
  String get catCollapse => 'Collapse';

  @override
  String get repError => 'Error';

  @override
  String get repNoData => 'No data';

  @override
  String get repNoDataForPeriod => 'No data for the selected period';

  @override
  String get repKpiLoadError => 'KPI load error';

  @override
  String get repColIndicator => 'Indicator';

  @override
  String get repColCount => 'Qty';

  @override
  String get repColSumTenge => 'Amount, ₸';

  @override
  String get repColRow => 'Line';

  @override
  String get repColTurnoverExclVat => 'Turnover (excl. VAT)';

  @override
  String get repColVat => 'VAT';

  @override
  String get repColDate => 'Date';

  @override
  String get repColOperation => 'Operation';

  @override
  String get repColIncome => 'Income';

  @override
  String get repColExpense => 'Expense';

  @override
  String get repColBalance => 'Balance';

  @override
  String get repColRate => 'Rate';

  @override
  String get repColGross => 'Gross';

  @override
  String get repColNet => 'Net';

  @override
  String get repNoVat => 'No VAT';

  @override
  String get repColCounterparty => 'Counterparty';

  @override
  String get repColType => 'Type';

  @override
  String get repColSaldo => 'Balance';

  @override
  String get repDebtor => 'Debtor';

  @override
  String get repCreditor => 'Creditor';

  @override
  String get repColAccount => 'Account';

  @override
  String get repColCashier => 'Cashier';

  @override
  String get repColAmount => 'Amount';

  @override
  String get repColProduct => 'Product';

  @override
  String get repColRevenue => 'Revenue';

  @override
  String get repColCogs => 'COGS';

  @override
  String get repColProfit => 'Profit';

  @override
  String get repColMarginPct => 'Margin %';

  @override
  String get repColReason => 'Reason';

  @override
  String get repColDocuments => 'Documents';

  @override
  String get repColCostShort => 'Cost';

  @override
  String get repF910Title => 'Form 910 — Income (simplified)';

  @override
  String repF910Subtitle(String income, String rate, String tax) {
    return 'Taxable income: $income ₸ • tax $rate%: $tax ₸';
  }

  @override
  String get repF910RowSalesIncome => 'Sales income';

  @override
  String get repF910RowRefunds => 'Refunds (minus)';

  @override
  String get repF910RowTaxableIncome => 'Taxable income';

  @override
  String get repF300Title => 'Form 300 — VAT (declaration)';

  @override
  String repF300Subtitle(String turnover, String vat) {
    return 'Taxable turnover: $turnover ₸ • output VAT: $vat ₸';
  }

  @override
  String repF300TaxableTurnoverRate(String rate) {
    return 'Taxable turnover $rate%';
  }

  @override
  String get repF300ZeroRatedTurnover => 'Exempt / 0% turnover';

  @override
  String get repCashBookTitle => 'Cash book (KO-4)';

  @override
  String repCashBookSubtitle(String income, String expense, String balance) {
    return 'Income: $income • Expense: $expense • Balance: $balance ₸';
  }

  @override
  String get repVatPeriodTitle => 'VAT for the period';

  @override
  String repVatPeriodSubtitle(String vat, String base) {
    return 'VAT: $vat ₸ • base: $base ₸';
  }

  @override
  String get repArApTitle => 'Receivables / Payables';

  @override
  String repArApSubtitle(String receivable, String payable, String saldo) {
    return 'Receivables: $receivable • Payables: $payable • Balance: $saldo';
  }

  @override
  String get repCashCollectionTitle => 'Cash collection';

  @override
  String repCashCollectionSubtitle(int count, String total) {
    return '$count operations • total: $total ₸';
  }

  @override
  String get repProfitCogsTitle => 'Profit / Margin (COGS)';

  @override
  String get repProfitMarginTitle => 'Profit / Margin';

  @override
  String repProfitMarginSubtitle(String profit, String margin, String note) {
    return 'Profit: $profit ₸ • margin $margin% • $note';
  }

  @override
  String get repProfitCostRealCogs => 'cost: real COGS';

  @override
  String get repProfitCostWholesale =>
      'cost: wholesale price (no CalculateCogsUseCase)';

  @override
  String get repWriteoffTitle => 'Write-offs';

  @override
  String repWriteoffSubtitle(int count, String total) {
    return '$count documents • total: $total ₸';
  }

  @override
  String get repOrderTypesTitle => 'Order types';

  @override
  String get repOrderTypesSubtitle => 'distribution by service type';

  @override
  String get repTableTurnoverTitle => 'Table turnover';

  @override
  String get repTableTurnoverSubtitle => 'seatings for the period (top-10)';

  @override
  String get repDishPopularityTitle => 'Dish popularity';

  @override
  String get repDishPopularitySubtitle => 'top-10 by sales count';

  @override
  String get repFoodCostAnalysisShort => 'Food cost analysis';

  @override
  String get repFoodCostAnalysisTitle => 'Cost analysis (Food Cost)';

  @override
  String get repFoodCostAnalysisSubtitle =>
      'green <30%, yellow 30-40%, red >40%';

  @override
  String get repColDish => 'Dish';

  @override
  String get repColFoodCostPct => 'Food Cost %';

  @override
  String get repTipsByWaiterTitle => 'Tips by waiter';

  @override
  String get repTipsByWaiterSubtitle => 'sorted by tip amount';

  @override
  String get repColWaiter => 'Waiter';

  @override
  String get repColOrders => 'Orders';

  @override
  String get repColTips => 'Tips';

  @override
  String get repColTipsPct => 'Tips %';

  @override
  String get repKpiRestaurantRevenue => 'Restaurant revenue';

  @override
  String get repKpiOrders => 'Orders';

  @override
  String get repKpiAvgCheck => 'Average check';

  @override
  String get repKpiTips => 'Tips';

  @override
  String get repKpiRevenue => 'Revenue';

  @override
  String get repKpiExpenses => 'Expenses';

  @override
  String get repKpiRefunds => 'Refunds';

  @override
  String get repKpiSales => 'Sales';

  @override
  String get repSubtitleForPeriod => 'for the period';

  @override
  String get repSubtitleTotal => 'total';

  @override
  String get repSubtitleCashExpenses => 'cash expenses';

  @override
  String get repSubtitleRefundTotal => 'refund amount';

  @override
  String get repSubtitleReceipts => 'receipts';

  @override
  String get repCashFlowTitle => 'Cash flow by day';

  @override
  String get repCashFlowInvestments => 'Investments';

  @override
  String get repCashFlowExpenses => 'Expenses';

  @override
  String get repCashFlowDividends => 'Dividends';

  @override
  String repDaysCount(int count) {
    return '$count days';
  }

  @override
  String get repTopProfitableTitle => 'Top-10 profitable products';

  @override
  String get repTopProfitableSubtitle => 'by absolute profit';

  @override
  String get repProductProfitTitle => 'Product profitability';

  @override
  String get repProductProfitSubtitle => 'top-20 by profit';

  @override
  String get repRefundTrendTitle => 'Refund trend';

  @override
  String get repSupplierVolumeTitle => 'Supplies by supplier';

  @override
  String repSuppliersCount(int count) {
    return '$count suppliers';
  }

  @override
  String get repSupplierTableTitle => 'Suppliers table';

  @override
  String get repSupplierTableSubtitle => 'sorted by supply count';

  @override
  String get repColSupplier => 'Supplier';

  @override
  String get repColSupplyCount => 'Supply count';

  @override
  String get repPriceTrendTitle => 'Purchase price trend';

  @override
  String get repPriceTrendSubtitle => 'top-5 products by supply count';

  @override
  String get repNotEnoughDataForChart => 'Not enough data for the chart';

  @override
  String get repPriceChangesShort => 'Price changes';

  @override
  String get repPriceChangesTitle => 'Supplier price changes';

  @override
  String get repPriceChangesSubtitle => 'recent purchase price changes';

  @override
  String get repColWas => 'Was';

  @override
  String get repColBecame => 'Now';

  @override
  String get repColChangePctShort => 'Chg. %';

  @override
  String get repNoSupplierData => 'No supplier data';

  @override
  String get repNoSuppliesForPeriod =>
      'No supplies found for the selected period';

  @override
  String get navWmsDashboard => 'WMS';

  @override
  String get navWmsWarehouses => 'Warehouses';

  @override
  String get navWmsBatches => 'Batches';

  @override
  String get navWmsSerials => 'Serials';

  @override
  String get navWmsCellStock => 'Cells';

  @override
  String get navWmsClaims => 'Claims';

  @override
  String get navWmsMarking => 'Marking';

  @override
  String get navWmsSettings => 'WMS settings';

  @override
  String errorInsufficientStock(String name) {
    return 'Insufficient stock: $name';
  }

  @override
  String get errorBigAmountBlocked =>
      'Sale total exceeds 1,000,000 ₸. Enable the large-amount permission in POS settings.';

  @override
  String errorMarkRequired(String name) {
    return 'Marking code required: $name';
  }

  @override
  String get errorOrderNotFound => 'Order not found';

  @override
  String get errorSerialNotFound => 'Serial number not found';

  @override
  String get errorReceiptFailedPrint => 'Failed to print receipt';

  @override
  String get errorDeleteFailed => 'Failed to delete';

  @override
  String get errorCancelFailed => 'Failed to cancel';

  @override
  String get errorShiftZreportFailed => 'Z-report error';

  @override
  String get errorTransitionFailed => 'Failed to change status';

  @override
  String get logJournalTitle => 'Work log';

  @override
  String get logJournalOpen => 'Open log';

  @override
  String get logJournalCardDesc =>
      'Dated file work log: export to USB, cleanup';

  @override
  String get logJournalEmpty => 'Log is empty';

  @override
  String get logJournalPickFolder => 'Choose a folder (USB) to export';

  @override
  String get logJournalExport => 'Export to USB';

  @override
  String logJournalExported(int count, String dir) {
    return 'Exported $count files to $dir';
  }

  @override
  String logJournalSummary(int count, String size) {
    return 'Files: $count, total $size';
  }

  @override
  String get logJournalDeleteOld => 'Older than 7 days';

  @override
  String logJournalDeletedOld(int count) {
    return 'Deleted $count files';
  }

  @override
  String get logJournalDeleteAllTitle => 'Delete all logs?';

  @override
  String get logJournalDeleteAllConfirm =>
      'All log files except today\'s will be deleted. This cannot be undone.';

  @override
  String get setUserTabPin => 'PIN';

  @override
  String get setUserPinChange => 'Change PIN';

  @override
  String get setUserPinSetHint => 'Set a login PIN (4-6 digits)';

  @override
  String get setUserPinKeepHint => 'Leave blank to keep the current PIN';

  @override
  String get setUserPinNew => 'New PIN';

  @override
  String get receiptInputRecent => 'Recent receipts';

  @override
  String get receiptInputNoRecent => 'No receipts yet';

  @override
  String get shiftHistoryTitle => 'Shift history';

  @override
  String get shiftHistoryEmpty => 'No closed shifts yet';

  @override
  String shiftHistoryShiftNo(int id) {
    return 'Shift #$id';
  }

  @override
  String get shiftHistorySales => 'Sales';

  @override
  String get shiftHistoryRefunds => 'Refunds';

  @override
  String get shiftHistoryOpeningCash => 'Opening cash';

  @override
  String saleExpiredBatchWarning(String name) {
    return 'Warning: \"$name\" has an expired batch';
  }

  @override
  String get setPolicyEditProduct => 'Allow editing products';

  @override
  String get setPolicyEditProductDesc =>
      'Cashier can edit product cards in the catalog';

  @override
  String get setPolicyEditPrice => 'Allow changing price during sale';

  @override
  String get setPolicyEditPriceDesc =>
      'Cashier can manually change a line price on the receipt';

  @override
  String get setPolicyDiscounts => 'Allow discounts';

  @override
  String get setPolicyDiscountsDesc =>
      'Cashier can apply discounts to receipt lines';

  @override
  String get setPolicyCashInOut => 'Allow cash in/out';

  @override
  String get setPolicyCashInOutDesc =>
      'Cashier can deposit and withdraw cash from the till';

  @override
  String get setPolicyBigAmount => 'Allow large amounts (>1M)';

  @override
  String get setPolicyBigAmountDesc => 'Lift the 1,000,000 cap on operations';

  @override
  String get setPolicyBlockPriceDecrease =>
      'Forbid lowering price below the card price';

  @override
  String get setPolicyBlockPriceDecreaseDesc =>
      'A receipt line price cannot be set below the product price';

  @override
  String get printerAutoDetect => 'Find printer';

  @override
  String get printerAutoDetecting => 'Searching for printer…';

  @override
  String printerFound(String device) {
    return 'Found: $device';
  }

  @override
  String printerFoundWithNote(String device, String note) {
    return 'Found: $device — $note';
  }

  @override
  String get printerNotFoundAnyPort =>
      'Printer not found on any port (USB/serial). Check the cable and power.';

  @override
  String get printerUsbName => 'USB printer';

  @override
  String get printerSelectDevice => 'Select printer';

  @override
  String get printerNoAccessGroupLp =>
      'Node found but no access (group lp required)';

  @override
  String printerLabelUsb(String path) {
    return 'USB printer ($path)';
  }

  @override
  String printerLabelSerial(String path) {
    return 'Serial printer ($path)';
  }

  @override
  String get printerNoAccessGroupLpHint =>
      'Node found but no access (group lp required): usermod -aG lp telepos and restart the session.';

  @override
  String printerRawOpenNoPermsHint(String path) {
    return 'Node $path found but cannot be opened — no permissions. Add the user to group lp (usermod -aG lp telepos) and restart the session/appliance.';
  }

  @override
  String get printerNotFoundNoNode =>
      'Printer not found: no /dev/usb/lp* char node and no USB-serial port. Check the printer cable and power.';

  @override
  String get ownerOnlyTitle => 'Available to the till owner only';

  @override
  String get ownerOnlyDesc =>
      'System operations (reboot, reset, drivers, terminal) are available only under the owner account.';

  @override
  String get telegramApiSectionTitle => 'Telegram application';

  @override
  String get telegramApiSectionDesc =>
      'TelePOS ships without Telegram credentials. Register an application at my.telegram.org and enter the pair below, or pass it at build time via --dart-define.';

  @override
  String get telegramApiIdLabel => 'api_id';

  @override
  String get telegramApiHashLabel => 'api_hash';

  @override
  String get telegramApiSave => 'Save credentials';

  @override
  String get telegramApiClear => 'Clear credentials';

  @override
  String get telegramApiSaved => 'Telegram credentials saved';

  @override
  String get telegramApiCleared => 'Telegram credentials cleared';

  @override
  String get telegramApiInvalid =>
      'Enter a numeric api_id and a non-empty api_hash';

  @override
  String get telegramApiStatusConfigured => 'Credentials set';

  @override
  String get telegramApiStatusMissing => 'Credentials not set';

  @override
  String get deviceSearchButton => 'Search';

  @override
  String get deviceSearchTitle => 'Discovered devices';

  @override
  String get deviceSearchRunning => 'Searching…';

  @override
  String get deviceSearchEmpty =>
      'Nothing found. Every source was searched — the device is not attached or is switched off.';

  @override
  String get deviceSearchNoValueForField =>
      'Devices were found, but none of them supplies a value for this field.';

  @override
  String deviceSearchFailedSources(String sources) {
    return 'Could not search over: $sources. That is not the same as “nothing is attached”.';
  }

  @override
  String get deviceSearchUnavailable =>
      'Device search is not available in this build.';

  @override
  String deviceSearchFieldFilled(String value) {
    return 'Field filled in: $value';
  }

  @override
  String get deviceSourceSerialPort => 'Serial port';

  @override
  String get deviceSourceUsb => 'USB';

  @override
  String get deviceSourceNetwork => 'Network';

  @override
  String get deviceSourceBluetooth => 'Bluetooth';

  @override
  String get deviceCheckButton => 'Check device';

  @override
  String get deviceCheckRunning => 'Checking…';

  @override
  String get deviceCheckUnavailable =>
      'Device checks are not available in this build.';

  @override
  String get deviceCheckSavedBindingNotice =>
      'The check runs against the saved binding: the device is contacted using the stored parameters, not the unsaved edits on this screen. Restart the app for a changed binding to take effect in sales.';

  @override
  String get deviceCheckReasonOk => 'The device responded';

  @override
  String get deviceCheckReasonNotConfigured => 'The device is not configured';

  @override
  String get deviceCheckReasonInvalidBinding => 'The binding is invalid';

  @override
  String get deviceCheckReasonDriverNotLive =>
      'Bound, but this build cannot drive this device';

  @override
  String get deviceCheckReasonConnectionFailed => 'The device did not answer';

  @override
  String get deviceCheckReasonDeviceRefused =>
      'The device refused the operation';

  @override
  String get deviceCheckReasonNotSupportedOnPlatform =>
      'Not supported on this platform';

  @override
  String get deviceCheckReasonNotImplemented =>
      'No check is implemented for this device class yet';

  @override
  String get deviceCheckReasonUnexpectedError => 'Unexpected error';

  @override
  String get scannerRulesTitle => 'Barcode reading rules';

  @override
  String get scannerRulesSubtitle =>
      'Not scanner properties — installation rules deciding which read value to accept.';

  @override
  String get scannerRulesMinLength => 'Minimum barcode length';

  @override
  String get scannerRulesMaxLength => 'Maximum barcode length';

  @override
  String get scannerRulesTimeoutMs => 'Scanner inter-character gap, ms';

  @override
  String scannerRulesDefaultHint(String value) {
    return 'Empty — default $value';
  }

  @override
  String scannerRulesNotAnInteger(String value) {
    return '“$value” is not a whole number';
  }

  @override
  String get scannerRulesUnavailable =>
      'Barcode reading rules are not available in this build.';

  @override
  String get scannerRulesSaved => 'Barcode reading rules saved';

  @override
  String get printQueueSectionTitle => 'Print queue';

  @override
  String get printQueueSubtitle =>
      'What is waiting to print, what did not print and why.';

  @override
  String get printQueueEmpty =>
      'The queue is empty — there are no unprinted receipts.';

  @override
  String get printQueueUnavailable =>
      'The print queue is not available in this build.';

  @override
  String get printQueueUnreadable => 'The print queue cannot be read';

  @override
  String get printQueueUnreadableHint =>
      'This is not an empty queue: jobs may be waiting to print, but the list cannot be read. Service is required.';

  @override
  String get printQueueStateQueued => 'Waiting to print';

  @override
  String get printQueueStatePrinting => 'Printing';

  @override
  String get printQueueStatePrinted => 'Printed';

  @override
  String get printQueueStateFailed => 'Not printed, will be retried';

  @override
  String get printQueueStateExpired =>
      'Deadline passed, will not retry by itself';

  @override
  String get printQueueStateCancelled => 'Cancelled by the operator';

  @override
  String printQueueAttempts(int count) {
    return 'Attempts: $count';
  }

  @override
  String printQueueDeadline(String moment) {
    return 'Valid until $moment';
  }

  @override
  String printQueueReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get printQueueRetry => 'Retry';

  @override
  String get printQueueCancelJob => 'Cancel job';

  @override
  String get printQueueExtendTitle => 'How much longer should the job live?';

  @override
  String get printQueueExtend5Minutes => '5 more minutes';

  @override
  String get printQueueExtend30Minutes => '30 more minutes';

  @override
  String get printQueueExtend2Hours => '2 more hours';

  @override
  String get printQueueRetryAccepted => 'The job is back in the queue';

  @override
  String get printQueueRetryAlreadyPrinted =>
      'This receipt has already been printed — it is not printed a second time';

  @override
  String get printQueueRetryRejected => 'Retry failed';

  @override
  String get printQueueCancelTitle => 'Cancel this job?';

  @override
  String get printQueueCancelBody =>
      'A cancelled job can no longer be printed. If the same receipt is still needed, it has to be issued again.';

  @override
  String get printQueueCancelConfirm => 'Cancel job';

  @override
  String get printQueueCancelDone => 'The job has been cancelled';

  @override
  String get printQueueCancelRefused =>
      'This job can no longer be cancelled: it is printing or already finished';
}
