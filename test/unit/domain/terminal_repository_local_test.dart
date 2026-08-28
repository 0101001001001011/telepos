import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';

/// `LocalTerminalRepository` is terminal-identity-only since plan 2, task 5:
/// devices are `DeviceBindingRepository`'s job now
/// (`test/unit/data/terminal/device_binding_repository_local_test.dart`), not
/// a method here — see the doc comments on `Terminal`/`TerminalRepository`
/// for why.
void main() {
  late AppDatabase db;
  late TerminalRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // self() отказывается создавать терминал до того, как мастер настройки
    // записал настоящее имя кассы (см. LocalTerminalRepository.self()) —
    // большинство тестов ниже используют self() как способ получить "этот"
    // терминал, а не как предмет проверки сам по себе, поэтому установка
    // сконфигурирована здесь по умолчанию. Поведение "установка ещё не
    // сконфигурирована" проверяется отдельными тестами ниже на собственной,
    // сознательно не сконфигурированной базе.
    await db.thisPosDao.upsert(
      const ThisPosEntriesCompanion(cashBoxName: Value('Касса-1')),
    );
    repo = LocalTerminalRepository(db);
  });

  tearDown(() => db.close());

  test('self создаёт терминал этой машины при первом обращении', () async {
    final self = await repo.self();
    expect(self.name, isNotEmpty);
    expect(self.pointMode, PointMode.cashier);
  });

  test(
    'self отказывается выдумывать имя, пока мастер настройки не прошёл',
    () async {
      // Тот же дефект, что уже был закрыт для миграции v25→v26 (commit
      // 1e63d04), только вторым входом: GET /api/terminals/self доступен ещё
      // до мастера настройки, а старое поведение подставляло 'Касса-1' и
      // создавало постоянную isSelf-строку — ensureSelf() потом находил бы
      // её как уже существующую и никогда не заменял бы на настоящее имя.
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);
      final freshRepo = LocalTerminalRepository(freshDb);

      await expectLater(
        freshRepo.self(),
        throwsA(isA<InstallationNotConfiguredException>()),
      );

      final rows = await freshDb.select(freshDb.terminals).get();
      expect(
        rows,
        isEmpty,
        reason:
            'отказ обязан быть побочно-чистым — не должно остаться '
            'плейсхолдерной isSelf-строки, которую нечем будет заменить '
            'позже',
      );
    },
  );

  test(
    'self отказывается выдумывать имя, если cashBoxName состоит только из пробелов',
    () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);
      await freshDb.thisPosDao.upsert(
        const ThisPosEntriesCompanion(cashBoxName: Value('   ')),
      );
      final freshRepo = LocalTerminalRepository(freshDb);

      await expectLater(
        freshRepo.self(),
        throwsA(isA<InstallationNotConfiguredException>()),
        reason:
            'пробельное имя после trim() пусто — установка считается '
            'несконфигурированной, как и с NULL',
      );
    },
  );

  test(
    'self начинает работать после того, как мастер настройки записал имя',
    () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);
      final freshRepo = LocalTerminalRepository(freshDb);

      await expectLater(
        freshRepo.self(),
        throwsA(isA<InstallationNotConfiguredException>()),
      );

      await freshDb.thisPosDao.upsert(
        const ThisPosEntriesCompanion(cashBoxName: Value('Касса Реальная')),
      );

      final self = await freshRepo.self();
      expect(self.name, 'Касса Реальная');
    },
  );

  test('второй терминал регистрируется отдельно от self', () async {
    final first = await repo.self();
    final second = (await repo.register(name: 'Касса 2')).terminal;

    final all = await repo.list();
    expect(all, hasLength(2));
    expect(
      all.map((t) => t.id).toSet(),
      {first.id, second.id},
    );
  });

  test('register не помечает новый терминал как этот', () async {
    await repo.self();
    final second = (await repo.register(name: 'Касса 2')).terminal;

    final self = await repo.self();
    expect(self.id, isNot(second.id));
  });

  test(
    'self находит помеченный isSelf терминал, даже если он не первая строка в базе',
    () async {
      // register() создаёт строку раньше, чем существует какой-либо self —
      // значит, "первая строка в таблице" и "терминал, помеченный isSelf"
      // здесь разные строки. Тест, который сначала вызывает self(), этого
      // не различает: self всегда оказывается первой (и единственной)
      // строкой случайно, а не потому что реализация действительно ищет
      // isSelf.
      final registeredFirst =
          (await repo.register(name: 'Касса, заведённая раньше')).terminal;

      final self = await repo.self();

      expect(
        self.id,
        isNot(registeredFirst.id),
        reason:
            'self() обязан найти строку с isSelf=true, а не первую строку '
            'в таблице',
      );
    },
  );

  test(
    'несколько терминалов с казахскими и киргизскими именами находятся корректно',
    () async {
      final self = await repo.self();
      await repo.rename(self.id, 'Кассаүй');
      final second = (await repo.register(name: 'Ысык-Көл')).terminal;
      final third = (await repo.register(name: 'Терминал у окна')).terminal;

      final all = await repo.list();
      expect(all, hasLength(3));

      final byName = {for (final t in all) t.name: t};
      expect(byName.keys, containsAll(['Кассаүй', 'Ысык-Көл', 'Терминал у окна']));
      expect(byName['Кассаүй']!.id, self.id);
      expect(byName['Ысык-Көл']!.id, second.id);
      expect(byName['Терминал у окна']!.id, third.id);
    },
  );

  test(
    'pointMode с нераспознанным именем отклоняется, а не подделывается под кассира',
    () async {
      // Строку с этим значением мог оставить более новый клиент — режим,
      // которого текущий PointMode.values ещё не знает. Молчаливая замена
      // на близкий валидный режим выдала бы такой терминал за кассира или
      // за кухню без всякого предупреждения, а у режима есть последствия
      // для прав доступа. Здесь это должно упасть явно, а не тихо соврать.
      await db.into(db.terminals).insert(
        TerminalsCompanion.insert(
          name: 'Из будущей версии',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          pointMode: const Value('quantumRegister'),
        ),
      );

      await expectLater(repo.list(), throwsStateError);
    },
  );

  test('register отклоняет пустое имя', () async {
    expect(
      () => repo.register(name: ''),
      throwsArgumentError,
      reason:
          'И18-подобное правило контракта: имя обязательно, оба биндинга '
          'обязаны отклонять пустое одинаково',
    );
  });

  test('register отклоняет имя из одних пробелов', () async {
    expect(() => repo.register(name: '   '), throwsArgumentError);
  });

  test('register обрезает имя, которое становится валидным после trim', () async {
    final registered = (await repo.register(name: '  Касса у окна  ')).terminal;
    expect(registered.name, 'Касса у окна');
  });

  test('rename отклоняет пустое имя', () async {
    final self = await repo.self();
    expect(
      () => repo.rename(self.id, ''),
      throwsArgumentError,
      reason: 'локальный биндинг не должен молча записать безымянный терминал',
    );
  });

  test('rename отклоняет имя из одних пробелов', () async {
    final self = await repo.self();
    expect(() => repo.rename(self.id, '   '), throwsArgumentError);
  });

  test('rename обрезает имя, которое становится валидным после trim', () async {
    final self = await repo.self();
    await repo.rename(self.id, '  Новое имя  ');
    final reloaded = await repo.self();
    expect(reloaded.name, 'Новое имя');
  });

  test(
    'каждый из четырёх pointMode хранится и читается по имени, а не по индексу',
    () async {
      // И32/архитектурное правило: перечисления путешествуют по имени, а не
      // по порядковому номеру, потому что вставка нового варианта не в конец
      // PointMode.values иначе молча меняет режим уже сохранённых
      // терминалов. Тест хранит и перечитывает все четыре режима по
      // отдельности — переименование значения или изменение порядка
      // PointMode.values не должно пройти незамеченным.
      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final idByMode = <PointMode, int>{};

      for (final mode in PointMode.values) {
        final id = await db.into(db.terminals).insert(
          TerminalsCompanion.insert(
            name: 'Режим ${mode.name}',
            createdAt: createdAt,
            pointMode: Value(mode.name),
          ),
        );
        idByMode[mode] = id;
      }

      final all = await repo.list();
      final byId = {for (final t in all) t.id: t};

      for (final entry in idByMode.entries) {
        expect(
          byId[entry.value]!.pointMode,
          entry.key,
          reason:
              'терминал, сохранённый с pointMode="${entry.key.name}", должен '
              'прочитаться как ${entry.key}, а не как режим соседа по '
              'порядку в PointMode.values',
        );
      }
    },
  );
}
