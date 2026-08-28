import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/organization_tables.dart';

part 'agent_local_contact_dao.g.dart';

@DriftAccessor(tables: [AgentLocalContacts, Agents])
class AgentLocalContactDao extends DatabaseAccessor<AppDatabase>
    with _$AgentLocalContactDaoMixin {
  AgentLocalContactDao(super.db);

  Future<AgentLocalContact?> findForAgent(int agentLocalId, String posKey) =>
      (select(agentLocalContacts)..where(
            (c) =>
                c.agentLocalId.equals(agentLocalId) & c.posKey.equals(posKey),
          ))
          .getSingleOrNull();

  Future<List<AgentLocalContact>> findAllForPos(String posKey) =>
      (select(agentLocalContacts)..where((c) => c.posKey.equals(posKey))).get();

  Future<List<AgentWithLocalContact>> findAgentsWithContacts(
    String posKey, {
    int? agentType,
    String? search,
    int limit = 100,
  }) async {
    var query = select(agents).join([
      leftOuterJoin(
        agentLocalContacts,
        agentLocalContacts.agentLocalId.equalsExp(agents.localId) &
            agentLocalContacts.posKey.equals(posKey),
      ),
    ]);

    if (agentType != null) {
      query = query
        ..where(agents.type.equals(agentType) & agents.isDeleted.equals(false));
    } else {
      query = query..where(agents.isDeleted.equals(false));
    }

    if (search != null && search.isNotEmpty) {
      query = query..where(agents.name.like('%$search%'));
    }

    query = query
      ..orderBy([OrderingTerm.desc(agents.editTime)])
      ..limit(limit);

    final rows = await query.get();
    return rows.map((row) {
      return AgentWithLocalContact(
        agent: row.readTable(agents),
        localContact: row.readTableOrNull(agentLocalContacts),
      );
    }).toList();
  }

  Future<int> upsert(AgentLocalContactsCompanion contact) async {
    final existing = await findForAgent(
      contact.agentLocalId.value,
      contact.posKey.value,
    );

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (existing != null) {
      return (update(agentLocalContacts)
            ..where((c) => c.id.equals(existing.id)))
          .write(contact.copyWith(updatedAt: Value(now)));
    } else {
      return into(
        agentLocalContacts,
      ).insert(contact.copyWith(createdAt: Value(now), updatedAt: Value(now)));
    }
  }

  Future<int> deleteForAgent(int agentLocalId, String posKey) =>
      (delete(agentLocalContacts)..where(
            (c) =>
                c.agentLocalId.equals(agentLocalId) & c.posKey.equals(posKey),
          ))
          .go();

  Future<int> deleteAllForPos(String posKey) =>
      (delete(agentLocalContacts)..where((c) => c.posKey.equals(posKey))).go();

  Future<int> countForPos(String posKey) {
    final expr = agentLocalContacts.id.count();
    return (selectOnly(agentLocalContacts)
          ..addColumns([expr])
          ..where(agentLocalContacts.posKey.equals(posKey)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }
}

class AgentWithLocalContact {
  final Agent agent;
  final AgentLocalContact? localContact;

  const AgentWithLocalContact({required this.agent, this.localContact});

  String? get contactName => localContact?.contactName;

  String? get contactPhone =>
      localContact?.contactPhone ?? agent.phone?.toString();

  String? get contactEmail => localContact?.contactEmail;

  String? get preferredContactMethod => localContact?.preferredContactMethod;

  bool get hasLocalContact => localContact != null;
}
