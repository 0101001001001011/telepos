import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

class CashInOutControllerImpl implements CashInOutController {
  CashInOutControllerImpl(this._db, {FiscalService? fiscalService})
    : _fiscalServiceOverride = fiscalService;

  final AppDatabase _db;
  Talker get _logger => GetIt.I<Talker>();

  final FiscalService? _fiscalServiceOverride;

  FiscalService? _resolveFiscalService() {
    if (_fiscalServiceOverride != null) return _fiscalServiceOverride;
    if (GetIt.I.isRegistered<FiscalService>()) {
      return GetIt.I<FiscalService>();
    }
    return null;
  }

  void _fiscalizeCashOperation({
    required CashInOutType type,
    required Decimal amount,
    required int operationId,
    String? note,
  }) {
    final fiscal = _resolveFiscalService();
    if (fiscal == null) return;

    final idem = 'cashop:$operationId';
    final isMoneyIn = type == CashInOutType.investment;

    Future<void>(() async {
      try {
        final result = isMoneyIn
            ? await fiscal.moneyIn(
                amount: amount,
                comment: note,
                idempotencyKey: idem,
              )
            : await fiscal.moneyOut(
                amount: amount,
                comment: note,
                idempotencyKey: idem,
              );
        if (result.success) {
          _logger.info(
            'Cash op fiscalized (${isMoneyIn ? 'moneyIn' : 'moneyOut'}) '
            '${result.queued ? 'queued' : 'ok'}: op=$operationId, amount=$amount',
          );
        } else {
          _logger.warning(
            'Cash op fiscalization failed: op=$operationId, '
            '${result.errorMessage}',
          );
        }
      } catch (e, st) {
        _logger.warning(
          'Cash op fiscalization error: op=$operationId, $e',
          e,
          st,
        );
      }
    });
  }

  @override
  Future<CashOperationResult> createInvestment({
    required Decimal amount,
    required int accountId,
    String? note,
  }) async {
    final validation = await validateAmount(amount);
    if (!validation.isValid) {
      return CashOperationResult.failed(validation.errorMessage!);
    }

    return _createOperation(
      type: CashInOutType.investment,
      amount: amount,
      accountId: accountId,
      note: note,
    );
  }

  @override
  Future<CashOperationResult> createExpense({
    required Decimal amount,
    required int accountId,
    required ExpenseType expenseType,
    String? note,
    int? customFieldItemId,
  }) async {
    final validation = await validateAmount(amount);
    if (!validation.isValid) {
      return CashOperationResult.failed(validation.errorMessage!);
    }

    if (expenseType.requiresNote && (note == null || note.trim().isEmpty)) {
      return CashOperationResult.failed(
        'Для типа "Другое" необходимо указать комментарий',
      );
    }

    final result = await _createOperation(
      type: CashInOutType.expense,
      amount: amount,
      accountId: accountId,
      note: _buildExpenseNote(expenseType, note),
    );

    if (result.success && customFieldItemId != null) {
      await _db.cashOperationDao.db
          .into(_db.cashOperationCustomFields)
          .insert(
            CashOperationCustomFieldsCompanion.insert(
              cashOperationId: Value(result.operationId),
              customFieldItemId: Value(customFieldItemId),
            ),
          );
    }

    return result;
  }

  @override
  Future<CashOperationResult> createDividend({
    required Decimal amount,
    required int accountId,
    String? note,
  }) async {
    final validation = await validateAmount(amount);
    if (!validation.isValid) {
      return CashOperationResult.failed(validation.errorMessage!);
    }

    return _createOperation(
      type: CashInOutType.dividend,
      amount: amount,
      accountId: accountId,
      note: note,
    );
  }

  @override
  Future<CashOperationResult> createInkassaciya({
    required Decimal amount,
    required int fromAccountId,
    int? toAccountId,
    String? note,
  }) async {
    final validation = await validateAmount(amount);
    if (!validation.isValid) {
      return CashOperationResult.failed(validation.errorMessage!);
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      int? userId;
      final openedShift = await _db.shiftDao.findOpenedShift();
      if (openedShift != null) {
        userId = openedShift.userId;
      }

      final operationId = await _db.transaction(() async {
        int destId;
        if (toAccountId != null) {
          destId = toAccountId;
        } else {
          final dest = await _db.accountDao.findInkassaciyaDestination(
            excludeId: fromAccountId,
          );
          if (dest == null) {
            throw Exception(
              'Не найден счёт назначения для инкассации (банк/сейф)',
            );
          }
          destId = dest.id;
        }

        if (destId == fromAccountId) {
          throw Exception(
            'Счёт назначения инкассации не может совпадать с кассовым счётом',
          );
        }

        await _db.accountDao.transfer(
          fromId: fromAccountId,
          toId: destId,
          amount: amount,
        );

        _logger.info(
          'Inkassaciya (transfer): $amount from account $fromAccountId '
          'to account $destId',
        );

        final id = await _db.cashOperationDao.insert(
          CashOperationsCompanion.insert(
            amount: amount,
            type: CashInOutType.expense.index,
            accountId: Value(fromAccountId),
            userId: Value(userId),
            note: Value(_buildExpenseNote(ExpenseType.collection, note)),
            docTime: Value(now),
            state: const Value(1),
          ),
        );

        return id;
      });

      _fiscalizeCashOperation(
        type: CashInOutType.expense,
        amount: amount,
        operationId: operationId,
        note: _buildExpenseNote(ExpenseType.collection, note),
      );

      return CashOperationResult.created(operationId);
    } catch (e) {
      _logger.error('Failed to create inkassaciya: $e');
      return CashOperationResult.failed('Ошибка инкассации: $e');
    }
  }

  @override
  Future<List<CashOperationInfo>> getOperationsForShift(int shiftId) async {
    final shift = await _db.shiftDao.findById(shiftId);

    List<CashOperation> operations;

    if (shift != null) {
      final fromTime = shift.openTime;
      final toTime = shift.isOpened ? null : shift.closeTime;

      operations = await _db.cashOperationDao.findByTimeRange(
        fromTime,
        toTime: toTime,
      );

      _logger.debug(
        'CashInOut: found ${operations.length} operations for shift $shiftId '
        '(from ${DateTime.fromMillisecondsSinceEpoch(fromTime * 1000)})',
      );
    } else {
      _logger.warning('CashInOut: shift $shiftId not found');
      operations = [];
    }

    return operations.map((op) {
      return CashOperationInfo(
        id: op.id,
        type: CashInOutTypeExtension.fromIndex(op.type),
        amount: op.amount,
        accountId: op.accountId ?? 0,
        note: op.note,
        docTime: DateTime.fromMillisecondsSinceEpoch((op.docTime ?? 0) * 1000),
      );
    }).toList();
  }

  @override
  Future<CashOperationValidation> validateAmount(Decimal amount) async {
    if (amount <= Decimal.zero) {
      return CashOperationValidation.invalid('Сумма должна быть больше 0');
    }

    final pos = await _db.thisPosDao.get();
    final allowBig = pos?.allowBigAmount ?? false;
    final cap = allowBig
        ? Decimal.fromInt(1000000000)
        : CashInOutController.maxAmount;

    if (amount > cap) {
      return CashOperationValidation.invalid('Сумма не может превышать $cap');
    }

    return CashOperationValidation.valid();
  }

  Future<CashOperationResult> _createOperation({
    required CashInOutType type,
    required Decimal amount,
    required int accountId,
    String? note,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      int? userId;
      final openedShift = await _db.shiftDao.findOpenedShift();
      if (openedShift != null) {
        userId = openedShift.userId;
      }

      final operationId = await _db.transaction(() async {
        final account = await _db.accountDao.findById(accountId);
        if (account == null) {
          throw Exception('Счёт не найден: $accountId');
        }

        final currentBalance = account.value ?? Decimal.zero;

        Decimal newBalance;
        switch (type) {
          case CashInOutType.investment:
            newBalance = currentBalance + amount;
            break;
          case CashInOutType.expense:
            newBalance = currentBalance - amount;
            break;
          case CashInOutType.dividend:
            if (currentBalance < amount) {
              throw Exception(
                'Недостаточно средств. Баланс: $currentBalance, запрошено: $amount',
              );
            }
            newBalance = currentBalance - amount;
            break;
        }

        await _db.accountDao.updateBalance(accountId, newBalance);

        _logger.info(
          'CashOperation: $type, account $accountId, '
          'balance $currentBalance → $newBalance (${type == CashInOutType.investment ? '+' : '-'}$amount)',
        );

        final id = await _db.cashOperationDao.insert(
          CashOperationsCompanion.insert(
            amount: amount,
            type: type.index,
            accountId: Value(accountId),
            userId: Value(userId),
            note: Value(note),
            docTime: Value(now),
            state: const Value(1),
          ),
        );

        return id;
      });

      _fiscalizeCashOperation(
        type: type,
        amount: amount,
        operationId: operationId,
        note: note,
      );

      return CashOperationResult.created(operationId);
    } catch (e) {
      _logger.error('Failed to create cash operation: $e');
      return CashOperationResult.failed('Ошибка создания операции: $e');
    }
  }

  String? _buildExpenseNote(ExpenseType expenseType, String? note) {
    if (note != null && note.isNotEmpty) {
      return '${expenseType.displayName}: $note';
    }
    return expenseType.displayName;
  }

  @override
  Future<int> getPosAccountId() async {
    try {
      final thisPos = await _db.thisPosDao.get();
      return thisPos?.accountId ?? 1;
    } catch (_) {
      return 1;
    }
  }

}
