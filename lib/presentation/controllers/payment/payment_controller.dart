import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/device/terminal_device_binding_resolver.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/usecases/agent/bonus_service.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_config.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_service.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

enum PaymentType { cash, card, mixed }

@immutable
class LoyaltyCustomer {
  const LoyaltyCustomer({
    required this.id,
    required this.phone,
    required this.name,
    required this.bonusBalance,
  });

  final int id;
  final String phone;
  final String name;
  final Decimal bonusBalance;
}

@immutable
class PaymentAccount {
  const PaymentAccount({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final bool isDefault;
}

enum PaymentInputField { cash, card }

enum CardTerminalOutcome { notConfigured, approved, declined }

@immutable
class CardTerminalResult {
  const CardTerminalResult({
    required this.outcome,
    this.approvalCode,
    this.cardMask,
    this.transactionId,
    this.message,
  });

  final CardTerminalOutcome outcome;
  final String? approvalCode;
  final String? cardMask;
  final String? transactionId;
  final String? message;

  bool get isApproved => outcome == CardTerminalOutcome.approved;
  bool get isDeclined => outcome == CardTerminalOutcome.declined;
  bool get isNotConfigured => outcome == CardTerminalOutcome.notConfigured;
}

@immutable
class PaymentState {
  PaymentState({
    required this.totalAmount,
    this.paymentType = PaymentType.cash,
    Decimal? cashReceived,
    Decimal? cardAmount,
    this.selectedAccountId,
    this.loyaltyCustomer,
    Decimal? bonusToUse,
    this.iin,
    this.isProcessing = false,
    this.error,
    this.activeInput = PaymentInputField.cash,
    this.cashInputText = '',
    this.cardInputText = '',
    this.terminalApprovalCode,
    this.terminalCardMask,
    this.terminalTransactionId,
  }) : cashReceived = cashReceived ?? Decimal.zero,
       cardAmount = cardAmount ?? Decimal.zero,
       bonusToUse = bonusToUse ?? Decimal.zero;

  final Decimal totalAmount;

  final PaymentType paymentType;

  final Decimal cashReceived;

  final Decimal cardAmount;

  final int? selectedAccountId;

  final LoyaltyCustomer? loyaltyCustomer;

  final Decimal bonusToUse;

  final String? iin;

  final bool isProcessing;

  final String? error;

  final PaymentInputField activeInput;

  final String cashInputText;

  final String cardInputText;

  final String? terminalApprovalCode;

  final String? terminalCardMask;

  final String? terminalTransactionId;

  bool get isTerminalAuthorized => terminalApprovalCode != null;

  Decimal get amountToPay => totalAmount - bonusToUse;

  Decimal get change {
    if (paymentType == PaymentType.cash) {
      final diff = cashReceived - amountToPay;
      return diff > Decimal.zero ? diff : Decimal.zero;
    }
    if (paymentType == PaymentType.mixed) {
      final totalReceived = cashReceived + cardAmount;
      final diff = totalReceived - amountToPay;
      return diff > Decimal.zero ? diff : Decimal.zero;
    }
    return Decimal.zero;
  }

  Decimal get remaining {
    switch (paymentType) {
      case PaymentType.cash:
        final diff = amountToPay - cashReceived;
        return diff > Decimal.zero ? diff : Decimal.zero;
      case PaymentType.card:
        return Decimal.zero;
      case PaymentType.mixed:
        final totalReceived = cashReceived + cardAmount;
        final diff = amountToPay - totalReceived;
        return diff > Decimal.zero ? diff : Decimal.zero;
    }
  }

  bool get canComplete {
    if (isProcessing) return false;

    switch (paymentType) {
      case PaymentType.cash:
        return cashReceived >= amountToPay;
      case PaymentType.card:
        return true;
      case PaymentType.mixed:
        return (cashReceived + cardAmount) >= amountToPay;
    }
  }

  bool get hasLoyaltyCustomer => loyaltyCustomer != null;

  Decimal get availableBonus => loyaltyCustomer?.bonusBalance ?? Decimal.zero;

  PaymentState copyWith({
    Decimal? totalAmount,
    PaymentType? paymentType,
    Decimal? cashReceived,
    Decimal? cardAmount,
    int? selectedAccountId,
    bool clearSelectedAccountId = false,
    LoyaltyCustomer? loyaltyCustomer,
    bool clearLoyaltyCustomer = false,
    Decimal? bonusToUse,
    String? iin,
    bool clearIin = false,
    bool? isProcessing,
    String? error,
    bool clearError = false,
    PaymentInputField? activeInput,
    String? cashInputText,
    String? cardInputText,
    String? terminalApprovalCode,
    String? terminalCardMask,
    String? terminalTransactionId,
    bool clearTerminalData = false,
  }) {
    return PaymentState(
      totalAmount: totalAmount ?? this.totalAmount,
      paymentType: paymentType ?? this.paymentType,
      cashReceived: cashReceived ?? this.cashReceived,
      cardAmount: cardAmount ?? this.cardAmount,
      selectedAccountId: clearSelectedAccountId
          ? null
          : (selectedAccountId ?? this.selectedAccountId),
      loyaltyCustomer: clearLoyaltyCustomer
          ? null
          : (loyaltyCustomer ?? this.loyaltyCustomer),
      bonusToUse: bonusToUse ?? this.bonusToUse,
      iin: clearIin ? null : (iin ?? this.iin),
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : (error ?? this.error),
      activeInput: activeInput ?? this.activeInput,
      cashInputText: cashInputText ?? this.cashInputText,
      cardInputText: cardInputText ?? this.cardInputText,
      terminalApprovalCode: clearTerminalData
          ? null
          : (terminalApprovalCode ?? this.terminalApprovalCode),
      terminalCardMask: clearTerminalData
          ? null
          : (terminalCardMask ?? this.terminalCardMask),
      terminalTransactionId: clearTerminalData
          ? null
          : (terminalTransactionId ?? this.terminalTransactionId),
    );
  }
}

class PaymentNotifier extends Notifier<PaymentState> {
  @override
  PaymentState build() {
    return PaymentState(totalAmount: Decimal.zero);
  }

  void initialize(Decimal amount) {
    state = PaymentState(totalAmount: amount);
  }

  void setPaymentType(PaymentType type) {
    state = state.copyWith(
      paymentType: type,
      cashReceived: Decimal.zero,
      cardAmount: Decimal.zero,
      clearError: true,
      activeInput: PaymentInputField.cash,
      cashInputText: '',
      cardInputText: '',
      clearTerminalData: true,
    );

    if (type == PaymentType.card || type == PaymentType.mixed) {
      _autoSelectBankAccount();
    } else {
      _autoSelectPosAccount();
    }
  }

  Future<void> _autoSelectBankAccount() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final bankAccounts = await db.accountDao.findByType(
        AccountType.customBank,
      );
      if (bankAccounts.isNotEmpty) {
        state = state.copyWith(selectedAccountId: bankAccounts.first.id);
      }
    } catch (_) {}
  }

  Future<void> _autoSelectPosAccount() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final posAccounts = await db.accountDao.findByType(AccountType.pos);
      if (posAccounts.isNotEmpty) {
        state = state.copyWith(selectedAccountId: posAccounts.first.id);
      }
    } catch (_) {}
  }

  void setCashReceived(Decimal amount) {
    final text = amount > Decimal.zero ? amount.toString() : '';
    state = state.copyWith(
      cashReceived: amount,
      cashInputText: text,
      clearError: true,
    );
  }

  void addCash(Decimal amount) {
    final newAmount = state.cashReceived + amount;
    state = state.copyWith(
      cashReceived: newAmount,
      cashInputText: newAmount.toString(),
      clearError: true,
    );
  }

  void setExactAmount() {
    state = state.copyWith(
      cashReceived: state.amountToPay,
      cashInputText: state.amountToPay.toString(),
      clearError: true,
    );
  }

  void clearCashReceived() {
    state = state.copyWith(cashReceived: Decimal.zero, cashInputText: '');
  }

  void setCardAmount(Decimal amount) {
    final text = amount > Decimal.zero ? amount.toString() : '';
    state = state.copyWith(
      cardAmount: amount,
      cardInputText: text,
      clearError: true,
    );
  }

  void setActiveInput(PaymentInputField field) {
    state = state.copyWith(activeInput: field);
  }

  void numpadKey(String key) {
    if (state.activeInput == PaymentInputField.cash) {
      final newText = state.cashInputText + key;
      final amount = Decimal.tryParse(newText) ?? Decimal.zero;
      state = state.copyWith(
        cashInputText: newText,
        cashReceived: amount,
        clearError: true,
      );
    } else {
      final newText = state.cardInputText + key;
      final amount = Decimal.tryParse(newText) ?? Decimal.zero;
      state = state.copyWith(
        cardInputText: newText,
        cardAmount: amount,
        clearError: true,
      );
    }
  }

  void numpadBackspace() {
    if (state.activeInput == PaymentInputField.cash) {
      if (state.cashInputText.isEmpty) return;
      final newText = state.cashInputText.substring(
        0,
        state.cashInputText.length - 1,
      );
      final amount = newText.isEmpty
          ? Decimal.zero
          : (Decimal.tryParse(newText) ?? Decimal.zero);
      state = state.copyWith(cashInputText: newText, cashReceived: amount);
    } else {
      if (state.cardInputText.isEmpty) return;
      final newText = state.cardInputText.substring(
        0,
        state.cardInputText.length - 1,
      );
      final amount = newText.isEmpty
          ? Decimal.zero
          : (Decimal.tryParse(newText) ?? Decimal.zero);
      state = state.copyWith(cardInputText: newText, cardAmount: amount);
    }
  }

  void numpadClear() {
    if (state.activeInput == PaymentInputField.cash) {
      state = state.copyWith(cashReceived: Decimal.zero, cashInputText: '');
    } else {
      state = state.copyWith(cardAmount: Decimal.zero, cardInputText: '');
    }
  }

  void selectAccount(int accountId) {
    state = state.copyWith(selectedAccountId: accountId);
  }

  Future<void> searchLoyaltyCustomer(String phone) async {
    if (phone.length < 10) {
      state = state.copyWith(clearLoyaltyCustomer: true);
      return;
    }

    try {
      final db = GetIt.I<AppDatabase>();

      final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
      final phoneInt = int.tryParse(phoneDigits);
      if (phoneInt == null) {
        state = state.copyWith(clearLoyaltyCustomer: true);
        return;
      }

      final agent = await db.agentDao.findByPhone(phoneInt);
      if (agent == null) {
        state = state.copyWith(clearLoyaltyCustomer: true);
        return;
      }

      Decimal bonusBalance = Decimal.zero;
      if (agent.cashbackAccountId != null) {
        final account = await db.accountDao.findById(agent.cashbackAccountId!);
        bonusBalance = account?.value ?? Decimal.zero;
      }

      state = state.copyWith(
        loyaltyCustomer: LoyaltyCustomer(
          id: agent.localId,
          phone: phone,
          name: agent.name ?? 'Client',
          bonusBalance: bonusBalance,
        ),
      );
    } catch (e) {
      state = state.copyWith(clearLoyaltyCustomer: true);
    }
  }

  void clearLoyaltyCustomer() {
    state = state.copyWith(
      clearLoyaltyCustomer: true,
      bonusToUse: Decimal.zero,
    );
  }

  void setBonusToUse(Decimal amount) {
    final maxBonus = state.availableBonus;
    final maxAllowed = state.totalAmount;

    Decimal effectiveAmount = amount;
    if (effectiveAmount > maxBonus) {
      effectiveAmount = maxBonus;
    }
    if (effectiveAmount > maxAllowed) {
      effectiveAmount = maxAllowed;
    }
    if (effectiveAmount < Decimal.zero) {
      effectiveAmount = Decimal.zero;
    }

    state = state.copyWith(bonusToUse: effectiveAmount);
  }

  void useAllBonus() {
    setBonusToUse(state.availableBonus);
  }

  void setIin(String? iin) {
    if (iin == null || iin.isEmpty) {
      state = state.copyWith(clearIin: true);
    } else {
      state = state.copyWith(iin: iin);
    }
  }

  /// Kaspi POS terminal connection, read from **this terminal's**
  /// `payment.kaspi.pos` device binding (docs/system-architecture.md,
  /// section 8, И27) — not the old installation-wide `hardware_settings`
  /// blob, which no longer exists (plan 2, task 3). `null` covers every
  /// "nothing to charge through" case alike: no binding, more than one
  /// (ambiguous — `resolveTerminalDeviceBindings` and this both refuse to
  /// guess), a binding missing its required parameters, or the setup wizard
  /// not having run yet. Every caller already falls back to the manual card
  /// path when this is `null` (see [chargeCardViaTerminal]), so refusing
  /// here is safe, never a blocker.
  Future<KaspiPosConfig?> _loadKaspiConfig() async {
    try {
      if (!GetIt.I.isRegistered<TerminalRepository>() ||
          !GetIt.I.isRegistered<AppDatabase>()) {
        return null;
      }

      final terminal = await GetIt.I<TerminalRepository>().self();
      final bindings = await resolveTerminalDeviceBindings(
        database: GetIt.I<AppDatabase>(),
        terminalId: terminal.id,
        catalog: BuiltinDeviceProfileCatalog(),
        deviceClass: DeviceClass.paymentTerminal,
      );
      if (bindings.length != 1) return null;

      final binding = bindings.single;
      final host = binding.parameters['ipAddress']?.trim();
      if (host == null || host.isEmpty) return null;
      final port =
          int.tryParse(binding.parameters['port'] ?? '') ??
          KaspiPosConfig.defaultPort;

      final config = KaspiPosConfig(host: host, port: port, enabled: true);
      return config.isValid ? config : null;
    } catch (_) {
      return null;
    }
  }

  Future<CardTerminalResult> chargeCardViaTerminal(Decimal amount) async {
    final config = await _loadKaspiConfig();
    if (config == null) {
      talker.info(
        'Payment: Kaspi terminal not configured — using manual card path',
      );
      return const CardTerminalResult(
        outcome: CardTerminalOutcome.notConfigured,
      );
    }

    final service = KaspiPosService(config: config);
    try {
      final amountKopeiki = (amount * Decimal.fromInt(100))
          .round()
          .toBigInt()
          .toInt();

      final saleState = ref.read(saleControllerProvider);
      final receiptNo = (saleState.receiptNo ?? 0).toString();

      talker.info(
        'Payment: requesting Kaspi terminal charge '
        'amount=$amountKopeiki tiyn, receiptNo=$receiptNo',
      );

      final result = await service.requestPayment(
        amountKopeiki: amountKopeiki,
        receiptNo: receiptNo,
      );

      if (result.success) {
        talker.info(
          'Payment: Kaspi terminal APPROVED '
          'approval=${result.approvalCode}, mask=${result.cardMask}, '
          'txId=${result.transactionId}',
        );
        state = state.copyWith(
          terminalApprovalCode: result.approvalCode,
          terminalCardMask: result.cardMask,
          terminalTransactionId: result.transactionId,
        );
        return CardTerminalResult(
          outcome: CardTerminalOutcome.approved,
          approvalCode: result.approvalCode,
          cardMask: result.cardMask,
          transactionId: result.transactionId,
        );
      }

      talker.warning(
        'Payment: Kaspi terminal DECLINED — ${result.errorMessage}',
      );
      return CardTerminalResult(
        outcome: CardTerminalOutcome.declined,
        message: result.errorMessage,
      );
    } catch (e, stack) {
      talker.error('Payment: Kaspi terminal error: $e', e, stack);
      return CardTerminalResult(
        outcome: CardTerminalOutcome.declined,
        message: '$e',
      );
    } finally {
      service.dispose();
    }
  }

  void setProcessing(bool value) => state = state.copyWith(isProcessing: value);

  Future<bool> processPayment() async {
    talker.info(
      'Payment: processPayment called, canComplete=${state.canComplete}, '
      'type=${state.paymentType}, amount=${state.amountToPay}, cash=${state.cashReceived}',
    );
    if (!state.canComplete) return false;

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final db = GetIt.I<AppDatabase>();

      final thisPos = await db.thisPosDao.get();
      var posAccountId = thisPos?.accountId;

      if (posAccountId == null) {
        final posAccounts = await db.accountDao.findByType(AccountType.pos);
        if (posAccounts.isNotEmpty) {
          posAccountId = posAccounts.first.id;
          talker.info(
            'Payment: auto-found posAccountId=$posAccountId from accounts',
          );
        } else {
          posAccountId = await db.accountDao.createPosAccount(name: 'POS');
          talker.info('Payment: auto-created posAccountId=$posAccountId');
        }
      }
      talker.info('Payment: posAccountId=$posAccountId');

      int? bankAccountId = state.selectedAccountId;
      talker.info(
        'Payment: selectedAccountId=$bankAccountId, paymentType=${state.paymentType}',
      );
      if (bankAccountId == null && state.paymentType != PaymentType.cash) {
        final bankAccounts = await db.accountDao.findByTypeAndVisibility(
          AccountType.customBank,
          true,
        );
        talker.info('Payment: found ${bankAccounts.length} bank accounts');
        if (bankAccounts.isNotEmpty) {
          bankAccountId = bankAccounts.first.id;
        } else {
          bankAccountId = await db.accountDao.createAcquiringAccount(
            name: 'Bank (card)',
            acquirerId: 0,
          );
          talker.info('Payment: auto-created bankAccountId=$bankAccountId');
        }
      }

      final payments = <PaymentEntry>[];

      switch (state.paymentType) {
        case PaymentType.cash:
          if (posAccountId != null) {
            payments.add(
              PaymentEntry(
                payeeAccountId: posAccountId,
                amount: state.amountToPay,
                customerLocalId: state.loyaltyCustomer?.id,
              ),
            );
          }
          break;

        case PaymentType.card:
          final accountId = bankAccountId ?? posAccountId;
          if (accountId != null) {
            payments.add(
              PaymentEntry(
                payeeAccountId: accountId,
                amount: state.amountToPay,
                customerLocalId: state.loyaltyCustomer?.id,
                approvalCode: state.terminalApprovalCode,
                cardMask: state.terminalCardMask,
                terminalTransactionId: state.terminalTransactionId,
              ),
            );
          }
          break;

        case PaymentType.mixed:
          final cashPortion = state.amountToPay - state.cardAmount;
          if (cashPortion > Decimal.zero && posAccountId != null) {
            payments.add(
              PaymentEntry(
                payeeAccountId: posAccountId,
                amount: cashPortion,
                customerLocalId: state.loyaltyCustomer?.id,
              ),
            );
          }
          final cardAccountId = bankAccountId ?? state.selectedAccountId;
          if (state.cardAmount > Decimal.zero && cardAccountId != null) {
            payments.add(
              PaymentEntry(
                payeeAccountId: cardAccountId,
                amount: state.cardAmount,
                customerLocalId: state.loyaltyCustomer?.id,
                approvalCode: state.terminalApprovalCode,
                cardMask: state.terminalCardMask,
                terminalTransactionId: state.terminalTransactionId,
              ),
            );
          }
          break;
      }

      if (state.bonusToUse > Decimal.zero && state.loyaltyCustomer != null) {
        final customerLocalId = state.loyaltyCustomer!.id;
        final agent = await db.agentDao.findByLocalId(customerLocalId);
        final cashbackAccountId = agent?.cashbackAccountId;
        if (cashbackAccountId != null) {
          payments.add(
            PaymentEntry(
              payeeAccountId: cashbackAccountId,
              amount: state.bonusToUse,
              customerLocalId: customerLocalId,
            ),
          );
          talker.info(
            'Payment: bonus redemption ${state.bonusToUse} '
            'against cashback account $cashbackAccountId',
          );
        } else {
          talker.warning(
            'Payment: bonusToUse>0 but customer '
            '$customerLocalId has no cashback account — aborting',
          );
          state = state.copyWith(
            isProcessing: false,
            error: 'error.payment_config',
          );
          return false;
        }
      }

      talker.info('Payment: payments count=${payments.length}');
      if (payments.isEmpty) {
        talker.warning(
          'Payment: no payment entries — check posAccountId or selectedAccountId',
        );
        state = state.copyWith(
          isProcessing: false,
          error: 'error.payment_config',
        );
        return false;
      }

      talker.info('Payment: calling completeSale...');
      final saleNotifier = ref.read(saleControllerProvider.notifier);
      final success = await saleNotifier.completeSale(
        payments: payments,
        change: state.change,
        customerBin: state.iin,
      );

      talker.info('Payment: completeSale result=$success');
      if (!success) {
        final saleErr = ref.read(saleControllerProvider).error;
        talker.warning('Payment: completeSale failed, saleError=$saleErr');
        state = state.copyWith(
          isProcessing: false,
          error: (saleErr != null && saleErr.isNotEmpty)
              ? saleErr
              : 'error.sale_save_failed',
        );
        return false;
      }

      await _accrueCashback();

      state = state.copyWith(isProcessing: false);
      return true;
    } catch (e, stack) {
      talker.error('Payment: processPayment error: $e', e, stack);
      state = state.copyWith(
        isProcessing: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return false;
    }
  }

  Future<void> _accrueCashback() async {
    try {
      final customer = state.loyaltyCustomer;
      if (customer == null) return;
      final base = state.amountToPay;
      if (base <= Decimal.zero) return;
      final phoneInt = int.tryParse(
        customer.phone.replaceAll(RegExp(r'\D'), ''),
      );
      if (phoneInt == null) return;
      final receiptNo = ref.read(saleControllerProvider).receiptNo ?? 0;
      final result = await GetIt.I<BonusService>().accrualBonuses(
        phone: phoneInt,
        saleAmount: base,
        saleReceiptNo: receiptNo,
      );
      talker.info(
        'Payment: cashback accrued ${result.accruedAmount} -> ${result.newBalance}',
      );
    } catch (e, st) {
      talker.warning(
        'Payment: cashback accrual failed (non-blocking): $e',
        e,
        st,
      );
    }
  }
}

final paymentControllerProvider =
    NotifierProvider<PaymentNotifier, PaymentState>(PaymentNotifier.new);

final paymentAccountsProvider = FutureProvider<List<PaymentAccount>>((
  ref,
) async {
  try {
    final db = GetIt.I<AppDatabase>();

    final accounts = await db.accountDao.findByTypeAndVisibility(
      AccountType.customBank,
      true,
    );

    final posAccounts = await db.accountDao.findByType(AccountType.pos);

    final allAccounts = [...posAccounts, ...accounts];

    return allAccounts
        .map(
          (a) => PaymentAccount(
            id: a.id,
            name: a.name ?? 'Account ${a.id}',
            isDefault: a.type == AccountType.pos,
          ),
        )
        .toList();
  } catch (e) {
    return const [];
  }
});

List<Decimal> _getDenominationsForCountry(int? countryCode) {
  switch (countryCode) {
    case 1:
      return [
        50,
        100,
        200,
        500,
        1000,
        2000,
        5000,
      ].map(Decimal.fromInt).toList();
    case 2:
      return [20, 50, 100, 200, 500, 1000, 5000].map(Decimal.fromInt).toList();
    case 3:
      return [
        1000,
        5000,
        10000,
        20000,
        50000,
        100000,
        200000,
      ].map(Decimal.fromInt).toList();
    case 4:
      return [1, 5, 10, 20, 50, 100].map(Decimal.fromInt).toList();
    case 5:
      return [1, 5, 10, 20, 50, 100, 500].map(Decimal.fromInt).toList();
    case 0:
    default:
      return [
        200,
        500,
        1000,
        2000,
        5000,
        10000,
        20000,
      ].map(Decimal.fromInt).toList();
  }
}

final denominationsProvider = FutureProvider<List<Decimal>>((ref) async {
  try {
    final db = GetIt.I<AppDatabase>();
    final thisPos = await db.thisPosDao.get();
    return _getDenominationsForCountry(thisPos?.countryCode);
  } catch (_) {
    return _getDenominationsForCountry(null);
  }
});

final canCompletePaymentProvider = Provider<bool>((ref) {
  return ref.watch(paymentControllerProvider.select((s) => s.canComplete));
});

final thisPosProvider = FutureProvider<ThisPosEntry?>((ref) async {
  try {
    return await GetIt.I<AppDatabase>().thisPosDao.get();
  } catch (_) {
    return null;
  }
});

final changeAmountProvider = Provider<Decimal>((ref) {
  return ref.watch(paymentControllerProvider.select((s) => s.change));
});
