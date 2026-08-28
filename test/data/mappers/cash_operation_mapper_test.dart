import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/cash_operation_mapper.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_entity.dart';

void main() {
  group('CashOperationMapper', () {
    test('fromDrift converts all fields', () {
      final driftOp = CashOperation(
        id: 1,
        storeId: 10,
        amount: Decimal.parse('5000.500'),
        accountId: 20,
        type: 0,
        userId: 5,
        note: 'Размен',
        docTime: 1700000000,
        state: 1,
      );

      final entity = CashOperationMapper.fromDrift(driftOp);

      expect(entity.id, 1);
      expect(entity.storeId, 10);
      expect(entity.amount, Decimal.parse('5000.500'));
      expect(entity.accountId, 20);
      expect(entity.type, 0);
      expect(entity.userId, 5);
      expect(entity.note, 'Размен');
      expect(entity.docTime, 1700000000);
      expect(entity.state, 1);
    });

    test('fromDrift with nullable fields null', () {
      final driftOp = CashOperation(
        id: 1,
        amount: Decimal.parse('1000.000'),
        type: 1,
      );

      final entity = CashOperationMapper.fromDrift(driftOp);

      expect(entity.id, 1);
      expect(entity.storeId, isNull);
      expect(entity.accountId, isNull);
      expect(entity.userId, isNull);
      expect(entity.note, isNull);
      expect(entity.docTime, isNull);
      expect(entity.state, isNull);
    });

    test('toDrift creates companion', () {
      final entity = CashOperationEntity(
        storeId: 10,
        amount: Decimal.parse('5000.500'),
        accountId: 20,
        type: 0,
        userId: 5,
        note: 'Размен',
        docTime: 1700000000,
        state: 1,
      );

      final companion = CashOperationMapper.toDrift(entity);

      expect(companion.storeId.value, 10);
      expect(companion.amount.value, Decimal.parse('5000.500'));
      expect(companion.accountId.value, 20);
      expect(companion.type.value, 0);
      expect(companion.userId.value, 5);
      expect(companion.note.value, 'Размен');
      expect(companion.docTime.value, 1700000000);
      expect(companion.state.value, 1);
    });

    test('round-trip preserves data', () {
      final original = CashOperationEntity(
        id: 3,
        storeId: 10,
        amount: Decimal.parse('15000.750'),
        accountId: 20,
        type: 2,
        userId: 5,
        note: 'Изъятие инкассация',
        docTime: 1700036000,
        state: 0,
      );

      final companion = CashOperationMapper.toDrift(original);

      final driftOp = CashOperation(
        id: companion.id.value,
        storeId: companion.storeId.value,
        amount: companion.amount.value,
        accountId: companion.accountId.value,
        type: companion.type.value,
        userId: companion.userId.value,
        note: companion.note.value,
        docTime: companion.docTime.value,
        state: companion.state.value,
      );

      final restored = CashOperationMapper.fromDrift(driftOp);

      expect(restored.id, original.id);
      expect(restored.storeId, original.storeId);
      expect(restored.amount, original.amount);
      expect(restored.accountId, original.accountId);
      expect(restored.type, original.type);
      expect(restored.userId, original.userId);
      expect(restored.note, original.note);
      expect(restored.docTime, original.docTime);
      expect(restored.state, original.state);
    });

    test('fromDriftList maps multiple', () {
      final operations = [
        CashOperation(id: 1, amount: Decimal.parse('5000.000'), type: 0),
        CashOperation(id: 2, amount: Decimal.parse('3000.000'), type: 1),
        CashOperation(id: 3, amount: Decimal.parse('8000.000'), type: 2),
      ];

      final entities = CashOperationMapper.fromDriftList(operations);
      expect(entities.length, 3);
      expect(entities[0].type, 0);
      expect(entities[0].isInvestment, true);
      expect(entities[1].type, 1);
      expect(entities[1].isExpense, true);
      expect(entities[2].type, 2);
      expect(entities[2].isDividend, true);
    });
  });
}
