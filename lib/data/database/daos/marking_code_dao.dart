import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'marking_code_dao.g.dart';

@DriftAccessor(tables: [MarkingCodes])
class MarkingCodeDao extends DatabaseAccessor<AppDatabase>
    with _$MarkingCodeDaoMixin {
  MarkingCodeDao(super.db);

  Future<MarkingCode?> findByCode(String code) => (select(
    markingCodes,
  )..where((m) => m.code.equals(code))).getSingleOrNull();

  Future<MarkingCode?> findById(int id) =>
      (select(markingCodes)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<List<MarkingCode>> findByUcode(int ucode) =>
      (select(markingCodes)..where((m) => m.ucode.equals(ucode))).get();

  Future<List<MarkingCode>> findBySupplyId(int supplyId) =>
      (select(markingCodes)..where((m) => m.supplyId.equals(supplyId))).get();

  Future<List<MarkingCode>> findBySaleId(int saleId) =>
      (select(markingCodes)..where((m) => m.saleId.equals(saleId))).get();

  Future<List<MarkingCode>> findChildren(int parentCodeId) => (select(
    markingCodes,
  )..where((m) => m.parentCodeId.equals(parentCodeId))).get();

  Future<int> insertCode(MarkingCodesCompanion code) =>
      into(markingCodes).insert(code);

  Future<int> updateCode(int id, MarkingCodesCompanion code) =>
      (update(markingCodes)..where((m) => m.id.equals(id))).write(code);

  Future<int> updateStatus(int id, int status) =>
      (update(markingCodes)..where((m) => m.id.equals(id))).write(
        MarkingCodesCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        ),
      );
}
