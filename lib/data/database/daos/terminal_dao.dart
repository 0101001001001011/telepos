import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/terminal_tables.dart';

part 'terminal_dao.g.dart';

@DriftAccessor(tables: [Terminals, TerminalDeviceBindings])
class TerminalDao extends DatabaseAccessor<AppDatabase>
    with _$TerminalDaoMixin {
  TerminalDao(super.db);

  /// Every device binding belonging to [terminalId] — one row per
  /// `DeviceClass` at most (`TerminalDeviceBindings`'s unique key on
  /// `(terminalId, deviceClass)`). Raw drift rows, not domain
  /// `DeviceBinding`s: decoding `parametersJson`/`optionsJson` and picking a
  /// catalog to validate against is the assembling side's job (plan 2, task
  /// 3), not the DAO's.
  Future<List<TerminalDeviceBinding>> deviceBindingsFor(int terminalId) =>
      (select(
        terminalDeviceBindings,
      )..where((b) => b.terminalId.equals(terminalId))).get();

  Future<Terminal?> self() => (select(
    terminals,
  )..where((t) => t.isSelf.equals(true))).getSingleOrNull();

  Future<List<Terminal>> all() => select(terminals).get();

  /// Одна строка по `id` — «откуда» в паре «кто и откуда» при выдаче сеанса
  /// (задача 7). `null`, если терминал уже не существует: вызывающий решает,
  /// как это трактовать, а не DAO.
  Future<Terminal?> findById(int id) =>
      (select(terminals)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Терминал с этим именем, если он уже существует, — первый из найденных.
  ///
  /// До правки пункта 6 фазы 3/4 закрытия долга (2026-08-21) это был
  /// «известный идентификатор» для [LocalTerminalRepository.register]:
  /// клиент, повторивший то же имя, получал существующую строку вместо
  /// новой. Дедупликация снята оттуда — разбор нашёл, что она была не
  /// защитой, а дырой: `terminals.register` открыта (`OpenAccess`, без
  /// сеанса), и тот, кто узнал чужое имя терминала (`terminals.rename` даёт
  /// его выбрать человеку, значит оно не секрет), мог вызвать `register`
  /// этим именем и получить **ту же строку**, что и настоящий владелец —
  /// ровно тот обход, который закрывает пункт 2 (`terminalId` для
  /// `auth.login` берётся из того, что сессия сама зарегистрировала). Метод
  /// остаётся — он публичный контракт DAO и годится там, где имя ищут
  /// заведомо не как секрет (например, диагностика), — но `getSingleOrNull()`
  /// заменён на `.get()..firstOrNull`: два терминала с одинаковым именем не
  /// поддельны схемой (`name` не `unique`, см. пункт 6 отчёта) и не должны
  /// ронять вызывающего `StateError`.
  Future<Terminal?> findByName(String name) async {
    final rows = await (select(
      terminals,
    )..where((t) => t.name.equals(name))).get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Сколько строк сейчас в `terminals` — то, с чем
  /// [LocalTerminalRepository.register] сверяет потолок (задача 7 закрытия
  /// долга), прежде чем вставить ещё одну.
  Future<int> count() async {
    final countExp = terminals.id.count();
    final query = selectOnly(terminals)..addColumns([countExp]);
    return query.map((row) => row.read(countExp)!).getSingle();
  }

  /// Создаёт терминал этой машины, если его ещё нет. Повтор ничего не меняет:
  /// вызывается при каждом запуске.
  ///
  /// Читает и вставляет в одной транзакции — иначе два одновременных запуска
  /// могут оба увидеть "терминала ещё нет" и оба вставить строку. Структурная
  /// защита от этого — частичный уникальный индекс `terminals_single_self`
  /// (см. `AppDatabase._ensureSingleSelfTerminalIndex`), который не даёт
  /// физически появиться второй строке с isSelf=true. Проигравшая сторона
  /// ловит именно нарушение уникальности (не любую ошибку) и перечитывает
  /// self(), чтобы вернуть строку победителя — вызывающему нужен "терминал
  /// этой машины", а не именно та строка, которую вставил он сам.
  Future<Terminal> ensureSelf({required String fallbackName}) {
    return transaction(() async {
      final existing = await self();
      if (existing != null) return existing;

      try {
        final id = await into(terminals).insert(
          TerminalsCompanion.insert(
            name: fallbackName,
            isSelf: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
        return (select(terminals)..where((t) => t.id.equals(id))).getSingle();
      } on SqliteException catch (e) {
        if (!e.message.contains('UNIQUE constraint failed')) rethrow;

        final winner = await self();
        if (winner == null) rethrow;
        return winner;
      }
    });
  }

  Future<void> rename(int id, String name) =>
      (update(terminals)..where((t) => t.id.equals(id))).write(
        TerminalsCompanion(name: Value(name)),
      );

  /// Удаляет строку терминала безвозвратно.
  ///
  /// Названа `remove`, не `delete`: `DatabaseAccessor` уже даёт метод с этим
  /// именем — `delete<T extends Table, D>(TableInfo<T, D> table)`, которым
  /// эта же реализация строит запрос ниже (`delete(terminals)`). Метод с тем
  /// же именем `delete` и другой сигнатурой (`int id`) скрыл бы унаследованный
  /// для всего класса, и построить запрос было бы нечем.
  ///
  /// Привязки устройств терминала уходят тем же запросом, а не отдельным
  /// вызовом: `TerminalDeviceBindings.terminalId` объявлена
  /// `onDelete: KeyAction.cascade` (`terminal_tables.dart`), а
  /// `PRAGMA foreign_keys = ON` включена в `beforeOpen`
  /// (`AppDatabase`, действует и на `AppDatabase.forTesting`) — значит
  /// удаление строки терминала каскадом удаляет и все её привязки; они не
  /// остаются сиротами на несуществующий `terminalId`.
  ///
  /// Существование строки и запрет удалять `isSelf`-терминал — забота
  /// вызывающего ([LocalTerminalRepository.delete],
  /// `lib/data/terminal/terminal_repository_local.dart`), не этого метода:
  /// DAO не решает, что терминал самой кассы неприкосновенен, он просто
  /// исполняет запрос, который ему дали.
  Future<void> remove(int id) =>
      (delete(terminals)..where((t) => t.id.equals(id))).go();
}
