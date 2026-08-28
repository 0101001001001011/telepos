import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/agent/edit_agent_use_case.dart';

class EditAgentUseCaseImpl implements EditAgentUseCase {
  EditAgentUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<bool> edit({
    required int localId,
    String? name,
    int? phone,
    String? bin,
    String? legalName,
    String? legalType,
    String? legalAddress,
    String? actualAddress,
    String? note,
  }) async {
    if (name == null &&
        phone == null &&
        bin == null &&
        legalName == null &&
        legalType == null &&
        legalAddress == null &&
        actualAddress == null &&
        note == null) {
      return true;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final rowsAffected =
        await (_db.update(
          _db.agents,
        )..where((a) => a.localId.equals(localId))).write(
          AgentsCompanion(
            name: name != null ? Value(name) : const Value.absent(),
            phone: phone != null ? Value(phone) : const Value.absent(),
            bin: bin != null ? Value(bin) : const Value.absent(),
            legalName: legalName != null
                ? Value(legalName)
                : const Value.absent(),
            legalType: legalType != null
                ? Value(legalType)
                : const Value.absent(),
            legalAddress: legalAddress != null
                ? Value(legalAddress)
                : const Value.absent(),
            actualAddress: actualAddress != null
                ? Value(actualAddress)
                : const Value.absent(),
            note: note != null ? Value(note) : const Value.absent(),
            editTime: Value(now),
          ),
        );

    if (rowsAffected > 0) {
      _logger.info('EditAgent: updated localId=$localId');
      return true;
    }

    _logger.warning('EditAgent: agent localId=$localId not found');
    return false;
  }

  @override
  Future<bool> updateType(int localId, int type) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final rowsAffected =
        await (_db.update(_db.agents)..where((a) => a.localId.equals(localId)))
            .write(AgentsCompanion(type: Value(type), editTime: Value(now)));

    if (rowsAffected > 0) {
      _logger.info('EditAgent: updated type=$type for localId=$localId');
      return true;
    }

    _logger.warning('EditAgent: agent localId=$localId not found');
    return false;
  }

  @override
  Future<bool> delete(int localId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final rowsAffected =
        await (_db.update(
          _db.agents,
        )..where((a) => a.localId.equals(localId))).write(
          AgentsCompanion(isDeleted: const Value(true), editTime: Value(now)),
        );

    if (rowsAffected > 0) {
      _logger.info('EditAgent: soft deleted localId=$localId');
      return true;
    }

    _logger.warning('EditAgent: agent localId=$localId not found');
    return false;
  }
}
